part of pokrov_app_shell;

String _smartConnectNodeTitle(SmartConnectNode node) {
  final country = node.country.trim();
  if (country.isNotEmpty) {
    return country;
  }
  return 'Локация POKROV';
}

String _smartConnectNodeCity(SmartConnectNode node) {
  return node.country.trim().isEmpty ? 'Доступная локация' : 'Доступная страна';
}

String _smartConnectQualityLabel(SmartConnectNode node) {
  return _locationQualityLabel(node.rankHint.healthScore);
}

String _locationQualityLabel(double rawScore) {
  final score = rawScore > 1 ? rawScore / 100 : rawScore;
  if (score >= 0.88) {
    return 'Отлично';
  }
  if (score >= 0.68) {
    return 'Хорошо';
  }
  if (score >= 0.42) {
    return 'Стабильно';
  }
  return 'Медленно';
}
