#ifndef POKROV_ANDROID_SOCKET_OWNER_H
#define POKROV_ANDROID_SOCKET_OWNER_H

#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static int loopback_endpoint(const struct sockaddr_storage *address, socklen_t size, in_port_t port)
{
    if (address->ss_family == AF_INET && size >= sizeof(struct sockaddr_in)) {
        const struct sockaddr_in *v4 = (const struct sockaddr_in *)address;
        return v4->sin_port == port && v4->sin_addr.s_addr == htonl(INADDR_LOOPBACK);
    }
    if (address->ss_family == AF_INET6 && size >= sizeof(struct sockaddr_in6)) {
        const struct sockaddr_in6 *v6 = (const struct sockaddr_in6 *)address;
        const in_addr_t loopback = htonl(INADDR_LOOPBACK);
        return v6->sin6_port == port && IN6_IS_ADDR_V4MAPPED(&v6->sin6_addr) &&
            !memcmp(&v6->sin6_addr.s6_addr[12], &loopback, sizeof(loopback));
    }
    return 0;
}

/* A held FD pins the exact TCP connection while its reverse tuple is checked. */
static int process_owns_client(int accepted, in_port_t client_port, in_port_t server_port)
{
    if (client_port == server_port) return 0;
    DIR *fds = opendir("/proc/self/fd");
    if (!fds) return -1;
    int result = 0;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(fds);
        if (!entry) { if (errno) result = -1; break; }
        char *end;
        errno = 0;
        long number = strtol(entry->d_name, &end, 10);
        if (errno || end == entry->d_name || *end || number < 0 || number > INT_MAX ||
                number == accepted || number == dirfd(fds)) continue;
        int held = fcntl((int)number, F_DUPFD_CLOEXEC, 0);
        if (held < 0) {
            if (errno == EMFILE || errno == ENFILE) { result = -1; break; }
            continue;
        }
        int type = 0, protocol = 0;
        socklen_t type_size = sizeof(type), protocol_size = sizeof(protocol);
        struct sockaddr_storage local, peer;
        socklen_t local_size = sizeof(local), peer_size = sizeof(peer);
        int matches = !getsockopt(held, SOL_SOCKET, SO_TYPE, &type, &type_size) &&
            type == SOCK_STREAM &&
            !getsockopt(held, SOL_SOCKET, SO_PROTOCOL, &protocol, &protocol_size) &&
            protocol == IPPROTO_TCP &&
            !getsockname(held, (struct sockaddr *)&local, &local_size) &&
            !getpeername(held, (struct sockaddr *)&peer, &peer_size) &&
            loopback_endpoint(&local, local_size, client_port) &&
            loopback_endpoint(&peer, peer_size, server_port);
        close(held);
        if (matches) { result = 1; break; }
    }
    closedir(fds);
    return result;
}

#endif
