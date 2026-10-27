#include <jni.h>
#include <errno.h>
#include <getopt.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/un.h>

#include "params.h"
#include "proxy.h"
#include "android_socket_owner.h"
#include "android_proof_stats.h"
#include "android_proof_tcp.h"

int parse_args(int argc, char **argv);
int init(void);
void clear_params(char *line, char **argv);

/* Upstream params/parser are process-global, so one VPN session owns this loop. */
struct runtime {
    jlong id;
    pthread_t thread;
    int listener;
    int stop;
    int stop_read;
    int port;
    int running;
    int stopping;
    char *protect_path;
    jobject owner;
    jmethodID allow_client;
    JNIEnv *thread_env;
    uint64_t proof_sequence;
    struct pokrov_proof_stats proof_stats;
    int proof_fd;
};

static JavaVM *vm;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static struct runtime *current;
static jlong next_id;
static struct params defaults;
static int defaults_saved;
int pokrov_byedpi_stop_fd;

uint64_t pokrov_byedpi_proof_claim(uint16_t port)
{
    pthread_mutex_lock(&lock);
    uint64_t token = current ? pokrov_proof_claim(&current->proof_stats, port) : 0;
    pthread_mutex_unlock(&lock);
    return token;
}

void pokrov_byedpi_proof_ready(uint64_t token, int fd)
{
    if (!token) return;
    pthread_mutex_lock(&lock);
    if (current && pokrov_proof_ready(&current->proof_stats, token))
        pokrov_proof_tcp_hold(&current->proof_fd, fd);
    pthread_mutex_unlock(&lock);
}

void pokrov_byedpi_proof_recv(uint64_t token, int remote, int64_t bytes, int hello)
{
    if (!token) return;
    pthread_mutex_lock(&lock);
    if (current) pokrov_proof_recv(&current->proof_stats, token, remote, bytes, hello);
    pthread_mutex_unlock(&lock);
}

void pokrov_byedpi_proof_sent(uint64_t token, int64_t bytes)
{
    if (!token || bytes <= 0) return;
    pthread_mutex_lock(&lock);
    if (current) pokrov_proof_sent(&current->proof_stats, token, bytes);
    pthread_mutex_unlock(&lock);
}

void pokrov_byedpi_proof_tlsrec(uint64_t token, int applied)
{
    if (!token) return;
    pthread_mutex_lock(&lock);
    if (current) pokrov_proof_tlsrec(&current->proof_stats, token, applied);
    pthread_mutex_unlock(&lock);
}

int pokrov_byedpi_is_stopping(void)
{
    return __atomic_load_n(&current->stopping, __ATOMIC_ACQUIRE);
}

static void fail(JNIEnv *env, const char *message)
{
    jclass type = (*env)->FindClass(env, "java/lang/IllegalStateException");
    if (type) (*env)->ThrowNew(env, type, message);
}

int pokrov_byedpi_allow_client(int fd, const union sockaddr_u *client)
{
    union sockaddr_u local;
    socklen_t size = sizeof(local);
    if (client->sa.sa_family != AF_INET ||
            client->in.sin_addr.s_addr != htonl(INADDR_LOOPBACK) ||
            getsockname(fd, &local.sa, &size) || local.sa.sa_family != AF_INET ||
            local.in.sin_addr.s_addr != htonl(INADDR_LOOPBACK)) return 0;
    int ownership = process_owns_client(fd, client->in.sin_port, local.in.sin_port);
    JNIEnv *env = current->thread_env;
    jboolean allowed = (*env)->CallBooleanMethod(env, current->owner,
        current->allow_client, ntohs(client->in.sin_port), ownership);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        return 0;
    }
    return allowed == JNI_TRUE;
}

