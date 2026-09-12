# Dart crash handlers: prevent raw error forwarding

Document class: EVIDENCE. [Receipt and exact SDK/source hashes](receipt.json).

The client handlers wrote a sanitized crash marker, then forwarded the original
FlutterErrorDetails/error/stack to prior handlers. With no prior isolate handler,
they returned false and allowed default VM reporting. Pinned Flutter3.38.5
FlutterError.dumpErrorToConsole explicitly prints exception.toString and stack
in its profile/release fallback as well as debug diagnostics. This contradicts
the client boundary against raw exceptions and paths in diagnostic console sinks.

A focused real Flutter-engine test reports a synthetic password/URL/path through
FlutterError.reportError and exercises the real platform dispatcher callback.
Before the fix the default Flutter console receives the canary. The first test
attempt failed for a different reason: this pinned TestPlatformDispatcher setter
drops onError assignments. The final test uses WidgetsFlutterBinding and restores
both original handlers and debugPrint after the test. Both failures are retained
and distinguished. This is a source/test-engine reproduction; no claim that the
release APK executed a planted Dart exception is made.

The installed handlers now write only the closed synchronous crash marker.
They do not forward original exception/stack values, and the isolate callback
returns true to prevent default raw reporting. The same test confirms no console
or prior-callback forwarding, handled=true, and a retained CRASH-001 marker with
no canary. All eight existing-file tests and package analysis pass. The canonical
runtime contract is updated. New Android/Windows packages and their current
installed checks remain pending. Native process crash recovery and native crash
file/stack collection are separate paths; this fix does not close their matrix.
