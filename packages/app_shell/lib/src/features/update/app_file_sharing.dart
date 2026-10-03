import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:file_selector/file_selector.dart';

import '../../../app_first_runtime_bootstrap.dart';

/// Copies an already downloaded installer; never downloads or executes it.
Future<String> saveVerifiedPokrovWindowsInstaller(
  ClientAppUpdateInfo? update,
) async {
  const installerName = 'pokrov-windows-setup-x64.exe';
  final uri = update?.trustedHandoffUri;
  if (update == null ||
      update.platform.trim().toLowerCase() != 'windows' ||
      uri == null ||
      uri.pathSegments.last != installerName) {
    return 'unavailable';
  }
  try {
    const type = XTypeGroup(label: 'Установщик POKROV', extensions: ['exe']);
    final selected = await openFile(
      acceptedTypeGroups: const [type],
      confirmButtonText: 'Проверить установщик',
    );
    if (selected == null) return 'cancelled';
    if (await selected.length() != update.size) return 'invalid';
    final bytes = await selected.readAsBytes();
    if (bytes.length != update.size) return 'invalid';
    final digest = (await Sha256().hash(bytes)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (digest != update.sha256.trim().toLowerCase()) return 'invalid';
    final destination = await getSaveLocation(
      acceptedTypeGroups: const [type],
      suggestedName: installerName,
      confirmButtonText: 'Сохранить для передачи',
    );
    if (destination == null) return 'cancelled';
    // Save the bytes that passed verification, rather than reopening the source.
    await XFile.fromData(bytes, name: installerName).saveTo(destination.path);
    return 'saved';
  } on Object {
    return 'failed';
  }
}
