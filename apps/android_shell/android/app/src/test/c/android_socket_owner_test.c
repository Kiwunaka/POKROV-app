#include "android_socket_owner.h"

#include <stdio.h>
#include <sys/wait.h>

static int connect_client(const struct sockaddr_in *server)
{
    int client = socket(AF_INET, SOCK_STREAM, 0);
    if (client < 0) return -1;
    if (connect(client, (const struct sockaddr *)server, sizeof(*server))) {
        close(client);
        return -1;
    }
    return client;
}

static int check_owner(int accepted)
{
    struct sockaddr_in local, peer;
    socklen_t local_size = sizeof(local), peer_size = sizeof(peer);
    if (getsockname(accepted, (struct sockaddr *)&local, &local_size) ||
            getpeername(accepted, (struct sockaddr *)&peer, &peer_size)) return -1;
    return process_owns_client(accepted, peer.sin_port, local.sin_port);
}

int main(void)
{
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in server = { .sin_family = AF_INET, .sin_addr.s_addr = htonl(INADDR_LOOPBACK) };
    socklen_t size = sizeof(server);
    if (listener < 0 || bind(listener, (struct sockaddr *)&server, sizeof(server)) ||
            listen(listener, 1) || getsockname(listener, (struct sockaddr *)&server, &size)) {
        perror("listener");
        return 1;
    }

    int own = connect_client(&server);
    int accepted = accept(listener, NULL, NULL);
    if (own < 0 || accepted < 0 || check_owner(accepted) != 1) {
        fprintf(stderr, "same-process client rejected\n");
        return 1;
    }
    close(accepted);
    close(own);

    int gate[2];
    if (pipe(gate)) { perror("pipe"); return 1; }
    pid_t child = fork();
    if (child < 0) { perror("fork"); return 1; }
    if (child == 0) {
        close(gate[1]);
        close(listener);
        int foreign = connect_client(&server);
        char signal;
        if (foreign < 0 || read(gate[0], &signal, 1) != 1) _exit(1);
        close(foreign);
        _exit(0);
    }
    close(gate[0]);
    accepted = accept(listener, NULL, NULL);
    int foreign_result = accepted < 0 ? -1 : check_owner(accepted);
    if (accepted >= 0) close(accepted);
    if (write(gate[1], "x", 1) != 1) { perror("gate"); return 1; }
    close(gate[1]);
    close(listener);
    int status;
    if (waitpid(child, &status, 0) != child || !WIFEXITED(status) || WEXITSTATUS(status) != 0 ||
            foreign_result != 0) {
        fprintf(stderr, "foreign-process client not rejected\n");
        return 1;
    }
    puts("same-process accepted; foreign-process rejected");
    return 0;
}
