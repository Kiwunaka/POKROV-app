# Support Agent Sheet Session Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry the server-issued `assistantSessionId` through the Flutter client so consecutive messages in one open AI support sheet share bounded server memory, while closing the sheet starts a fresh client conversation.

**Architecture:** Add one optional opaque session field to the existing app-first API request/response model, thread it through the existing support callback, and keep it only inside `_AssistantChatSheetState`. No persistence, account access, hidden diagnostics, background session, or new UI surface is added.

**Tech Stack:** Dart/Flutter, existing app-first HTTP bootstrapper, existing support sheet/widget tests.

## Global Constraints

- Work only in `C:\Users\kiwun\Documents\ai\POKROV-app\.worktrees\support-agent-session-continuity` on `codex/support-agent-session-continuity`.
- The server contract is defined by the platform design `C:\Users\kiwun\Documents\ai\VPN\.worktrees\support-agent-harness\docs\superpowers\specs\2026-07-15-safe-support-agent-harness-design.md`.
- This plan depends only on the additive server request/response field. It does not depend on provider details or duplicate any agent logic in Flutter.
- Keep the assistant inside Support; do not add a tab, streaming, persistence, ticket-history import, or background memory.
- Keep the current four safe diagnostic fields unchanged. `assistantSessionId` is an opaque continuity token, never authentication.
- Tests must catch the two real regressions: wire loss of the token and accidental continuity beyond the sheet lifetime. Do not add getter/constructor/golden/coverage-only tests or run unrelated app suites.
- Flutter is not currently on this shell's `PATH`. Before execution, resolve the existing owner Flutter SDK and invoke its `flutter.bat` explicitly; if no SDK is available, record `BLOCKED_BY_ACCESS` instead of claiming tests passed.

---

## File Structure

### Modify

- `packages/app_shell/lib/app_first_runtime_bootstrap.dart` — optional request token and parsed response token.
- `packages/app_shell/lib/src/shell/seed_shell.dart` — pass the current sheet token with the existing four safe diagnostics.
- `packages/app_shell/lib/src/features/support/support_chat.dart` — retain the token only in sheet state.
- `packages/app_shell/test/app_first_runtime_bootstrap_test.dart` — exact HTTP request/response contract.
- `packages/app_shell/test/pokrov_seed_app_test.dart` — first/second/reopened sheet lifetime behavior.
- `docs/architecture/in-app-ai-assistant-contract.md` — canonical client continuity boundary.

### Data Flow

```text
open sheet: _assistantSessionId = null
  -> first ask(message, null)
  <- reply.assistantSessionId = server token
  -> second ask(message, server token)
close sheet: State.dispose()
reopen sheet: new State, token = null
```

The existing app-session bearer token remains the authorization layer. The assistant token is not authentication, never selects an owner, and is safe to discard at any time.

---

## Task 1: Add the Opaque Token to the App-First Wire Contract

**Files:**

- Modify: `packages/app_shell/lib/app_first_runtime_bootstrap.dart`
- Modify: `packages/app_shell/test/app_first_runtime_bootstrap_test.dart`

**Produces:** One optional valid `assistantSessionId` in the POST body and response model.

- [ ] Extend the existing test `client support assistant uses app-session auth` instead of adding a duplicate HTTP-server test. Make the fake endpoint return:

```dart
<String, Object?>{
  'reply': 'Try reconnecting once, then send diagnostics.',
  'assistantSessionId': 'session_1234567890abcdef',
  'shouldEscalate': false,
  'suggestedActions': <Object?>[
    <String, Object?>{'key': 'retry_connect', 'label': 'Retry'},
  ],
}
```

Call `askSupportAssistant` with `assistantSessionId: 'session_abcdefghijklmnop'`. Assert the request carries that exact camel-case field and the parsed reply exposes `session_1234567890abcdef`. Retain the authorization, message, ticket, and safe-diagnostics assertions already in the test.

- [ ] Run the single test and confirm the new named parameter/property assertions fail before implementation:

