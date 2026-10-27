#ifndef POKROV_ANDROID_PROOF_TCP_H
#define POKROV_ANDROID_PROOF_TCP_H

#include <fcntl.h>
#include <linux/tcp.h>
#include <netinet/in.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/socket.h>
#include <unistd.h>

struct pokrov_proof_tcp_info {
    int64_t state;
    int64_t unacked;
    int64_t total_retrans;
    int64_t bytes_acked;
    int64_t bytes_received;
};

static inline void pokrov_proof_tcp_hold(int *held, int fd)
{
    *held = fcntl(fd, F_DUPFD_CLOEXEC, 0);
}

static inline void pokrov_proof_tcp_close(int *held)
{
    if (*held >= 0) close(*held);
    *held = -1;
}

static inline struct pokrov_proof_tcp_info pokrov_proof_tcp_decode(
        const struct tcp_info *info, socklen_t size)
{
    struct pokrov_proof_tcp_info result = {-1, -1, -1, -1, -1};
#define TCP_FIELD_AVAILABLE(field) (size >= offsetof(struct tcp_info, field) + sizeof(info->field))
    if (TCP_FIELD_AVAILABLE(tcpi_state)) result.state = info->tcpi_state;
    if (TCP_FIELD_AVAILABLE(tcpi_unacked)) result.unacked = info->tcpi_unacked;
    if (TCP_FIELD_AVAILABLE(tcpi_total_retrans)) result.total_retrans = info->tcpi_total_retrans;
    if (TCP_FIELD_AVAILABLE(tcpi_bytes_acked)) result.bytes_acked = info->tcpi_bytes_acked;
    if (TCP_FIELD_AVAILABLE(tcpi_bytes_received)) result.bytes_received = info->tcpi_bytes_received;
#undef TCP_FIELD_AVAILABLE
    return result;
}

static inline struct pokrov_proof_tcp_info pokrov_proof_tcp_finish(int *held)
{
    struct pokrov_proof_tcp_info result = {-1, -1, -1, -1, -1};
    struct tcp_info info = {0};
    socklen_t size = sizeof(info);
    if (*held >= 0 && !getsockopt(*held, IPPROTO_TCP, TCP_INFO, &info, &size))
        result = pokrov_proof_tcp_decode(&info, size);
    pokrov_proof_tcp_close(held);
    return result;
}

#endif
