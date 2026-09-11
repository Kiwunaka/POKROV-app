# Core2662 offline build — 2026-09-12

Document class: EXECUTION_EVIDENCE. **PASS_BOUNDED_OFFLINE_CORE_BUILD**.

From the retained Core2662 source archive, gomobile/gobind and Windows/Android
libraries rebuilt in isolated network namespaces as uid 65534. The compiled
Go cache was initially empty. Five output hashes match the current libraries:
DLL, header, AAR, source JAR, and supplied libcronet. All 3172 Core source
files remain unchanged. [Native receipt](native-evidence/resume-progress.json)
records exact commands, tool hashes, limits and output hashes; [capture index](receipt.json)
binds the retained logs and drivers.

The first tool build failed because version-qualified go install attempted a
module lookup with GOPROXY off. Its [failure receipt](native-evidence/build-progress.json)
and log remain. The successful retry compiled the pinned tool source directory.

Reproduction inputs: existing source archive
`E:/r12-2662-source-20260911/pokrov-core-2662f76-source-review.zip`
(SHA-256 `988573fde7433cc20c40f40a4696d0fa5b54aea1c936feec39cc7dab3715b25d`), plus
`C:/r12-c05-offline-source-20260912/gomobile-source-input-supplement.zip`
(SHA-256 `f04d3870a3db5ec6255a1477d861461528e738b2790df63a558af68bc0b58abd`).
The supplement contains 36 authenticated cache files for nine pinned tool modules
and their manifest. Overlay its go-module-cache directory onto the source packet;
verify each size/hash before use. Build gomobile/gobind from the extracted
v0.1.11 source with GOTOOLCHAIN=local and GOPROXY=off, then use the Core build
scripts and exact prerequisite versions recorded in the native receipt. The
retained drivers contain this run's concrete paths and need those paths adapted
for another machine; they are execution records, not a portable installer.

Go, PowerShell, MinGW, JDK, Android SDK/NDK and Windows libcronet were supplied
prebuilt. This does not establish compiler/Cronet/PGO reconstruction, complete
license compatibility, corresponding-source completeness or public delivery.
No app package, installation, release or production deploy was performed by
this build. Subsequent Wintun source corrections require separate artifacts.