static void *run_proxy(void *value)
{
    struct runtime *runtime = value;
    /* Do not change process-wide handlers owned by ART/Go. */
    sigset_t blocked;
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGPIPE);
    pthread_sigmask(SIG_BLOCK, &blocked, NULL);
    if ((*vm)->AttachCurrentThread(vm, &runtime->thread_env, NULL) == JNI_OK) {
        start_event_loop(runtime->listener);
        (*vm)->DetachCurrentThread(vm);
    } else {
        close(runtime->listener);
        close(runtime->stop_read);
    }
    pthread_mutex_lock(&lock);
    runtime->running = 0;
    pthread_mutex_unlock(&lock);
    return NULL;
}

static void release(JNIEnv *env, struct runtime *runtime)
{
    pokrov_proof_tcp_close(&runtime->proof_fd);
    if (runtime->stop >= 0) close(runtime->stop);
    if (runtime->owner) (*env)->DeleteGlobalRef(env, runtime->owner);
    clear_params(NULL, NULL);
    free(params.need_free);
    params = defaults;
    free(runtime->protect_path);
    free(runtime);
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *value, void *reserved)
{
    (void)reserved;
    vm = value;
    return JNI_VERSION_1_6;
}

JNIEXPORT jlong JNICALL
Java_space_pokrov_pokrov_1android_1shell_AndroidByeDpiRuntime_nativeStart(
        JNIEnv *env, jobject owner, jstring path, jint strategy, jint requested_port)
{
    if ((*env)->GetStringUTFLength(env, path) >= sizeof(((struct sockaddr_un *)0)->sun_path) ||
            strategy < 0 || strategy > 1 || requested_port < 0 || requested_port > 65535) {
        fail(env, "byedpi: invalid native startup options");
        return 0;
    }
    pthread_mutex_lock(&lock);
    if (current) {
        pthread_mutex_unlock(&lock);
        fail(env, "byedpi: previous VPN session still owns native runtime");
        return 0;
    }
    if (!defaults_saved) {
        defaults = params;
        defaults_saved = 1;
    }
    struct runtime *runtime = calloc(1, sizeof(*runtime));
    if (!runtime) {
        pthread_mutex_unlock(&lock);
        fail(env, "byedpi: native allocation failed");
        return 0;
    }
    runtime->stop = runtime->stop_read = runtime->listener = runtime->proof_fd = -1;
    const char *utf_path = (*env)->GetStringUTFChars(env, path, NULL);
    if (utf_path) {
        runtime->protect_path = strdup(utf_path);
        (*env)->ReleaseStringUTFChars(env, path, utf_path);
    }
    if (!runtime->protect_path) goto failed;
    jclass type = (*env)->GetObjectClass(env, owner);
    if (!type) goto failed;
    runtime->allow_client = (*env)->GetMethodID(env, type, "allowClient", "(II)Z");
    (*env)->DeleteLocalRef(env, type);
    if (!runtime->allow_client) goto failed;
    runtime->owner = (*env)->NewGlobalRef(env, owner);
    if (!runtime->owner) goto failed;

    char *argv[] = {"byedpi", "--ip", "127.0.0.1", "--no-domain", "--no-udp",
        "--debug", "0", "--protect-path", runtime->protect_path,
        strategy == 0 ? "--oob=1" : "--disorder=1",
        strategy == 0 ? "--tlsrec=-5+se" : NULL, NULL};
    optind = 1;
    optreset = 1;
    opterr = 0;
    if (parse_args(strategy == 0 ? 11 : 10, argv) || init()) goto failed;
    params.mode = MODE_SOCKS5;
    params.laddr.in.sin_port = htons(requested_port);
    runtime->listener = listen_socket(&params.laddr);
    if (runtime->listener < 0) goto failed;
    union sockaddr_u local;
    socklen_t size = sizeof(local);
    if (getsockname(runtime->listener, &local.sa, &size)) goto failed;
    runtime->port = ntohs(local.in.sin_port);
    runtime->stop = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    if (runtime->stop < 0) goto failed;
    runtime->stop_read = dup(runtime->stop);
    if (runtime->stop_read < 0) goto failed;
    pokrov_byedpi_stop_fd = runtime->stop_read;
    runtime->id = ++next_id;
    runtime->running = 1;
    current = runtime;
    if (pthread_create(&runtime->thread, NULL, run_proxy, runtime)) {
        current = NULL;
        goto failed;
    }
    jlong id = runtime->id;
    pthread_mutex_unlock(&lock);
    return id;

failed:
    if (runtime->listener >= 0) close(runtime->listener);
    if (runtime->stop_read >= 0) close(runtime->stop_read);
    release(env, runtime);
    pthread_mutex_unlock(&lock);
    if (!(*env)->ExceptionCheck(env)) fail(env, "byedpi: native startup failed");
    return 0;
}