```powershell
flutter test test/app_first_runtime_bootstrap_test.dart --plain-name "client support assistant uses app-session auth"
```

Expected: compile failure for the missing `assistantSessionId` API/model member.

- [ ] Add one shared private validator in `app_first_runtime_bootstrap.dart`:

```dart
final RegExp _assistantSessionIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

String? _clientAssistantSessionId(Object? value) {
  final text = _clientText(value).trim();
  return _assistantSessionIdPattern.hasMatch(text) ? text : null;
}
```

- [ ] Extend both the abstract service method and `AppFirstRuntimeBootstrapper.askSupportAssistant` with the optional named parameter `String? assistantSessionId`. Validate it locally and add `'assistantSessionId': validSessionId` only when non-null. Keep `scope: 'support'`, ticket ID, message, bearer session, and diagnostics behavior unchanged.

- [ ] Extend `ClientSupportAssistantReply` with `final String? assistantSessionId`, an optional constructor parameter, and parsing from `assistantSessionId` with snake-case fallback `assistant_session_id` through `_clientAssistantSessionId`. Existing fake/const constructors remain source-compatible because the new parameter is optional.

- [ ] Run the focused wire test:

```powershell
flutter test test/app_first_runtime_bootstrap_test.dart --plain-name "client support assistant uses app-session auth"
```

Expected: pass.

- [ ] Format only the touched Dart files and commit:

```powershell
dart format packages/app_shell/lib/app_first_runtime_bootstrap.dart packages/app_shell/test/app_first_runtime_bootstrap_test.dart
git add packages/app_shell/lib/app_first_runtime_bootstrap.dart packages/app_shell/test/app_first_runtime_bootstrap_test.dart
git commit -m "feat(client): carry support assistant session token"
```

---

## Task 2: Keep Continuity Only While the Assistant Sheet Is Open

**Files:**

- Modify: `packages/app_shell/lib/src/features/support/support_chat.dart`
- Modify: `packages/app_shell/lib/src/shell/seed_shell.dart`
- Modify: `packages/app_shell/test/pokrov_seed_app_test.dart`
- Modify: `docs/architecture/in-app-ai-assistant-contract.md`

**Produces:** First call without a token, later calls with the server token, reopened sheet without prior continuity.

- [ ] Add one focused widget test named `support AI assistant keeps one server session only while sheet is open`. Reuse `_FakeBootstrapper` and make its fixed reply carry `assistantSessionId: 'session_1234567890abcdef'`. Record every incoming `assistantSessionId` in `assistantSessionIds`.

The test must perform exactly three sends:

1. Open the sheet and send `Не подключается` — recorded token is `null`.
2. Without closing, send `Сайты всё ещё не открываются` — recorded token is `session_1234567890abcdef`.
3. Close the sheet, reopen it, send `Начнём заново` — recorded token is `null`.

It must also assert the existing four diagnostic keys remain exactly `app_version`, `platform`, `route_mode`, and `connection_status`. Do not inspect visual styling in this test.

- [ ] Run only that widget test and confirm compile/behavior failure:

```powershell
flutter test test/pokrov_seed_app_test.dart --plain-name "support AI assistant keeps one server session only while sheet is open"
```

Expected: failure because the callback has no token parameter and the sheet stores no server token.

- [ ] Change the callback signature in `support_chat.dart` from a one-argument function to:

```dart
Future<ClientSupportAssistantReply> Function(
  String message,
  String? assistantSessionId,
)
```

Add `String? _assistantSessionId;` to `_AssistantChatSheetState`. Call `widget.askAssistant(text, _assistantSessionId)`. After a successful reply and only while `mounted`, replace the stored value when `reply.assistantSessionId` is non-null. Do not persist it elsewhere. Normal `State.dispose()` is the cleanup; no explicit server logout call is needed.

- [ ] Change `_askSupportAssistant` in `seed_shell.dart` to accept `(String message, String? assistantSessionId)` and forward the token to `service.askSupportAssistant`. Keep its existing four-value `safeDiagnostics` map byte-for-byte in meaning.

