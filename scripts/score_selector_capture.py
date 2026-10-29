"""Score a fresh owned pre-action snapshot with frozen F102; prepare closed advice.

No API, training, final-set access or native execution. Research dependencies and
weights stay outside the App. An optional closed Decider answer binds the one
owned native QA attempt to this exact input, never to the default selector.
"""
import argparse
import json
from pathlib import Path
import statistics
import sys
import time


def prepare(snapshot, platform_root):
    sys.path.insert(0, str(platform_root / "portal_bot"))
    from connection_decisions import CandidateFacts, CandidateReplay, SelectorMemoryFacts, prepare_decision

    if snapshot["schema"] != "pokrov-owned-selector-outcome-v1" or "outcome" in snapshot:
        raise ValueError("preaction_snapshot_required")
    decision = snapshot["decision"]
    if decision["contract"] != "pokrov-preaction-v3":
        raise ValueError("unsupported_preaction_contract")
    history = decision["history"]
    if any(past["completed_at_ms"] >= decision["at_ms"] or
           past["context_generation"] != decision["context_generation"] for past in history):
        raise ValueError("not_preaction_history")
    candidates = []
    for item in decision["candidates"]:
        observed = [past for past in history if
                    past["candidate"]["candidate_ref"] == item["candidate_ref"] and
                    past["result"] in {"pass", "network_failure"}]
        elapsed = [past["elapsed_ms"] for past in observed if past["elapsed_ms"] is not None]
        memory = SelectorMemoryFacts.model_validate(item["selector_memory"])
        candidates.append(CandidateFacts(
            slot=item["candidate_ref"], eligible=item["eligible"],
            protocol={"awg": "amneziawg"}.get(item["protocol"], item["protocol"]),
            transport=item["transport"], protection=item["protection"], family=item["family"],
            network=item["network"], priority_group=item["priority_group"], priority=item["priority"],
            recovery=item["recovery"], last_good_current=item["last_good_current"],
            failure_memory_active=bool(memory.failed_self),
            successful_probes=sum(past["result"] == "pass" for past in observed),
            failed_probes=sum(past["result"] == "network_failure" for past in observed),
            median_probe_ms=round(statistics.median(elapsed)) if elapsed else None,
            selector_memory=memory))
    if any(item["policy_fixed"] for item in decision["candidates"]):
        raise ValueError("fixed_native_policy_cannot_be_advised")
    replay = CandidateReplay(role="candidate_choice", boundary=None, eligibility_complete=True,
        native_schedule_pending=snapshot["native_schedule_pending"],
        ipv6_available=decision["ipv6_available"],
        udp_failure_memory_active=bool(candidates[0].selector_memory.udp_failed), candidates=candidates)
    return replay, prepare_decision(replay)


def score(snapshot, research_root, checkpoint_path, prepared):
    if prepared.local_action is not None:
        return {"status": "local_guard", "choice": prepared.local_action, "applied": False}
    started = time.perf_counter()
    sys.path.insert(0, str(research_root))
    import numpy as np
    import torch
    from candidate_contract_v3 import encode_decision
    from generation_v3_train import Model

    torch.set_num_threads(1)
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    if checkpoint["arm"] != "enriched-F102":
        raise ValueError("frozen_f102_checkpoint_required")
    model = Model().eval()
    model.load_state_dict(checkpoint["state_dict"])
    loaded = time.perf_counter()
    tokens, allowed, _ = encode_decision(snapshot["decision"])
    rows = snapshot["decision"]["candidates"]
    allowed &= np.array([f"candidate_{row['candidate_ref']}" in prepared.criteria for row in rows])
    with torch.inference_mode():
        gains = model(torch.from_numpy(tokens[None]))[0, :, 0].numpy()
    if not np.isfinite(gains).all():
        raise ValueError("nonfinite_model_gain")
    masked = np.where(allowed, gains, -np.inf)
    # The frozen training policy uses positive expected marginal gain only.
    choice = int(masked.argmax()) if masked.max() > 0 else 0
    if not allowed[choice]:
        raise ValueError("baseline_not_admitted")
    return {"status": "advice", "contract": "pokrov-preaction-v3", "device": "cpu",
        "checkpoint": checkpoint_path.name, "epoch": checkpoint["epoch"],
        "parameters": sum(parameter.numel() for parameter in model.parameters()),
        "choice": f"candidate_{rows[choice]['candidate_ref']}",
        "baseline_choice": f"candidate_{rows[0]['candidate_ref']}",
        "expected_marginal_gains": [float(value) for value in gains],
        "load_ms": round((loaded-started)*1000, 3),
        "encode_infer_ms": round((time.perf_counter()-loaded)*1000, 3),
        "applied": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--platform-root", type=Path, required=True)
    parser.add_argument("--research-root", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--decider-result", type=Path)
    args = parser.parse_args()
    snapshot = json.loads(args.snapshot.read_text(encoding="utf-8-sig"))
    replay, prepared = prepare(snapshot, args.platform_root)
    if args.decider_result:
        result = json.loads(args.output.read_text(encoding="utf-8-sig"))
        if result["preaction"] != snapshot or result["decider_input"] != replay.model_dump():
            raise ValueError("advice_input_changed")
        from connection_decisions import parse_advice
        closed = json.loads(args.decider_result.read_text(encoding="utf-8-sig"))
        if closed["role"] != "candidate_choice" or closed["status"] != "advice" or closed["applied"]:
            raise ValueError("closed_unapplied_candidate_advice_required")
        result["decider_advice"] = parse_advice({"answers": {"advice": {
            "type": "choice", "choice": closed["choice"], "probabilities": closed["probabilities"]}}}, prepared)
        if "request_latency_ms" in closed:
            result["decider_request_latency_ms"] = closed["request_latency_ms"]
    else:
        result = {"preaction": snapshot, "decider_input": replay.model_dump(),
            "local_model": score(snapshot, args.research_root, args.checkpoint, prepared),
            "local_action": prepared.local_action, "network_requests": 0}
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"local_model": result["local_model"], "local_action": prepared.local_action,
        "candidate_count": len(replay.candidates), "network_requests": 0}))


if __name__ == "__main__":
    main()
