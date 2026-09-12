$ErrorActionPreference = 'Stop'
Set-Location E:/r12client
& ./test/docs-contract.ps1 *> C:/r12-psm-autoexpiry-20260912/docs-contract.log
if ($LASTEXITCODE -ne 0) { throw 'docs contract failed' }
& ./scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12corec02 *> C:/r12-psm-autoexpiry-20260912/validate-seed.log
if ($LASTEXITCODE -ne 0) { throw 'seed validation failed' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'diff check failed' }
if (git diff --name-only -- artifacts/releases/) { throw 'unexpected release artifact change' }
'PASS_DOCS_SEED_DIFF_ARTIFACT_BOUNDARY'