- [ ] Extend `_FakeBootstrapper.askSupportAssistant` with the optional named token parameter and append it to `assistantSessionIds` before returning. Update only constructor sites that need a server token for this test; existing tests continue to use `null`.

- [ ] Update `docs/architecture/in-app-ai-assistant-contract.md` with these exact client truths: the token is optional and opaque; the server binds it to authenticated owner/surface; the sheet retains it only until close; reopen/restart starts fresh continuity; it is not auth; no chat history is persisted; the four diagnostics do not enter model memory.

- [ ] Run the one new continuity test plus the existing honest-fallback test because both execute `_send()` error/empty-answer handling:

```powershell
flutter test test/pokrov_seed_app_test.dart --plain-name "support AI assistant keeps one server session only while sheet is open"
flutter test test/pokrov_seed_app_test.dart --plain-name "support AI assistant admits a missing answer instead of improvising"
```

Expected: both pass.

- [ ] Format and commit this slice:

```powershell
dart format packages/app_shell/lib/src/features/support/support_chat.dart packages/app_shell/lib/src/shell/seed_shell.dart packages/app_shell/test/pokrov_seed_app_test.dart
git add packages/app_shell/lib/src/features/support/support_chat.dart packages/app_shell/lib/src/shell/seed_shell.dart packages/app_shell/test/pokrov_seed_app_test.dart docs/architecture/in-app-ai-assistant-contract.md
git commit -m "feat(client): scope assistant memory to open support sheet"
```

---

## Task 3: Run the Smallest Complete Client Gate

**Files:** The six modified files above.

- [ ] Resolve the owner Flutter SDK once and set `$flutter` and `$dart` to literal executable paths. Do not install or upgrade Flutter as part of this task.

- [ ] Run only the two affected test files; they cover transport parsing and the sheet callback/state lifecycle:

```powershell
& $flutter test test/app_first_runtime_bootstrap_test.dart --plain-name "client support assistant uses app-session auth"
& $flutter test test/pokrov_seed_app_test.dart --plain-name "support AI assistant keeps one server session only while sheet is open"
& $flutter test test/pokrov_seed_app_test.dart --plain-name "support AI assistant admits a missing answer instead of improvising"
```

Run from `packages/app_shell`. Expected: all selected tests pass.

- [ ] Analyze only the affected package, not Android/Windows/runtime-engine packages:

```powershell
& $flutter analyze
```

Run from `packages/app_shell`. Expected: no issues found.

- [ ] Check formatting, diff, and accidental persistence:

```powershell
& $dart format --output=none --set-exit-if-changed lib/app_first_runtime_bootstrap.dart lib/src/features/support/support_chat.dart lib/src/shell/seed_shell.dart test/app_first_runtime_bootstrap_test.dart test/pokrov_seed_app_test.dart
rg.exe -n "assistantSessionId|assistant_session_id" lib test ..\..\docs\architecture\in-app-ai-assistant-contract.md
rg.exe -n "SharedPreferences|secure storage|file|database" lib/src/features/support/support_chat.dart lib/src/shell/seed_shell.dart
git diff --check
git status --short --branch
git diff main...HEAD -- packages/app_shell docs/architecture/in-app-ai-assistant-contract.md
```

Expected: token occurrences are limited to the wire/data/callback/sheet/test/doc paths; no persistence API was added; diff check is empty.

- [ ] If verification reveals a corrective edit, stage only the literal affected paths and commit with `fix(client): close assistant session continuity gaps`. If no edit was needed, do not create an empty commit.

---

## Done Condition

- The first message in a newly opened assistant sheet omits `assistantSessionId`.
- The server-issued valid ID is sent on subsequent messages in that same sheet.
- Closing/reopening the sheet drops client continuity; nothing is persisted.
- The normal app bearer session remains the only authorization mechanism.
- The four safe diagnostics remain unchanged and no new sensitive context is collected.
- Three focused tests and `flutter analyze` pass, or missing SDK access is reported as `BLOCKED_BY_ACCESS` without a false pass claim.
