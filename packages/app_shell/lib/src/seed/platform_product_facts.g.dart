// Generated from platform shared facts via scripts/sync_shared_surface_facts.py.
// Do not edit this projection by hand.

import 'package:pokrov_core_domain/core_domain.dart';

abstract final class PlatformProductFacts {
  static const productFactsSha256 =
      '2c135eeee91adaca52bc35b103ce5839e7f670e557ff7b55970c4375a2916f54';
  static const publicUrlsSha256 =
      '022f7ba577714bdc0bffd3cc00254309af346ef0c8fc62fe9c52e40d72a0de67';
  static const commercialRevision = '2026-08-21.1';
  static const commercialContractSha256 =
      '22b7ef26908c23c2bb53322dec959a3bc050a20a6c6d2feff9f78708b45e23cd';
  static const tariffCatalogSha256 =
      '0e5acae30601854cee4c44c33af84e84bbdcd24d2788a7da1463bb3ee4a40d43';
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
