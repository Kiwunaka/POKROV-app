#include <assert.h>
#include <errno.h>
#include <stdio.h>

#include "../../main/cpp/android_proof_stats.h"
#include "../../main/cpp/android_proof_tcp.h"

int main(void)
{
    struct pokrov_proof_stats stats, snapshot;
    pokrov_proof_begin(&stats, 1, 1234);
    assert(!stats.tunnel && stats.hello == -1 && stats.tlsrec == -1);
    assert(!pokrov_proof_claim(&stats, 1235));
    assert(pokrov_proof_claim(&stats, 1234) == 1);
    assert(!pokrov_proof_claim(&stats, 1234));
    assert(!pokrov_proof_ready(&stats, 2));
    assert(pokrov_proof_ready(&stats, 1));
    assert(!pokrov_proof_ready(&stats, 1));
    pokrov_proof_recv(&stats, 1, 0, 20, 0);
    pokrov_proof_recv(&stats, 1, 0, 30, 1);
    pokrov_proof_recv(&stats, 1, 1, 7, -1);
    pokrov_proof_sent(&stats, 1, 8);
    pokrov_proof_sent(&stats, 1, -1);
    pokrov_proof_sent(&stats, 2, 100);
    pokrov_proof_tlsrec(&stats, 1, 0);
    pokrov_proof_tlsrec(&stats, 1, 1);
    assert(!pokrov_proof_finish(&stats, 2, &snapshot));
    assert(pokrov_proof_finish(&stats, 1, &snapshot));
    assert(snapshot.tunnel && snapshot.client_rx == 50 && snapshot.upstream_tx == 8);
    assert(snapshot.remote_rx == 7 && snapshot.hello == 0 && snapshot.tlsrec == 1);
    pokrov_proof_begin(&stats, 2, 1234);
    assert(pokrov_proof_claim(&stats, 1234) == 2);
    assert(pokrov_proof_ready(&stats, 2));
    pokrov_proof_sent(&stats, 1, 100);
    assert(pokrov_proof_finish(&stats, 2, &snapshot));
    assert(!snapshot.upstream_tx && snapshot.hello == -1 && snapshot.tlsrec == -1);
    struct tcp_info raw = {0};
    raw.tcpi_state = 1;
    raw.tcpi_unacked = 2;
    raw.tcpi_total_retrans = 3;
    raw.tcpi_bytes_acked = 4;
    raw.tcpi_bytes_received = 5;
    struct pokrov_proof_tcp_info tcp = pokrov_proof_tcp_decode(&raw, offsetof(struct tcp_info, tcpi_unacked));
    assert(tcp.state == 1 && tcp.unacked == -1 && tcp.total_retrans == -1);
    assert(tcp.bytes_acked == -1 && tcp.bytes_received == -1);
    tcp = pokrov_proof_tcp_decode(&raw, offsetof(struct tcp_info, tcpi_bytes_acked));
    assert(tcp.state == 1 && tcp.unacked == 2 && tcp.total_retrans == 3);
    assert(tcp.bytes_acked == -1 && tcp.bytes_received == -1);
    tcp = pokrov_proof_tcp_decode(&raw, sizeof(raw));
    assert(tcp.state == 1 && tcp.unacked == 2 && tcp.total_retrans == 3);
    assert(tcp.bytes_acked == 4 && tcp.bytes_received == 5);

    int fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    assert(fd >= 0);
    int held = -1;
    pokrov_proof_tcp_hold(&held, fd);
    assert(held >= 0);
    int duplicate = held;
    close(fd);
    assert(fcntl(duplicate, F_GETFD) >= 0);
    tcp = pokrov_proof_tcp_finish(&held);
    assert(tcp.state >= 0 && held == -1);
    assert(fcntl(duplicate, F_GETFD) == -1 && errno == EBADF);

    int ends[2];
    assert(!pipe(ends));
    pokrov_proof_tcp_hold(&held, ends[0]);
    assert(held >= 0);
    duplicate = held;
    tcp = pokrov_proof_tcp_finish(&held);
    assert(tcp.state == -1 && tcp.unacked == -1 && tcp.total_retrans == -1);
    assert(tcp.bytes_acked == -1 && tcp.bytes_received == -1);
    assert(held == -1 && fcntl(duplicate, F_GETFD) == -1 && errno == EBADF);
    pokrov_proof_tcp_hold(&held, ends[0]);
    duplicate = held;
    pokrov_proof_tcp_close(&held);
    assert(held == -1 && fcntl(duplicate, F_GETFD) == -1 && errno == EBADF);
    close(ends[0]);
    close(ends[1]);
    puts("control proof stats and TCP snapshot isolated; duplicate FDs closed");
    return 0;
}
