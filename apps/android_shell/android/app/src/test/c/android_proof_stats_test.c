#include <assert.h>
#include <stdio.h>

#include "../../main/cpp/android_proof_stats.h"

int main(void)
{
    struct pokrov_proof_stats stats, snapshot;
    pokrov_proof_begin(&stats, 1, 1234);
    assert(!stats.tunnel && stats.hello == -1 && stats.tlsrec == -1);
    assert(!pokrov_proof_claim(&stats, 1235));
    assert(pokrov_proof_claim(&stats, 1234) == 1);
    assert(!pokrov_proof_claim(&stats, 1234));
    pokrov_proof_ready(&stats, 1);
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
    pokrov_proof_ready(&stats, 2);
    pokrov_proof_sent(&stats, 1, 100);
    assert(pokrov_proof_finish(&stats, 2, &snapshot));
    assert(!snapshot.upstream_tx && snapshot.hello == -1 && snapshot.tlsrec == -1);
    puts("control proof stats isolated; send counts reflect positive returns");
    return 0;
}
