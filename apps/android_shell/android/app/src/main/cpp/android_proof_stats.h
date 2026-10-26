#ifndef POKROV_ANDROID_PROOF_STATS_H
#define POKROV_ANDROID_PROOF_STATS_H

#include <stdint.h>

/* Only the explicitly registered control socket can claim this observation. */
struct pokrov_proof_stats {
    uint64_t token;
    uint16_t port;
    int claimed;
    int tunnel;
    uint64_t client_rx;
    uint64_t upstream_tx;
    uint64_t remote_rx;
    int hello;
    int tlsrec;
};

static inline void pokrov_proof_begin(struct pokrov_proof_stats *stats,
        uint64_t token, uint16_t port)
{
    *stats = (struct pokrov_proof_stats) {
        .token = token, .port = port, .hello = -1, .tlsrec = -1
    };
}

static inline uint64_t pokrov_proof_claim(struct pokrov_proof_stats *stats, uint16_t port)
{
    if (!stats->token || stats->claimed || stats->port != port) return 0;
    stats->claimed = 1;
    return stats->token;
}

static inline void pokrov_proof_ready(struct pokrov_proof_stats *stats, uint64_t token)
{
    if (token && stats->token == token && stats->claimed) stats->tunnel = 1;
}

static inline void pokrov_proof_recv(struct pokrov_proof_stats *stats, uint64_t token,
        int remote, int64_t bytes, int hello)
{
    if (!token || stats->token != token || !stats->tunnel || bytes <= 0) return;
    if (remote) stats->remote_rx += (uint64_t)bytes;
    else {
        stats->client_rx += (uint64_t)bytes;
        if (stats->hello < 0) stats->hello = hello;
    }
}

static inline void pokrov_proof_sent(struct pokrov_proof_stats *stats,
        uint64_t token, int64_t bytes)
{
    if (token && stats->token == token && stats->tunnel && bytes > 0)
        stats->upstream_tx += (uint64_t)bytes;
}

static inline void pokrov_proof_tlsrec(struct pokrov_proof_stats *stats,
        uint64_t token, int applied)
{
    if (token && stats->token == token && stats->tunnel &&
            (stats->tlsrec < 0 || applied)) stats->tlsrec = applied;
}

static inline int pokrov_proof_finish(struct pokrov_proof_stats *stats,
        uint64_t token, struct pokrov_proof_stats *result)
{
    if (!token || stats->token != token) return 0;
    *result = *stats;
    stats->token = 0;
    return 1;
}

uint64_t pokrov_byedpi_proof_claim(uint16_t port);
void pokrov_byedpi_proof_ready(uint64_t token);
void pokrov_byedpi_proof_recv(uint64_t token, int remote, int64_t bytes, int hello);
void pokrov_byedpi_proof_sent(uint64_t token, int64_t bytes);
void pokrov_byedpi_proof_tlsrec(uint64_t token, int applied);

#endif