JNIEXPORT jint JNICALL
Java_space_pokrov_pokrov_1android_1shell_AndroidByeDpiRuntime_nativePort(
        JNIEnv *env, jobject owner, jlong id)
{
    (void)env;
    (void)owner;
    pthread_mutex_lock(&lock);
    int port = current && current->id == id && current->running ? current->port : 0;
    pthread_mutex_unlock(&lock);
    return port;
}

JNIEXPORT jlong JNICALL
Java_space_pokrov_pokrov_1android_1shell_AndroidByeDpiRuntime_nativeProofBegin(
        JNIEnv *env, jobject owner, jlong id, jint port)
{
    (void)env;
    (void)owner;
    uint64_t token = 0;
    pthread_mutex_lock(&lock);
    if (current && current->id == id && current->running &&
            !current->proof_stats.token && port > 0 && port <= 65535) {
        token = ++current->proof_sequence;
        pokrov_proof_begin(&current->proof_stats, token, (uint16_t)port);
    }
    pthread_mutex_unlock(&lock);
    return (jlong)token;
}

JNIEXPORT jlongArray JNICALL
Java_space_pokrov_pokrov_1android_1shell_AndroidByeDpiRuntime_nativeProofFinish(
        JNIEnv *env, jobject owner, jlong id, jlong token)
{
    (void)owner;
    struct pokrov_proof_stats stats;
    struct pokrov_proof_tcp_info tcp;
    pthread_mutex_lock(&lock);
    int found = current && current->id == id &&
        pokrov_proof_finish(&current->proof_stats, (uint64_t)token, &stats);
    if (found) tcp = pokrov_proof_tcp_finish(&current->proof_fd);
    pthread_mutex_unlock(&lock);
    if (!found) return NULL;
    jlong values[] = {stats.tunnel, (jlong)stats.client_rx, (jlong)stats.upstream_tx,
        (jlong)stats.remote_rx, stats.hello, stats.tlsrec, tcp.state, tcp.unacked,
        tcp.total_retrans, tcp.bytes_acked, tcp.bytes_received};
    jlongArray result = (*env)->NewLongArray(env, 11);
    if (result) (*env)->SetLongArrayRegion(env, result, 0, 11, values);
    return result;
}

JNIEXPORT void JNICALL
Java_space_pokrov_pokrov_1android_1shell_AndroidByeDpiRuntime_nativeStop(
        JNIEnv *env, jobject owner, jlong id)
{
    (void)owner;
    pthread_mutex_lock(&lock);
    struct runtime *runtime = current;
    if (!runtime || runtime->id != id) {
        pthread_mutex_unlock(&lock);
        return;
    }
    uint64_t stop = 1;
    __atomic_store_n(&runtime->stopping, 1, __ATOMIC_RELEASE);
    while (write(runtime->stop, &stop, sizeof(stop)) < 0 && errno == EINTR) {}
    pthread_mutex_unlock(&lock);
    pthread_join(runtime->thread, NULL);
    pthread_mutex_lock(&lock);
    current = NULL;
    release(env, runtime);
    pthread_mutex_unlock(&lock);
}
