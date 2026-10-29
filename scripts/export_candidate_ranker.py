"""Export the fixed pokrov-preaction-v1 Transformer for local client QA.

Training dependencies are used on the build host only. Output is a local asset,
not a source file; do not add weights or checkpoints to git.
"""
import argparse
from pathlib import Path

import numpy as np
import torch


def export(checkpoint_path: Path, output: Path) -> None:
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    if checkpoint.get("kind") != "transformer" or checkpoint.get("contract_version") != "pokrov-preaction-v1":
        raise ValueError("Expected pokrov-preaction-v1 Transformer")
    shapes = {"position": (1, 9, 160), "embed.weight": (160, 82), "embed.bias": (160,)}
    for layer in range(4):
        prefix = f"encoder.layers.{layer}."
        shapes.update({prefix + name: shape for name, shape in {
            "self_attn.in_proj_weight": (480, 160), "self_attn.in_proj_bias": (480,),
            "self_attn.out_proj.weight": (160, 160), "self_attn.out_proj.bias": (160,),
            "linear1.weight": (384, 160), "linear1.bias": (384,),
            "linear2.weight": (160, 384), "linear2.bias": (160,),
            "norm1.weight": (160,), "norm1.bias": (160,),
            "norm2.weight": (160,), "norm2.bias": (160,),
        }.items()})
    shapes.update({"project.0.weight": (64, 160), "project.0.bias": (64,),
                   "head.weight": (4, 64), "head.bias": (4,)})
    state = checkpoint["state_dict"]
    if set(state) != set(shapes) or any(tuple(state[key].shape) != shape for key, shape in shapes.items()):
        raise ValueError("Unexpected Transformer architecture")
    weights = np.concatenate([state[key].detach().numpy().reshape(-1) for key in shapes]).astype("<f4")
    if weights.size != 933700 or not np.isfinite(weights).all():
        raise ValueError("Invalid Transformer weights")
    output.write_bytes(b"PKRTF001" + weights.tobytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkpoint", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    export(args.checkpoint, args.output)
