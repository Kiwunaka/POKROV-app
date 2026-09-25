# Client checks

Run focused Flutter tests in the changed package. For host changes, run the
Android app's direct and store unit-test flavors or the Windows build as
applicable.

Repository checks:

```powershell
./test/seed-layout.ps1 -PlatformRoot ../VPN -CoreRoot ../POKROV-core
./test/repository-hygiene-contract.ps1
./test/run-tests-contract.ps1
```

`repository-hygiene-contract.ps1` prevents release history and Core binaries
from being tracked in this source repository.
