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

Bridge-period release rule:

- build and package Android and Windows in `C:/Users/kiwun/Documents/ai/VPN/external/client-fork/app/`
- keep `external/client-fork/app/out/` as the local working-set bundle for signing and operator validation
- mirror the final alpha/beta/RC/public handoff bundle into `artifacts/releases/bridge/<version>/` here because the public bridge fork cannot accept new Git LFS release objects

Next-client alpha rule:

- build repo-backed Android and Windows validation bundles for the canonical next-client lane in `C:/Users/kiwun/Documents/ai/POKROV-app`
- archive those bundles under `artifacts/releases/pokrov-app/<version>/`
- treat them as engineering and tester handoff artifacts only until formal cutover closes
