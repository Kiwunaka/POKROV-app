# Runtime Artifacts

This directory stores extracted `libcore` artifacts for the Wave 7 next-client lane plus the retained bridge-period release bundle mirror.

Committed content:

- this README only

Committed release content:

- `artifacts/releases/bridge/<version>/...` for bridge-period Android and Windows handoff bundles that must live in a pushable repo
- `artifacts/releases/pokrov-app/<version>/...` for repo-backed Android and Windows alpha and beta bundles built directly from the canonical `POKROV-app` lane

Generated local content:

- `artifacts/libcore/<tag>/<platform>/...`

Use `scripts/fetch-libcore-assets.ps1` to populate the local artifact cache and optionally sync the matching files into each host shell.

Retained bridge-archive rule:

- keep the last bridge-period Android and Windows handoff bundles mirrored in `artifacts/releases/bridge/<version>/`
- treat those bundles as rollback-safe evidence only
- do not treat the retired bridge repo as the active artifact or signing home

Next-client alpha rule:

- build repo-backed Android and Windows validation bundles for the canonical next-client lane in `C:/Users/kiwun/Documents/ai/POKROV-app`
- archive those bundles under `artifacts/releases/pokrov-app/<version>/`
- keep `release-handoff.json` beside each versioned bundle and update the stable pointer at `artifacts/releases/release-handoff.json` when a version becomes the active handoff source
- treat them as engineering and tester handoff artifacts only until formal cutover closes
