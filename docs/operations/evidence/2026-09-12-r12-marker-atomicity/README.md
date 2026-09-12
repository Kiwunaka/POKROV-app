# Previous-exit marker replacement

Document class: EVIDENCE. [Receipt and file hashes](receipt.json).

The store deleted its current marker before renaming the flushed `.next` file.
The two retained fault-injection tests reproduce loss of the previous marker
when rename fails, for both async clean-exit and synchronous crash writes.
The first test-double declaration did not compile; before.log is that harness
failure. before-fixed-harness.log is the actual two-test product regression.

The fix removes only the two destination-deletion blocks. The pinned Dart3.10.4
Windows implementation uses MoveFileExW with replacement/write-through flags;
Android/Linux use renameat. [Pinned source identities](sdk-source-binding.json).
The native Windows fixture additionally holds the temporary file open: real
sharing violation32 preserves old bytes, and both rename APIs replace the
existing destination after unlocking. No production fault hook or dependency.

All9 phase/timeline tests and all31 observability-runtime tests pass. Targeted
analyze reports no issues. Commands: flutter test test/phase_timeline_test.dart
--no-pub --reporter expanded; flutter test --no-pub --reporter expanded;
dart analyze lib/src/crash_marker.dart test/phase_timeline_test.dart;
dart native-rename.dart. The canonical saved-state contract records the exact
write/failure behavior. [Source diff](source.patch).

These are source and isolated Windows filesystem checks, not power-loss proof,
new installed APK/Windows acceptance or completed operational release gates.
The F711 packages and Huawei acceptance precede this fix and retain their exact
original identities. No new package, public artifact or store release here.
