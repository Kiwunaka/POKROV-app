from pathlib import Path
import hashlib
import re

path = Path('packages/app_shell/lib/app_first_runtime_bootstrap.dart')
raw = path.read_bytes()
assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == 'adf022a9a5e35b943456672db708456d3860bc59', 'Source moved; do not patch another revision'
s = raw.decode('utf-8')

def replace_once(old, new):
    global s
    assert s.count(old) == 1, f'Expected one replacement, got {s.count(old)}'
    s = s.replace(old, new, 1)

replace_once('''    final nextState = effectiveState.copyWith(
      sessionToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      accountId: accountId,
      managedManifestPath: _validatedManagedManifestPath(managedManifestPath),
      expectsSecureSessionToken: true,
    );
    await _runtimeStatsOutbox.rebindAccount(hostPlatform,
      legacyAccountId: _readText(session['account_id'] ?? response['account_id']),
      canonicalAccountId: _readText(session['canonical_account_id'] ?? response['canonical_account_id']),
      installId: nextState.installId);
    await _saveState(hostPlatform, nextState);
    return await _loadState(hostPlatform) ?? nextState;
''', '''    final file = await _stateFile(hostPlatform);
    return _withAppFirstStateFileLock(file, () async {
      final current = await _loadStateFromFile(hostPlatform, file);
      if (current != null && current.installId == effectiveState.installId &&
          current.hasSession && accountId.isNotEmpty &&
          current.accountId == accountId) {
        // Another initial request or login already won for this same account.
        // Keep its complete state and credentials; never overwrite them.
        return current;
      }
      if (current == null || current.installId != effectiveState.installId ||
          current.accountId != effectiveState.accountId ||
          current.sessionToken != effectiveState.sessionToken ||
          current.refreshToken != effectiveState.refreshToken ||
          current.expectsSecureSessionToken != effectiveState.expectsSecureSessionToken) {
        throw const BootstrapFailure(
          'Сессия изменилась. Повторите вход.', code: 'session_changed');
      }
      final nextState = current.copyWith(
        sessionToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        accountId: accountId,
        managedManifestPath: _validatedManagedManifestPath(managedManifestPath),
        expectsSecureSessionToken: true,
      );
      await _runtimeStatsOutbox.rebindAccount(hostPlatform,
        legacyAccountId: _readText(session['account_id'] ?? response['account_id']),
        canonicalAccountId: _readText(session['canonical_account_id'] ?? response['canonical_account_id']),
        installId: nextState.installId);
      await _persistStateToFile(hostPlatform: hostPlatform, file: file, state: nextState);
      return nextState;
    });
''')
start = s.index('  Future<_StoredBootstrapState> _refreshSession({')
end = s.index('  void _removeRefreshFlight(', start)
block = s[start:end]
assert block.count("final key = '${hostPlatform.name}:${state.installId.trim()}';") == 1
block = block.replace("final key = '${hostPlatform.name}:${state.installId.trim()}';", "final key = '${hostPlatform.name}:${state.installId.trim()}:${state.accountId}';")
s = s[:start] + block + s[end:]
assert s.count('return _stateWithCredentials(state, latest!);') == 2
s = s.replace('return _stateWithCredentials(state, latest!);', 'return _loadRefreshSuccessor(hostPlatform, state);')
replace_once('''  _StoredBootstrapState _stateWithCredentials(
    _StoredBootstrapState state,
    AppFirstSessionCredentials credentials,
  ) {
    return state.copyWith(
      sessionToken: credentials.accessToken,
      refreshToken: credentials.refreshToken,
      expectsSecureSessionToken: true,
    );
  }
''', '''  Future<_StoredBootstrapState> _loadRefreshSuccessor(
    HostPlatform hostPlatform,
    _StoredBootstrapState previous,
  ) async {
    final file = await _stateFile(hostPlatform);
    return _withAppFirstStateFileLock(file, () async {
      final current = await _loadStateFromFile(hostPlatform, file);
      if (current == null || !current.hasSession ||
          current.installId != previous.installId ||
          previous.accountId.isEmpty || current.accountId != previous.accountId) {
        throw const BootstrapFailure(
          'Сессия изменилась. Повторите вход.', code: 'session_changed');
      }
      // A concurrent rotation may win, but its tokens must travel with its
      // own account and profile state, not a copy of the previous identity.
      return current;
    });
  }
''')
start = s.index('  Future<Map<String, dynamic>> _requestClientJsonWithSession({')
end = s.index('  Future<TelegramLinkResult> createTelegramLink({', start)
block = s[start:end]
old = '''          requests.requireActive();
          return response;'''
new = '''          requests.requireActive();
          final current = await _loadState(hostPlatform);
          requests.requireActive();
          if (current == null || !current.hasSession ||
              current.installId != state.installId ||
              current.accountId != state.accountId ||
              current.refreshToken != state.refreshToken ||
              current.sessionToken != state.sessionToken) {
            throw const BootstrapFailure(
              'Сессия изменилась. Повторите вход.', code: 'session_changed');
          }
          return response;'''
assert block.count(old) == 1
block = block.replace(old, new)
assert block.count("                accountId: '',\n") == 1
block = block.replace("                accountId: '',\n", '')
s = s[:start] + block + s[end:]
# Preserve the account only in expired-access retries, never logout writes.
s, count = re.subn(r"(state: state\.copyWith\(\n\s*sessionToken: '',\n)\s*accountId: '',\n(\s*\),)", r'\1\2', s)
assert count >= 1
replace_once('''  Future<void> _saveState(
    HostPlatform hostPlatform,
    _StoredBootstrapState state,
  ) async {
    final file = await _stateFile(hostPlatform);
    await _withAppFirstStateFileLock(
      file,
      () => _persistStateToFile(
        hostPlatform: hostPlatform,
        file: file,
        state: state,
      ),
    );
  }

''', '')
assert '_saveState(' not in s
path.write_text(s, encoding='utf-8')
test_path = Path('packages/app_shell/test/session_response_fencing_test.dart')
test_source = test_path.read_text(encoding='utf-8')
unused_import = "import 'package:pokrov_runtime_engine/runtime_engine.dart';\n"
assert test_source.count(unused_import) == 1
test_path.write_text(test_source.replace(unused_import, ''), encoding='utf-8')
print('Patched session response boundaries; preserved retry identity at', count + 1, 'call sites')
