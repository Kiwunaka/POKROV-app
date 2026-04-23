library pokrov_support_context;

import 'package:pokrov_core_domain/core_domain.dart';

class SupportSnapshot {
  const SupportSnapshot({
    required this.supportBot,
    required this.feedbackBot,
    required this.publicChannel,
    required this.supportEmail,
    required this.safeNotes,
    required this.recommendedRouteMode,
    required this.channelBonusDays,
  });

  final String supportBot;
  final String feedbackBot;
  final String publicChannel;
  final String supportEmail;
  final String safeNotes;
  final RouteMode recommendedRouteMode;
  final int channelBonusDays;

  String get summary =>
      'Get help in $supportBot, $feedbackBot, or by email at $supportEmail. Updates live in $publicChannel.';

  String get communityBonusSummary =>
      'Join $publicChannel, then claim your one-time +$channelBonusDays day bonus.';
}
