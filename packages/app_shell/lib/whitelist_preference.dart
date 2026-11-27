import 'package:pokrov_core_domain/core_domain.dart';

const _whitelistProfiles = {
  'mts_vless',
  'dnstt_vless',
  'slipstream_vless',
  'vk_vless',
  'avito_vless',
  'bitrix_hy2',
};

String whitelistProfile(String preference) {
  final parts = preference.split(':');
  if (parts.length != 2 || !_whitelistProfiles.contains(parts[1])) return '';
  return parts[1];
}

String automaticWhitelistPreference(String profile) => 'auto:$profile';

bool isAutomaticWhitelistPreference(String preference) =>
    preference.startsWith('auto:') && whitelistProfile(preference).isNotEmpty;

String pinnedCandidatePreference(String preference) =>
    isAutomaticWhitelistPreference(preference) ? '' : preference;

bool usesSelectedWhitelistProfile(TransportCandidate candidate, String preference) {
  final profile = whitelistProfile(preference);
  return profile.isEmpty
      ? !candidate.usesWhitelistTransport
      : candidate.usesWhitelistTransport && candidate.profileRef == profile;
}
