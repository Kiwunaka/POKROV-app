part of pokrov_app_shell;

String _smartConnectNodeTitle(SmartConnectNode node) {
  final country = node.country.trim();
  final code = node.code.trim().toUpperCase();
  if (country.isNotEmpty && code.isNotEmpty) {
    return '$country · $code';
  }
  if (country.isNotEmpty) {
    return country;
  }
  return code.isEmpty ? 'POKROV' : code;
}
