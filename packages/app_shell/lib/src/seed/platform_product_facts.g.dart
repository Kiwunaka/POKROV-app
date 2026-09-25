// Generated from platform shared facts via scripts/sync_shared_surface_facts.py.
// Do not edit this projection by hand.

import 'package:pokrov_core_domain/core_domain.dart';

abstract final class PlatformProductFacts {
  static const productFactsSha256 =
      '2c135eeee91adaca52bc35b103ce5839e7f670e557ff7b55970c4375a2916f54';
  static const publicUrlsSha256 =
      '022f7ba577714bdc0bffd3cc00254309af346ef0c8fc62fe9c52e40d72a0de67';
  static const commercialRevision = '2026-09-25.1';
  static const commercialContractSha256 =
      '09b4353aad4bee5ba537da244af3b6fbfc79844de14460cd6ab53d13d1b57039';
  static const tariffCatalogSha256 =
      '2f9992d170f4b20b7175a83e5db28230e853fef5e3ff057b9afb6161b9421b6b';
  static const trialDays = 5;
  static const telegramRewardDays = 5;
  static const referralFriendDays = 5;
  static const referralReferrerDays = 10;
  static const referralHoldHours = 72;
  static const defaultRuntimeCore = RuntimeCore.singBox;
  static const advancedFallbackCore = RuntimeCore.xray;
  static const defaultRouteMode = RouteMode.allExceptRu;
  static const publicReleaseTargets = <ClientPlatform>[
    ClientPlatform.android,
    ClientPlatform.windows,
  ];
  static const readinessOnlyTargets = <ClientPlatform>[
    ClientPlatform.ios,
    ClientPlatform.macos,
  ];
  static const offerPath = '/offer/';
  static const privacyPath = '/privacy/';
  static const offerUrl = 'https://pokrov.space/offer/';
  static const privacyUrl = 'https://pokrov.space/privacy/';
  static const githubReleasesUrl = 'https://github.com/Kiwunaka/pokrov/releases';
  static const supportBot = '@pokrov_supportbot';
  static const feedbackBot = '@pokrov_feedbackbot';
  static const publicChannel = '@pokrov_vpn';
  static const supportEmail = 'support@pokrov.space';
}
