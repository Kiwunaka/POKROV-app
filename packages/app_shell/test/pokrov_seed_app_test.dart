import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_shell/src/design_system/design_system.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';
import 'package:pokrov_support_bundle/support_bundle.dart';

const _materializedRuntimeConfig =
    '{"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}';

const _paidSubscriptionInfo = ClientSubscriptionInfo(
  lane: 'paidUnlimited',
  expiresAt: '2026-07-22T00:00:00Z',
  daysLeft: 30,
  autoRenew: false,
  renewUrl: null,
  plans: <ClientSubscriptionPlan>[],
  trafficPolicy: <String, Object?>{},
);

const _featureLabelPrivateHelperCoverage = <String>[
  '_smartConnectNodeTitle',
  '_smartConnectNodeCity',
  '_smartConnectQualityLabel',
  '_locationQualityLabel',
  '_accessPoolLabel',
  '_accessMainLabel',
  '_accessShortValue',
  '_telegramBonusHomeLabel',
  '_routeModeShortLabel',
  '_routeModeRowTitle',
  '_routeModeRowSummary',
  '_PresetRow',
  '_rulesPresetIcon',
  '_rulesPresetStatusLabel',
];

const _navigationShellPrivateHelperCoverage = <String>[
  '_SeedContentList',
  '_DesktopShell',
  '_DesktopDrawerShell',
  '_MobileShell',
  '_DesktopSidebar',
  '_LazyIndexedStack',
  'createState',
  '_LazyIndexedStackState',
  'initState',
  'didUpdateWidget',
  '_markInitialized',
  '_BrandLockup',
  '_BrandMark',
  '_SidebarItem',
];

const _sharedShellWidgetPrivateHelperCoverage = <String>[
  '_SectionCard',
  '_SeedBackdrop',
  '_StatusPill',
  '_ConnectOrbButton',
  '_ConnectOrbButtonState',
  'didChangeDependencies',
  '_syncControllers',
  'AnimatedBuilder',
  '_ConnectSettleLayer',
  '_ConnectDiscRimPainter',
  'paint',
  'shouldRepaint',
];

const _infoSheetPrivateHelperCoverage = <String>[
  '_SettingsRow',
  '_showInfoSheet',
  '_InfoSheet',
];

const _appShellImplementationPrivateHelperCoverage = <String>[
  '_SelectSeedTabIntent',
  '_FocusSupportComposerIntent',
  '_SendSupportMessageIntent',
  '_MotionScope',
  '_KeyValueLine',
];

void _expectFeatureLabelHelpersCovered(Iterable<String> helpers) {
  for (final helper in helpers) {
    expect(_featureLabelPrivateHelperCoverage, contains(helper));
  }
}

void _expectNavigationShellHelpersCovered(Iterable<String> helpers) {
  for (final helper in helpers) {
    expect(_navigationShellPrivateHelperCoverage, contains(helper));
  }
}

void _expectSharedShellWidgetHelpersCovered(Iterable<String> helpers) {
  for (final helper in helpers) {
    expect(_sharedShellWidgetPrivateHelperCoverage, contains(helper));
  }
}

void _expectInfoSheetHelpersCovered(Iterable<String> helpers) {
  for (final helper in helpers) {
    expect(_infoSheetPrivateHelperCoverage, contains(helper));
  }
}

void _expectAppShellImplementationHelpersCovered(Iterable<String> helpers) {
  for (final helper in helpers) {
    expect(_appShellImplementationPrivateHelperCoverage, contains(helper));
  }
}

class _FakeBootstrapper
    implements
        ManagedProfileBootstrapper,
        AppFirstAccountActionService,
        AppFirstBonusActionService,
        AppFirstWarpActionService,
        AppFirstReleaseActionService,
        AppFirstFirstSessionEventService,
        AppFirstAcquisitionService,
        AppFirstNodePreferenceService,
        AppFirstClientDataService {
  _FakeBootstrapper(
    this.payload, {
    CabinetHandoff? cabinetHandoff,
    TelegramLinkResult? telegramLinkResult,
    ChannelBonusStatus? channelBonusStatus,
    ChannelBonusClaimResult? channelBonusClaimResult,
    AppFirstBonusSummary? bonusSummary,
    AppFirstRedeemResult? redeemResult,
    WarpControlStatus? warpStatus,
    ClientAppsMetadata? clientAppsMetadata,
    ClientLocationsCatalog? locationsCatalog,
    ClientSubscriptionInfo? subscriptionInfo,
    ClientNotificationInbox? notificationsInbox,
    ClientSupportAssistantReply? assistantReply,
    this.assistantGate,
    this.assistantFailureCalls = const <int>{},
    this.bonusSummaryGate,
    this.subscriptionGate,
    this.locationsCatalogGate,
    this.locationsCatalogFailure,
    this.notificationsFailure,
    this.managedProfileFailure,
    this.acquisitionFailure = false,
    this.managedProfileResolver,
    this.nodePreferenceGate,
  })  : cabinetHandoff = cabinetHandoff ??
            CabinetHandoff(
              token: 'short-cabinet-token',
              handoffUrl: Uri.parse('https://app.pokrov.space/profile'),
              expiresIn: const Duration(seconds: 120),
              targetPath: '/profile',
              scope: 'cabinet_handoff',
            ),
        telegramLinkResult = telegramLinkResult ??
            TelegramLinkResult(
              ok: true,
              linked: false,
              linkedTelegramId: null,
              linkedTelegramUsername: '',
              startCode: 'app-link-2026',
              botUrl:
                  Uri.parse('https://t.me/pokrov_vpnbot?start=app-link-2026'),
              channelUrl: Uri.parse('https://t.me/pokrov_vpn'),
            ),
        channelBonusStatus = channelBonusStatus ??
            const ChannelBonusStatus(
              ok: true,
              subscriber: true,
              reason: 'member',
              pointsGranted: 0,
              campaignMarked: false,
              linkRequired: false,
              claimRequired: true,
              alreadyClaimed: false,
              bonusDays: 5,
            ),
        channelBonusClaimResult = channelBonusClaimResult ??
            const ChannelBonusClaimResult(
              ok: true,
              alreadyClaimed: false,
              premiumDays: 5,
              claimedAt: '2026-06-03T12:00:00Z',
              expiryAt: '2026-06-13T12:00:00Z',
              subType: 'BONUS',
              channel: '@pokrov_vpn',
              linkedTelegramId: 777001,
              linkedTelegramUsername: 'linked_user',
            ),
        bonusSummary = bonusSummary ??
            const AppFirstBonusSummary(
              referralCount: 1,
              referralCode: 'POKROV1',
              referralBonusDays: 10,
              streakMonths: 0,
              lastWheelSpin: '',
              channelBonusPremiumDays: 5,
              channelBonusClaimedAt: '',
              openingBonusPremiumDays: 5,
              openingBonusClaimed: true,
              channelUsername: 'pokrov_vpn',
              tierKey: 'starter',
              tierPercent: 5,
              paidReferrals: 0,
              nextTierKey: 'pro',
              nextTierAt: 5,
            ),
        redeemResult = redeemResult ??
            const AppFirstRedeemResult(
              ok: true,
              kind: 'access_key',
              codePreview: '...2026',
              result: <String, dynamic>{},
            ),
        warpStatus =
            warpStatus ?? WarpControlStatus.fromPolicy(payload.warpPolicy),
        clientAppsMetadata = clientAppsMetadata ?? ClientAppsMetadata.empty,
        assistantReply = assistantReply ??
            const ClientSupportAssistantReply(
              reply: 'Test assistant reply.',
              shouldEscalate: false,
              suggestedActions: <ClientSupportAssistantAction>[],
            ),
        locationsCatalog = locationsCatalog ??
            const ClientLocationsCatalog(
              auto: ClientLocationAuto(enabled: true, currentCode: ''),
              countries: <ClientLocationCountry>[],
              freePoolCode: '',
              profileRevision: '',
              transportProfile: '',
              query: '',
            ),
        subscriptionInfo = subscriptionInfo ??
            ClientSubscriptionInfo(
              lane: 'trialPremium',
              expiresAt: '2026-06-27T00:00:00Z',
              daysLeft: 5,
              autoRenew: false,
              renewUrl: Uri.parse('https://pay.pokrov.space/checkout/test'),
              plans: const <ClientSubscriptionPlan>[
                ClientSubscriptionPlan(
                  id: '1m',
                  title: '1 month',
                  price: '299 RUB',
                ),
              ],
              trafficPolicy: const <String, Object?>{},
            ),
        notificationsInbox = notificationsInbox ??
            const ClientNotificationInbox(
              items: <ClientNotificationItem>[],
              nextCursor: '',
              unreadCount: 0,
            );

  final ManagedProfilePayload payload;
  final ManagedProfilePayload Function(
    int call,
    Set<String> excludedNodeCodes,
  )? managedProfileResolver;
  final AppFirstRedeemResult redeemResult;
  final CabinetHandoff cabinetHandoff;
  final TelegramLinkResult telegramLinkResult;
  final ChannelBonusStatus channelBonusStatus;
  final ChannelBonusClaimResult channelBonusClaimResult;
  final AppFirstBonusSummary bonusSummary;
  final ClientAppsMetadata clientAppsMetadata;
  final ClientLocationsCatalog locationsCatalog;
  ClientSubscriptionInfo subscriptionInfo;
  final ClientNotificationInbox notificationsInbox;
  final ClientSupportAssistantReply assistantReply;
  final Future<void>? assistantGate;
  final Set<int> assistantFailureCalls;
  final Future<void>? bonusSummaryGate;
  Future<void>? subscriptionGate;
  final Future<void>? locationsCatalogGate;
  final String? locationsCatalogFailure;
  final String? notificationsFailure;
  final BootstrapFailure? managedProfileFailure;
  final bool acquisitionFailure;
  Future<void>? nodePreferenceGate;
  BootstrapFailure? nodePreferenceFailure;
  int calls = 0;
  int redeemCalls = 0;
  int pairingClaimCalls = 0;
  int assistantCalls = 0;
  final List<String?> assistantSessionIds = <String?>[];
  final List<Map<String, Object?>> assistantDiagnostics =
      <Map<String, Object?>>[];
  String? lastAssistantMessage;
  Map<String, Object?>? lastAssistantDiagnostics;
  int cabinetCalls = 0;
  int telegramLinkCalls = 0;
  final List<String> telegramLinkEvents = <String>[];
  int channelBonusCheckCalls = 0;
  int channelBonusClaimCalls = 0;
  int bonusSummaryCalls = 0;
  int subscriptionCalls = 0;
  int notificationCalls = 0;
  final List<String> accountSummaryCallOrder = <String>[];
  int wheelSpinCalls = 0;
  int calendarCheckInCalls = 0;
  int warpStatusCalls = 0;
  int warpConsentCalls = 0;
  int warpRotationCalls = 0;
  int warpRuntimeEventCalls = 0;
  int clientAppsCalls = 0;
  int locationsCatalogCalls = 0;
  int pairingIssueCalls = 0;
  int pairingCancelCalls = 0;
  final List<String> markedNotificationIds = <String>[];
  final List<String> dismissedNotificationIds = <String>[];
  bool? lastWarpConsentEnabled;
  String? lastWarpRuntimeEventName;
  String? lastWarpRuntimeEventState;
  Map<String, Object?>? lastWarpRuntimeEventMeta;
  WarpControlStatus warpStatus;
  final tcpFallbackRequests = <String>[];
  RouteMode? lastRouteMode;
  HostPlatform? lastHostPlatform;
  String? lastRedeemCode;
  String? lastPairingCode;
  HostPlatform? lastRedeemHostPlatform;
  String? lastCabinetTargetPath;
  HostPlatform? lastCabinetHostPlatform;
  HostPlatform? lastTelegramLinkHostPlatform;
  HostPlatform? lastChannelBonusCheckHostPlatform;
  HostPlatform? lastChannelBonusClaimHostPlatform;
  HostPlatform? lastBonusSummaryHostPlatform;
  HostPlatform? lastWheelSpinHostPlatform;
  HostPlatform? lastCalendarCheckInHostPlatform;
  HostPlatform? lastClientAppsHostPlatform;
  String? lastClientAppsCurrentVersion;
  String? lastClientAppsChannel;
  HostPlatform? lastLocationsCatalogHostPlatform;
  String? lastLocationsCatalogQuery;
  String? lastPreferredNodeCode;
  String? lastPreferredVariantId;
  Set<String> lastExcludedNodeCodes = const <String>{};
  final List<Set<String>> excludedNodeCodeRequests = <Set<String>>[];
  final List<String> acquisitionHandoffs = <String>[];
  final List<String> firstSessionEvents = <String>[];

  @override
  Future<void> reportFirstSessionEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    required String stage,
    required String result,
    String errorCode = '',
    bool? retryable,
  }) async {
    firstSessionEvents.add(
      '${hostPlatform.name}:$eventName:$stage:$result:$errorCode:${retryable ?? ''}',
    );
  }

  @override
  Future<void> consumeAcquisitionHandoff({
    required HostPlatform hostPlatform,
    required String handle,
    required String purpose,
  }) async {
    if (acquisitionFailure) {
      throw StateError('expired acquisition handoff');
    }
    acquisitionHandoffs.add('${hostPlatform.name}:$purpose:$handle');
  }

  @override
  Future<SmartConnectPreferenceResult> setPreferredSmartConnectNode({
    required HostPlatform hostPlatform,
    required SmartConnectProfile smartConnect,
    required String nodeCode,
  }) async {
    await nodePreferenceGate;
    if (nodePreferenceFailure != null) {
      throw nodePreferenceFailure!;
    }
    return SmartConnectPreferenceResult(
      preferredNodeCode: nodeCode,
      acceptedSamples: 0,
    );
  }

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    Set<String> excludedNodeCodes = const <String>{},
    String tcpFallbackFromRevision = '',
    Duration? timeout,
  }) async {
    calls += 1;
    if (managedProfileFailure != null) {
      throw managedProfileFailure!;
    }
    tcpFallbackRequests.add(tcpFallbackFromRevision);
    lastRouteMode = routeMode;
    lastHostPlatform = hostPlatform;
    lastPreferredNodeCode = preferredNodeCode;
    lastPreferredVariantId = preferredVariantId;
    lastExcludedNodeCodes = Set<String>.unmodifiable(excludedNodeCodes);
    excludedNodeCodeRequests.add(lastExcludedNodeCodes);
    return managedProfileResolver?.call(calls, lastExcludedNodeCodes) ??
        payload;
  }

  @override
  Future<AppFirstRedeemResult> redeemCode({
    required HostPlatform hostPlatform,
    required String code,
  }) async {
    redeemCalls += 1;
    lastRedeemHostPlatform = hostPlatform;
    lastRedeemCode = code;
    return redeemResult;
  }

  @override
  Future<DevicePairingClaimResult> claimDevicePairingCode({
    required HostPlatform hostPlatform,
    required String code,
  }) async {
    pairingClaimCalls += 1;
    lastPairingCode = code;
    lastRedeemHostPlatform = hostPlatform;
    return const DevicePairingClaimResult(
      ok: true,
      accountId: 'paired-account',
      installId: 'paired-install',
    );
  }

  @override
  Future<CabinetHandoff> createCabinetHandoff({
    required HostPlatform hostPlatform,
    String targetPath = '/',
  }) async {
    cabinetCalls += 1;
    lastCabinetHostPlatform = hostPlatform;
    lastCabinetTargetPath = targetPath;
    return cabinetHandoff;
  }

  @override
  Future<TelegramLinkResult> createTelegramLink({
    required HostPlatform hostPlatform,
  }) async {
    telegramLinkCalls += 1;
    lastTelegramLinkHostPlatform = hostPlatform;
    return telegramLinkResult;
  }

  @override
  Future<void> reportTelegramLinkEvent({
    required HostPlatform hostPlatform,
    required String eventName,
  }) async {
    lastTelegramLinkHostPlatform = hostPlatform;
    telegramLinkEvents.add(eventName);
  }

  @override
  Future<ChannelBonusStatus> checkChannelBonus({
    required HostPlatform hostPlatform,
  }) async {
    channelBonusCheckCalls += 1;
    lastChannelBonusCheckHostPlatform = hostPlatform;
    return channelBonusStatus;
  }

  @override
  Future<ChannelBonusClaimResult> claimChannelBonus({
    required HostPlatform hostPlatform,
  }) async {
    channelBonusClaimCalls += 1;
    lastChannelBonusClaimHostPlatform = hostPlatform;
    return channelBonusClaimResult;
  }

  @override
  Future<AppFirstBonusSummary> fetchBonusSummary({
    required HostPlatform hostPlatform,
  }) async {
    await bonusSummaryGate;
    bonusSummaryCalls += 1;
    accountSummaryCallOrder.add('bonus');
    lastBonusSummaryHostPlatform = hostPlatform;
    return bonusSummary;
  }

  @override
  Future<ClientAppsMetadata> fetchClientApps({
    required HostPlatform hostPlatform,
    required String currentVersion,
    String channel = 'stable',
  }) async {
    clientAppsCalls += 1;
    lastClientAppsHostPlatform = hostPlatform;
    lastClientAppsCurrentVersion = currentVersion;
    lastClientAppsChannel = channel;
    return clientAppsMetadata;
  }

  @override
  Future<ClientLocationsCatalog> fetchLocationsCatalog({
    required HostPlatform hostPlatform,
    String query = '',
  }) async {
    locationsCatalogCalls += 1;
    lastLocationsCatalogHostPlatform = hostPlatform;
    lastLocationsCatalogQuery = query;
    if (locationsCatalogFailure != null) {
      throw BootstrapFailure(locationsCatalogFailure!);
    }
    await locationsCatalogGate;
    return locationsCatalog;
  }

  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({
    required HostPlatform hostPlatform,
  }) async {
    subscriptionCalls += 1;
    accountSummaryCallOrder.add('subscription:start');
    await subscriptionGate;
    accountSummaryCallOrder.add('subscription:end');
    return subscriptionInfo;
  }

  @override
  Future<ClientDeviceList> fetchClientDevices({
    required HostPlatform hostPlatform,
  }) async {
    return const ClientDeviceList(items: <ClientDeviceInfo>[]);
  }

  @override
  Future<bool> revokeClientDevice({
    required HostPlatform hostPlatform,
    required String deviceId,
  }) async {
    return true;
  }

  @override
  Future<ClientDevicePairingCode> issueDevicePairingCode({
    required HostPlatform hostPlatform,
  }) async {
    pairingIssueCalls += 1;
    return const ClientDevicePairingCode(
      id: 'pairing-1',
      code: 'ABCD-9XYZ',
      pairingUri: 'pokrov://pair?code=ABCD-9XYZ',
      expiresAt: '2030-01-01T00:10:00Z',
      ttlSeconds: 600,
    );
  }

  @override
  Future<bool> cancelDevicePairingCode({
    required HostPlatform hostPlatform,
    required String pairingId,
  }) async {
    pairingCancelCalls += 1;
    return true;
  }

  @override
  Future<ClientNotificationInbox> fetchClientNotifications({
    required HostPlatform hostPlatform,
    String after = '',
  }) async {
    notificationCalls += 1;
    if (notificationsFailure != null) {
      throw BootstrapFailure(notificationsFailure!);
    }
    return notificationsInbox;
  }

  @override
  Future<bool> markClientNotificationsRead({
    required HostPlatform hostPlatform,
    required List<String> ids,
  }) async {
    markedNotificationIds.addAll(ids);
    return true;
  }

  @override
  Future<bool> dismissClientNotifications({
    required HostPlatform hostPlatform,
    required List<String> ids,
  }) async {
    dismissedNotificationIds.addAll(ids);
    return true;
  }

  @override
  Future<ClientPushRegistration> registerClientPushToken({
    required HostPlatform hostPlatform,
    required String token,
    required String provider,
  }) async {
    return ClientPushRegistration(
      ok: true,
      provider: provider,
      tokenHash: 'test-token-hash',
    );
  }

  @override
  Future<ClientSupportAssistantReply> askSupportAssistant({
    required HostPlatform hostPlatform,
    required String message,
    int? ticketId,
    String? assistantSessionId,
    Map<String, Object?> safeDiagnostics = const <String, Object?>{},
  }) async {
    await assistantGate;
    assistantCalls += 1;
    assistantSessionIds.add(assistantSessionId);
    assistantDiagnostics.add(Map<String, Object?>.of(safeDiagnostics));
    lastAssistantMessage = message;
    lastAssistantDiagnostics = safeDiagnostics;
    if (assistantFailureCalls.contains(assistantCalls)) {
      throw const BootstrapFailure('Test assistant request failure.');
    }
    return assistantReply;
  }

  @override
  Future<AppFirstBonusRewardResult> spinBonusWheel({
    required HostPlatform hostPlatform,
  }) async {
    wheelSpinCalls += 1;
    lastWheelSpinHostPlatform = hostPlatform;
    return AppFirstBonusRewardResult(
      ok: true,
      rewardDays: 1,
      rewardKey: 'wheel_test',
      expiryAt: '2026-06-06T12:00:00Z',
      summary: bonusSummary,
    );
  }

  @override
  Future<AppFirstBonusRewardResult> checkInBonusCalendar({
    required HostPlatform hostPlatform,
  }) async {
    calendarCheckInCalls += 1;
    lastCalendarCheckInHostPlatform = hostPlatform;
    return AppFirstBonusRewardResult(
      ok: true,
      rewardDays: 1,
      rewardKey: 'calendar_test',
      expiryAt: '2026-06-06T12:00:00Z',
      summary: bonusSummary,
    );
  }

  @override
  Future<WarpControlStatus> fetchWarpStatus({
    required HostPlatform hostPlatform,
  }) async {
    warpStatusCalls += 1;
    return warpStatus;
  }

  @override
  Future<WarpControlStatus> setWarpConsent({
    required HostPlatform hostPlatform,
    required bool enabled,
    String reasonCode = '',
  }) async {
    warpConsentCalls += 1;
    lastWarpConsentEnabled = enabled;
    warpStatus = warpStatus.copyWith(
      canEnable: !enabled,
      consented: enabled,
      state: enabled ? 'consented' : 'revoked',
      consentedAt: enabled ? '2026-06-05T12:00:00Z' : '',
      revokedAt: enabled ? '' : '2026-06-05T12:01:00Z',
    );
    return warpStatus;
  }

  @override
  Future<WarpControlStatus> requestWarpRotation({
    required HostPlatform hostPlatform,
    String reasonCode = 'user_requested',
  }) async {
    warpRotationCalls += 1;
    warpStatus = warpStatus.copyWith(state: 'rotation_requested');
    return warpStatus;
  }

  @override
  Future<WarpControlStatus> reportWarpRuntimeEvent({
    required HostPlatform hostPlatform,
    required String eventName,
    String state = '',
    String reasonCode = '',
    String message = '',
    Map<String, Object?> meta = const <String, Object?>{},
  }) async {
    warpRuntimeEventCalls += 1;
    lastWarpRuntimeEventName = eventName;
    lastWarpRuntimeEventState = state;
    lastWarpRuntimeEventMeta = meta;
    warpStatus = warpStatus.copyWith(
      state: state.isEmpty ? warpStatus.state : state,
      lastEvent: <String, Object?>{'event_name': eventName},
    );
    return warpStatus;
  }
}

class _FakeSupportTicketService implements SupportTicketService {
  _FakeSupportTicketService(
    this.receipt, {
    List<SupportTicketThread> tickets = const <SupportTicketThread>[],
    SupportTicketThread? loadedThread,
    List<SupportTicketThread> loadedThreads = const <SupportTicketThread>[],
    SupportTicketThread? sentThread,
    this.listGate,
    this.failGetAfter = 0,
    this.failListCalls = const <int>{},
    this.failCreateCalls = const <int>{},
  })  : tickets = List<SupportTicketThread>.from(tickets),
        loadedThread = loadedThread ?? (tickets.isEmpty ? null : tickets.first),
        loadedThreads = List<SupportTicketThread>.from(loadedThreads),
        sentThread = sentThread ??
            (loadedThread ??
                (tickets.isEmpty
                    ? _supportThread(id: receipt.ticketId)
                    : tickets.first));

  final SupportTicketReceipt receipt;
  final List<SupportTicketThread> tickets;
  final SupportTicketThread? loadedThread;
  final List<SupportTicketThread> loadedThreads;
  final SupportTicketThread sentThread;
  final Future<void>? listGate;
  final int failGetAfter;
  final Set<int> failListCalls;
  final Set<int> failCreateCalls;
  int calls = 0;
  int listCalls = 0;
  int getCalls = 0;
  int sendCalls = 0;
  HostPlatform? lastHostPlatform;
  RouteMode? lastRouteMode;
  String? lastStatusLabel;
  String? lastSubject;
  String? lastBody;
  int? lastTicketId;
  String? lastReplyBody;
  RouteMode? lastReplyRouteMode;
  String? lastReplyStatusLabel;
  Map<String, Object?>? lastReplyDiagnostics;
  Map<String, Object?>? lastDiagnostics;

  @override
  Future<List<SupportTicketThread>> listTickets({
    required HostPlatform hostPlatform,
    int limit = 5,
  }) async {
    await listGate;
    listCalls += 1;
    lastHostPlatform = hostPlatform;
    if (failListCalls.contains(listCalls)) {
      throw const SupportTicketFailure('history unavailable');
    }
    return tickets.take(limit).toList(growable: false);
  }

  @override
  Future<SupportTicketThread> getTicket({
    required HostPlatform hostPlatform,
    required int ticketId,
  }) async {
    getCalls += 1;
    lastHostPlatform = hostPlatform;
    lastTicketId = ticketId;
    if (failGetAfter > 0 && getCalls >= failGetAfter) {
      throw const SupportTicketFailure('poll failed');
    }
    if (loadedThreads.isNotEmpty) {
      final index = (getCalls - 1).clamp(0, loadedThreads.length - 1);
      return loadedThreads[index];
    }
    return loadedThread ?? _supportThread(id: ticketId);
  }

  @override
  Future<SupportTicketReceipt> createTicket({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required String statusLabel,
    required String body,
    String subject = 'Поддержка POKROV',
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) async {
    calls += 1;
    if (failCreateCalls.contains(calls)) {
      throw const SupportTicketFailure('send unavailable');
    }
    lastHostPlatform = hostPlatform;
    lastRouteMode = routeMode;
    lastStatusLabel = statusLabel;
    lastSubject = subject;
    lastBody = body;
    lastDiagnostics = diagnostics;
    return receipt;
  }

  @override
  Future<SupportTicketThread> sendMessage({
    required HostPlatform hostPlatform,
    required int ticketId,
    required String body,
    RouteMode? routeMode,
    String statusLabel = '',
    Map<String, Object?> diagnostics = const <String, Object?>{},
  }) async {
    sendCalls += 1;
    lastHostPlatform = hostPlatform;
    lastTicketId = ticketId;
    lastReplyBody = body;
    lastReplyRouteMode = routeMode;
    lastReplyStatusLabel = statusLabel;
    lastReplyDiagnostics = diagnostics;
    return sentThread;
  }
}

class _FakeEncryptedSupportTicketService extends _FakeSupportTicketService
    implements SupportBundleTransferService {
  _FakeEncryptedSupportTicketService(super.receipt);

  int bundleCalls = 0;
  HostPlatform? lastBundleHostPlatform;
  String? lastBundleCaseSummary;
  int? lastBundleTicketId;
  PreparedSupportBundle? lastPreparedBundle;

  @override
  bool get supportBundleEncryptionConfigured => true;

  @override
  Future<SupportModeActivation> redeemSupportMode({
    required HostPlatform hostPlatform,
    required String activationCode,
    required String appVersion,
    required String buildNumber,
  }) =>
      throw const SupportBundleTransferFailure(
        'support_mode_unavailable',
        'not configured in this fixture',
      );

  @override
  Future<SupportBundleExportResult> exportSupportBundle({
    required HostPlatform hostPlatform,
    required PreparedSupportBundle prepared,
  }) async =>
      SupportBundleExportResult(
        state: SupportBundleExportState.exported,
        fileName: '${prepared.preview.diagnosticId}.pokrov-support',
      );

  @override
  Future<SupportBundleDeliveryResult> deliverSupportBundle({
    required HostPlatform hostPlatform,
    required PreparedSupportBundle prepared,
    required String caseSummary,
    int? ticketId,
  }) async {
    bundleCalls += 1;
    lastBundleHostPlatform = hostPlatform;
    lastBundleCaseSummary = caseSummary;
    lastBundleTicketId = ticketId;
    lastPreparedBundle = prepared;
    return SupportBundleDeliveryResult(
      state: SupportBundleDeliveryState.offlineEncrypted,
      diagnosticId: prepared.preview.diagnosticId,
      outboxReference: 'encrypted-outbox.pokrov-support',
      ticketId: ticketId ?? receipt.ticketId,
      failureCode: 'upload_deferred',
    );
  }
}

class _FakeFirstLaunchStore implements PokrovFirstLaunchStore {
  _FakeFirstLaunchStore({this.completed = false});

  bool completed;
  int readCalls = 0;
  int markCalls = 0;

  @override
  Future<bool> isCompleted() async {
    readCalls += 1;
    return completed;
  }

  @override
  Future<void> markCompleted() async {
    markCalls += 1;
    completed = true;
  }
}

class _FixedThemeModeStore extends PokrovFileThemeModeStore {
  const _FixedThemeModeStore(this.mode);

  final ThemeMode mode;

  @override
  Future<ThemeMode> read() async => mode;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _CompletedConnectHintStore extends PokrovFileConnectHintStore {
  const _CompletedConnectHintStore();

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}
}

class _FakeClientExperienceStore implements PokrovClientExperienceStore {
  _FakeClientExperienceStore([
    this.state = const PokrovClientExperienceState.empty(),
  ]);

  PokrovClientExperienceState state;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<PokrovClientExperienceState> read() async {
    readCalls += 1;
    return state;
  }

  @override
  Future<void> write(PokrovClientExperienceState next) async {
    writeCalls += 1;
    state = next;
  }
}

class _DelayedClientExperienceStore implements PokrovClientExperienceStore {
  _DelayedClientExperienceStore(this._staleState) : state = _staleState;

  final PokrovClientExperienceState _staleState;
  final Completer<PokrovClientExperienceState> _read =
      Completer<PokrovClientExperienceState>();
  PokrovClientExperienceState state;
  int readCalls = 0;
  int writeCalls = 0;

  void releaseStaleRead() {
    if (!_read.isCompleted) {
      _read.complete(_staleState);
    }
  }

  @override
  Future<PokrovClientExperienceState> read() {
    readCalls += 1;
    return _read.future;
  }

  @override
  Future<void> write(PokrovClientExperienceState next) async {
    writeCalls += 1;
    state = next;
  }
}

SupportTicketThread _supportThread({
  required int id,
  String status = 'open',
  String statusTitle = 'Open',
  List<SupportTicketMessage> messages = const <SupportTicketMessage>[],
}) {
  return SupportTicketThread(
    id: id,
    status: status,
    statusTitle: statusTitle,
    subject: 'Support',
    createdAt: '2026-06-03T00:00:00Z',
    updatedAt: '2026-06-03T00:01:00Z',
    closedAt: '',
    lastMessagePreview: messages.isEmpty ? '' : messages.last.body,
    messages: messages,
  );
}

SupportTicketMessage _supportMessage({
  required int id,
  required int ticketId,
  required String senderRole,
  required String body,
}) {
  return SupportTicketMessage(
    id: id,
    ticketId: ticketId,
    senderRole: senderRole,
    body: body,
    mediaType: '',
    mediaFileId: '',
    mediaPayload: '',
    createdAt: '2026-06-03T00:00:00Z',
  );
}

class _CachedBootstrapper extends _FakeBootstrapper
    implements CachedManagedProfileBootstrapper {
  _CachedBootstrapper(ManagedProfilePayload payload, {int status = 503})
      : super(payload, managedProfileFailure: BootstrapFailure('API unavailable', statusCode: status));
  final cacheReads = <bool>[];
  final provenEntries = <String>[];

  @override
  Future<ManagedProfilePayload?> loadCachedManagedProfile(
    ManagedProfileCacheInputs inputs, {bool preferProven = false}) async {
    cacheReads.add(preferProven);
    return payload;
  }

  @override
  Future<void> markManagedProfileProven(ManagedProfileCacheInputs inputs, String entryId) async {
    provenEntries.add(entryId);
  }
}

class _ThrowingBootstrapper implements ManagedProfileBootstrapper {
  _ThrowingBootstrapper(this.message);

  final String message;
  int calls = 0;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
    String preferredVariantId = 'direct',
    Set<String> excludedNodeCodes = const <String>{},
    String tcpFallbackFromRevision = '',
    Duration? timeout,
  }) async {
    calls += 1;
    throw BootstrapFailure(message);
  }
}

EmergencyCatalog _emergencyCatalog({
  int itemCount = 4,
  String accessState = 'trial_premium',
  String eligibilitySource = 'server_cached_ru',
}) {
  final now = DateTime.now().toUtc();
  return EmergencyCatalog(
    revision: 'emergency-widget-rev-$itemCount',
    issuedAt: now.subtract(const Duration(minutes: 1)),
    refreshAfter: now.add(const Duration(minutes: 5)),
    validUntil: now.add(const Duration(hours: 2)),
    offlineValidUntil: now.add(const Duration(hours: 1)),
    deviceBinding: 'widget-device-binding',
    accessState: accessState,
    accessExpiresAt: now.add(const Duration(days: 5)),
    eligibilitySource: eligibilitySource,
    eligibilityCountryCode: 'RU',
    eligibilityValidUntil: now.add(const Duration(hours: 2)),
    disclosureRevision: 'emergency-disclosure-widget-v1',
    items: List<EmergencyReserve>.generate(
      itemCount,
      (index) => EmergencyReserve(
        id: 'emg_${(index + 1).toRadixString(16).padLeft(24, '0')}',
        ordinal: index + 1,
        countryCode: index.isEven ? 'FR' : 'NL',
        transport: index.isEven ? 'tcp' : 'grpc',
        status: EmergencyReserveStatus.working,
        latencyMs: 70 + index,
        checkedAt: now.subtract(const Duration(minutes: 2)),
        verification: EmergencyVerificationLevel.syntheticBs,
        verificationAt: now.subtract(const Duration(minutes: 3)),
        modes: EmergencyChainMode.values,
      ),
      growable: false,
    ),
    envelope: const <String, dynamic>{'fixture': 'widget'},
  );
}

class _FakeEmergencyBootstrapper extends _FakeBootstrapper
    implements AppFirstEmergencyNetworkService {
  _FakeEmergencyBootstrapper({
    required this.catalogResult,
    this.catalogFailure,
    BootstrapFailure? managedProfileFailure,
  }) : super(
          const ManagedProfilePayload(
            profileName: 'normal-widget-profile',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
            warpPolicy: WarpRuntimePolicy.disabled,
          ),
          managedProfileFailure: managedProfileFailure,
        );

  final AppFirstEmergencyCatalogResult catalogResult;
  final BootstrapFailure? catalogFailure;
  final List<bool> manualLimitedNetworkCalls = <bool>[];
  int emergencyProfileCalls = 0;
  String lastEmergencyReserveId = '';
  EmergencyChainMode? lastEmergencyChainMode;
  final List<(String, EmergencyChainMode)> emergencyProfileRequests =
      <(String, EmergencyChainMode)>[];

  @override
  Future<AppFirstEmergencyCatalogResult> fetchEmergencyCatalog({
    required HostPlatform hostPlatform,
    required bool manualLimitedNetwork,
    bool forceRefresh = false,
  }) async {
    manualLimitedNetworkCalls.add(manualLimitedNetwork);
    final failure = catalogFailure;
    if (failure != null) {
      throw failure;
    }
    return catalogResult;
  }

  @override
  Future<void> prepareEmergencyOfflineCache({
    required HostPlatform hostPlatform,
    bool manualLimitedNetwork = false,
  }) async {}

  @override
  Future<AppFirstEmergencyProfileResult> resolveEmergencyProfile({
    required HostPlatform hostPlatform,
    required String catalogRevision,
    required String reserveId,
    required EmergencyChainMode chainMode,
    required bool manualLimitedNetwork,
  }) async {
    emergencyProfileCalls += 1;
    lastEmergencyReserveId = reserveId;
    lastEmergencyChainMode = chainMode;
    emergencyProfileRequests.add((reserveId, chainMode));
    final now = DateTime.now().toUtc();
    return AppFirstEmergencyProfileResult(
      profile: EmergencyProfile(
        catalogRevision: catalogRevision,
        profileRevision: 'emergency-widget-profile-v1',
        issuedAt: now,
        offlineValidUntil: now.add(const Duration(hours: 1)),
        deviceBinding: 'widget-device-binding',
        reserveId: reserveId,
        chainMode: chainMode,
        accessState: 'trial_premium',
        configPayload: const <String, dynamic>{
          'outbounds': <Object?>[
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
          ],
          'route': <String, Object?>{'final': 'direct'},
        },
        envelope: const <String, dynamic>{'fixture': 'widget-profile'},
      ),
      managedProfile: const ManagedProfilePayload(
        profileName: 'emergency-widget-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        quickSettingsEligible: false,
        routeMode: RouteMode.allExceptRu,
        warpPolicy: WarpRuntimePolicy.disabled,
      ),
      usingCache: false,
    );
  }
}

void _installReadyRuntimeBridgeMock({
  List<String>? calls,
  List<String>? stagedPayloads,
  Map<String, Object?>? variantProbeSnapshot,
  bool reportDegradedAfterConnect = false,
  bool failFirstConnect = false,
  bool failAllEmergencyConnects = false,
  bool failAfterConnect = false,
  bool failApplyWarp = false,
  bool retainHealthyConnectedSnapshot = false,
  Future<void>? connectGate,
}) {
  const channel = MethodChannel('space.pokrov/runtime_engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var connected = false;
  var connectCalls = 0;

  messenger.setMockMethodCallHandler(channel, (call) async {
    calls?.add(call.method);
    switch (call.method) {
      case 'runtimeEngine.snapshot':
        if ((failAllEmergencyConnects ||
                (failFirstConnect && connectCalls == 1)) &&
            connectCalls > 0 &&
            !connected) {
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'last_failure_kind': 'emergency_endpoint_unreachable',
            'message': 'Этот резерв недоступен в текущей сети.',
          };
        }
        if (failAfterConnect && connected && connectCalls == 1) {
          connected = false;
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'last_failure_kind': 'core_egress_probe_failed',
            'message': 'Выход через выбранную локацию не подтверждён.',
          };
        }
        if (failAfterConnect && connected && connectCalls > 1) {
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'hostHealth': 'healthy',
            'dnsState': 'healthy',
            'uplinkState': 'healthy',
            'core_egress_validated': true,
            'message': 'Android runtime service is running.',
          };
        }
        if (retainHealthyConnectedSnapshot && connected) {
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'hostHealth': 'healthy',
            'dnsState': 'healthy',
            'uplinkState': 'healthy',
            'core_egress_validated': true,
            'message': 'Android runtime service is running.',
          };
        }
        if (reportDegradedAfterConnect && connected) {
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'core_egress_validated': true,
            'message': 'Android runtime service is running.',
            'hostDiagnostics': <String, Object?>{
              'health': 'degraded',
              'dnsStatus': 'degraded',
              'uplinkStatus': 'healthy',
              'summary': 'Runtime dataplane errors were classified.',
            },
          };
        }
        return <String, Object?>{
          'phase': 'artifactReady',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Host bridge ready.',
        };
      case 'runtimeEngine.initialize':
        return <String, Object?>{
          'phase': 'initialized',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Runtime bootstrap completed on the host bridge.',
        };
      case 'runtimeEngine.stageManagedProfile':
        final arguments = call.arguments as Map<Object?, Object?>?;
        stagedPayloads?.add(arguments?['configPayload'] as String? ?? '');
        return <String, Object?>{
          'phase': 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Managed profile staged on the host bridge.',
        };
      case 'runtimeEngine.connect':
        await connectGate;
        connectCalls += 1;
        if (failAllEmergencyConnects ||
            (failFirstConnect && connectCalls == 1)) {
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'last_failure_kind': 'emergency_endpoint_unreachable',
            'message': 'Этот резерв недоступен в текущей сети.',
          };
        }
        connected = true;
        return <String, Object?>{
          'phase': 'running',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'hostHealth': 'healthy',
          'dnsState': 'healthy',
          'uplinkState': 'healthy',
          'core_egress_validated':
              failAfterConnect || reportDegradedAfterConnect ? null : true,
          'message': 'Runtime service is running.',
        };
      case 'runtimeEngine.disconnect':
        connected = false;
        return <String, Object?>{
          'phase': 'initialized',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Runtime service stopped.',
        };
      case 'runtimeEngine.applyWarp':
        return <String, Object?>{
          'applied': !failApplyWarp,
          'effectiveAt': failApplyWarp ? 'none' : 'now',
          'fallbackUsed': false,
          if (failApplyWarp) 'reason': 'missing_staged_profile',
        };
      case 'runtimeEngine.measureLocationVariants':
        return variantProbeSnapshot ??
            <String, Object?>{
              'observedAtMs': DateTime.now().millisecondsSinceEpoch,
              'activeVariantId': '',
              'results': const <Object?>[],
              'errorCategory': 'profile_unavailable',
            };
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

Future<void> _completeFirstLaunchIfPresent(WidgetTester tester) async {
  final newUser = find.byKey(const ValueKey('first-launch-new-user'));
  if (newUser.evaluate().isEmpty) {
    return;
  }
  await tester.tap(newUser);
  await tester.pumpAndSettle();
}

Future<void> _confirmFirstRouteScopeIfPresent(
  WidgetTester tester, {
  RouteMode mode = RouteMode.allExceptRu,
}) async {
  final wholeDevice =
      find.byKey(const ValueKey('first-connect-scope-whole-device'));
  if (wholeDevice.evaluate().isEmpty) {
    return;
  }
  final choice = mode == RouteMode.selectedApps
      ? find.byKey(const ValueKey('first-connect-scope-selected-apps'))
      : wholeDevice;
  expect(choice, findsOneWidget);
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

Future<void> _tapPrimaryConnectAndConfirmRouteScope(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
  await tester.pumpAndSettle();
  await _confirmFirstRouteScopeIfPresent(tester);
}

Future<void> _tapNav(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openAdvancedRules(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('rules-advanced-toggle'));
  await tester.dragUntilVisible(
    toggle,
    find.byType(Scrollable).first,
    const Offset(0, -320),
    maxIteration: 12,
  );
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('rules-advanced-open')), findsOneWidget);
}

Future<void> _openEnhancedProtectionFromProfile(WidgetTester tester) async {
  if (find.byKey(const ValueKey('nav-profile')).evaluate().isEmpty) {
    final hamburger = find.byKey(const ValueKey('desktop-sidebar-hamburger'));
    if (hamburger.evaluate().isNotEmpty) {
      await tester.tap(hamburger);
      await tester.pumpAndSettle();
    }
  }
  await _tapNav(tester, 'nav-profile');
  final action =
      find.byKey(const ValueKey('profile-enhanced-protection-action'));
  await tester.dragUntilVisible(
    action,
    find.byType(Scrollable).first,
    const Offset(0, -260),
    maxIteration: 12,
  );
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _openRedeemSheetFromProfile(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('profile-redeem-code-action'));
  await tester.dragUntilVisible(
    action,
    find.byType(Scrollable).first,
    const Offset(0, -220),
  );
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('profile-redeem-sheet')), findsOneWidget);
}

Future<void> _openRewardsHubFromProfile(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('profile-bonus-wheel-action'));
  await tester.dragUntilVisible(
    action,
    find.byType(Scrollable).first,
    const Offset(0, -240),
    maxIteration: 12,
  );
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('rewards-hub-sheet')), findsOneWidget);
}

Future<void> _openSupportChatFromProfile(WidgetTester tester) async {
  await _tapNav(tester, 'nav-profile');
  final support = find.byKey(const ValueKey('profile-section-support'));
  await tester.dragUntilVisible(
    support,
    find.byType(Scrollable).first,
    const Offset(0, -260),
    maxIteration: 12,
  );
  await tester.pumpAndSettle();
  await tester.tap(support);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('support-chat-screen')), findsOneWidget);
}

void main() {
  testWidgets('inactive app mutes animation ticks including modal routes',
      (tester) async {
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() async {
      PokrovLoopingMotion.debugLoopingOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 250));
      tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      firstLaunchStore: _FakeFirstLaunchStore(completed: true),
    ));
    await tester.pumpAndSettle();
    final homeContext =
        tester.element(find.byKey(const ValueKey('primary-connect-action')));
    PokrovLoopingMotion.debugLoopingOverride = true;
    unawaited(showDialog<void>(
      context: homeContext,
      builder: (_) => const Dialog(child: PokrovSkeletonList(rows: 1)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    final pulse = find.byKey(PokrovSkeletonPulse.motionKey);
    double opacity() => tester.widget<FadeTransition>(pulse).opacity.value;
    final activeOpacity = opacity();
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(), isNot(activeOpacity));

    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final inactiveOpacity = opacity();
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), inactiveOpacity);
    expect(TickerMode.of(tester.element(pulse)), isFalse);

    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final resumedOpacity = opacity();
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(), isNot(resumedOpacity));
    expect(TickerMode.of(tester.element(pulse)), isTrue);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('consumes only valid host-bound acquisition continuation once',
      (tester) async {
    const handle = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    const otherHandle = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'acquisition-test',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final links = StreamController<Uri>();
    addTearDown(links.close);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        initialAcquisitionUri: Uri.parse(
          'pokrov://acquisition/continue?handle=$handle&purpose=android_install',
        ),
        acquisitionUriStream: links.stream,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    links.add(
      Uri.parse(
        'pokrov://acquisition/continue?handle=$handle&purpose=android_install',
      ),
    );
    links.add(
      Uri.parse(
        'pokrov://acquisition/continue?handle=$otherHandle&purpose=windows_install',
      ),
    );
    await tester.pump();

    expect(bootstrapper.acquisitionHandoffs, <String>[
      'android:android_install:$handle',
    ]);
  });

  testWidgets('acquisition confirmation never hides trial or restore choices',
      (tester) async {
    const handle = 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'acquisition-choice-test',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        initialAcquisitionUri: Uri.parse(
          'pokrov://acquisition/continue?handle=$handle&purpose=android_install',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-acquisition-linked')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('first-launch-new-user')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('first-launch-returning-user')),
      findsOneWidget,
    );
  });

  testWidgets('expired acquisition leaves normal access paths usable',
      (tester) async {
    const handle = 'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD';
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'acquisition-failure-test',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      acquisitionFailure: true,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        initialAcquisitionUri: Uri.parse(
          'pokrov://acquisition/continue?handle=$handle&purpose=android_install',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-acquisition-failed')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('first-launch-new-user')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
  });

  testWidgets(
      'disposing after a hanging Quick Settings invalidation cancels its timeout',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final invalidateCompleter = Completer<Map<String, Object?>>();
    const initialized = <String, Object?>{
      'phase': 'initialized',
      'artifactDirectory': '/host/runtime',
      'coreBinaryPath': '/host/runtime/pokrov-core.aar',
      'supportsLiveConnect': true,
      'canInitialize': true,
      'canConnect': false,
      'message': 'Runtime initialized.',
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
        case 'runtimeEngine.initialize':
          return initialized;
        case 'runtimeEngine.invalidateManagedProfile':
          return invalidateCompleter.future;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('first-connect-scope-whole-device')),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final action in [
    'connect',
    'repair',
    'repair-stale',
    'repair-timeout',
  ]) {
    final repair = action != 'connect';
    final changeDuringStage = action == 'repair-stale';
    testWidgets(
      'Quick Settings invalidation coalesces a held burst before $action',
      (tester) async {
        const channel = MethodChannel('space.pokrov/runtime_engine');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final first = Completer<Map<String, Object?>>();
        final second = Completer<Map<String, Object?>>();
        final stageResult = Completer<Map<String, Object?>>();
        var invalidations = 0;
        final calls = <String>[];
        const ready = <String, Object?>{
          'phase': 'initialized',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Runtime initialized.',
        };
        final staged = <String, Object?>{
          ...ready,
          'phase': 'configStaged',
          'stagedConfigPath': '/host/runtime/synthetic-profile.json',
          'canConnect': true,
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'runtimeEngine.snapshot':
            case 'runtimeEngine.initialize':
              return ready;
            case 'runtimeEngine.invalidateManagedProfile':
              return ++invalidations == 1 ? first.future : second.future;
            case 'runtimeEngine.stageManagedProfile':
              return changeDuringStage ? stageResult.future : staged;
            case 'runtimeEngine.connect':
              return <String, Object?>{
                ...ready,
                'phase': 'running',
                'canConnect': true,
              };
          }
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final store = _FakeClientExperienceStore(
          const PokrovClientExperienceState.empty().copyWith(
            firstRouteScopeConfirmed: true,
            firstRouteScopeMode: RouteMode.fullTunnel,
          ),
        );
        await tester.pumpWidget(
          PokrovSeedApp(
            appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
            bootstrapper: _FakeBootstrapper(
              const ManagedProfilePayload(
                profileName: 'burst',
                configPayload: _materializedRuntimeConfig,
                materializedForRuntime: true,
              ),
            ),
            firstLaunchStore: _FakeFirstLaunchStore(completed: true),
            clientExperienceStore: store,
          ),
        );
        await tester.pumpAndSettle();
        await _tapNav(tester, 'nav-rules');
        for (var i = 0; i < 10; i += 1) {
          await tester.tap(
            find.byKey(
              ValueKey(
                'rules-mode-row-${i.isEven ? 'allExceptRu' : 'fullTunnel'}',
              ),
            ),
          );
          await tester.pump();
        }
        expect(invalidations, 1);
        await _tapNav(tester, 'nav-protection');
        if (repair) {
          await tester.tap(
            find.byKey(const ValueKey('home-connection-details-action')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('protection-repair-action')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('protection-repair-confirm')),
          );
        } else {
          await tester.tap(
            find.byKey(const ValueKey('primary-connect-action')),
          );
        }
        await tester.pump();
        expect(calls, isNot(contains('runtimeEngine.stageManagedProfile')));
        if (action == 'repair-timeout') {
          await tester.pump(const Duration(seconds: 18));
          await tester.pumpAndSettle();
          expect(calls, isNot(contains('runtimeEngine.stageManagedProfile')));
          expect(calls, isNot(contains('runtimeEngine.connect')));
          first.complete(ready);
          await tester.pumpAndSettle();
          expect(calls, isNot(contains('runtimeEngine.stageManagedProfile')));
          expect(calls, isNot(contains('runtimeEngine.connect')));
          return;
        }
        first.complete(ready);
        await tester.pump();
        expect(invalidations, 2);
        expect(calls, isNot(contains('runtimeEngine.stageManagedProfile')));
        second.complete(ready);
        if (changeDuringStage) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        } else {
          await tester.pumpAndSettle();
        }
        expect(invalidations, 2);
        expect(
          calls.where((it) => it == 'runtimeEngine.stageManagedProfile'),
          hasLength(1),
        );
        if (changeDuringStage) {
          // A user can dismiss the repair sheet and change routing while a slow
          // host stage still acknowledges the old profile.
          expect(
            find.byKey(const ValueKey('protection-repair-progress')),
            findsOneWidget,
          );
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const ValueKey('nav-rules')));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(
            find.byKey(const ValueKey('rules-mode-row-allExceptRu')),
          );
          await tester.pump();
          expect(invalidations, 3);
          stageResult.complete(staged);
          await tester.pumpAndSettle();
          expect(calls, isNot(contains('runtimeEngine.connect')));
        } else {
          expect(
            calls.where((it) => it == 'runtimeEngine.connect'),
            hasLength(1),
          );
        }
      },
    );
  }

  test(
      'android seed app context keeps smoke profile free of desktop route keys',
      () {
    final context = buildSeedAppContext(hostPlatform: HostPlatform.android);
    expect(
      context.managedProfileSeed.configPayload,
      isNot(contains('auto_detect_interface')),
    );
    expect(
      context.managedProfileSeed.configPayload,
      isNot(contains('override_android_vpn')),
    );
  });

  test('public route choices expose selected apps in P3', () {
    for (final hostPlatform in <HostPlatform>[
      HostPlatform.android,
      HostPlatform.windows,
    ]) {
      expect(hostPlatform.supportsSelectedAppsMode, isTrue);
      final context = buildSeedAppContext(hostPlatform: hostPlatform);

      expect(
        context.runtimeProfile.supportedRouteModes,
        containsAll(const [
          RouteMode.allExceptRu,
          RouteMode.fullTunnel,
          RouteMode.selectedApps,
        ]),
      );
      expect(
        context.runtimeProfile.supportedRouteModes
            .contains(RouteMode.excludedApps),
        hostPlatform == HostPlatform.android,
      );
    }
  });

  testWidgets('first launch keeps Home visible and offers soft recovery',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-choice-screen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-shell')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('first-launch-new-user')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-choice-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );
  });

  testWidgets('trial selection provisions account data and reports one journey',
      (tester) async {
    final store = _FakeFirstLaunchStore();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'first-session-events',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.subscriptionCalls, 0,
        reason: 'account provisioning waits for the access choice');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(bootstrapper.subscriptionCalls, 0,
        reason: 'foreground return cannot select a trial or restore account');
    expect(bootstrapper.notificationCalls, 0,
        reason: 'the welcome screen cannot start a session through inbox reads');
    await tester.tap(find.byKey(const ValueKey('first-launch-new-user')));
    await tester.pumpAndSettle();

    expect(
      bootstrapper.firstSessionEvents.map((event) => event.split(':')[1]),
      <String>[
        'app_first_open',
        'trial_start_selected',
        'first_home_seen',
      ],
    );
    expect(bootstrapper.subscriptionCalls, greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: store,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      bootstrapper.firstSessionEvents
          .where((event) => event.contains(':app_first_open:')),
      hasLength(1),
    );
    expect(
      bootstrapper.firstSessionEvents
          .where((event) => event.contains(':first_home_seen:')),
      hasLength(1),
    );
  });

  testWidgets('completed first launch skips the startup choice screen',
      (tester) async {
    final store = _FakeFirstLaunchStore(completed: true);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(store.readCalls, 1);
    expect(
      find.byKey(const ValueKey('first-launch-choice-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );
  });

  testWidgets('first launch choice uses new and returning access copy',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POKROV VPN'), findsWidgets);
    expect(find.text('Добро пожаловать'), findsOneWidget);
    expect(find.text('Начать бесплатно'), findsOneWidget);
    expect(find.text('5 дней премиум-доступа'), findsOneWidget);
    expect(find.text('У меня есть код'), findsOneWidget);
    expect(find.text('Восстановить доступ'), findsOneWidget);
    expect(find.textContaining('логин'), findsNothing);
    expect(find.textContaining('регистра'), findsNothing);
    expect(find.textContaining('raw'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();

    expect(find.text('Восстановить доступ'), findsOneWidget);
    expect(
      find.text(
        'Введите одноразовый код устройства из бота или кабинета. Код активации из Telegram, сайта или письма тоже подойдет.',
      ),
      findsOneWidget,
    );
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Получить код в боте'), findsOneWidget);
    expect(find.text('Открыть кабинет'), findsOneWidget);
  });

  testWidgets('first-session actions remain reachable at 200 percent text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    final returning = find.byKey(const ValueKey('first-launch-returning-user'));
    await tester.ensureVisible(returning);
    expect(returning, findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'access choice at 200%');
    await tester.tap(returning);
    await tester.pumpAndSettle();

    final redeem = find.byKey(const ValueKey('first-launch-restore-redeem'));
    await tester.ensureVisible(redeem);
    expect(redeem, findsOneWidget);
    expect(
      find.byKey(const ValueKey('first-launch-restore-code-field')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull, reason: 'restore step at 200%');
  });

  testWidgets('restore step focuses the code field and back returns to choice',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();

    final fieldFinder =
        find.byKey(const ValueKey('first-launch-restore-code-field'));
    expect(fieldFinder, findsOneWidget);
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.autofocus, isTrue);
    expect(field.textCapitalization, TextCapitalization.characters);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);

    // Android system back returns to the new/returning choice instead of
    // backgrounding the app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-restore-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('first-launch-choice-screen')),
      findsOneWidget,
    );
  });

  testWidgets('seed shell lazily builds tabs and keeps opened tabs alive',
      (tester) async {
    _expectNavigationShellHelpersCovered(const [
      '_SeedContentList',
      '_MobileShell',
      '_LazyIndexedStack',
      'createState',
      '_LazyIndexedStackState',
      'initState',
      'didUpdateWidget',
      '_markInitialized',
    ]);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('locations-auto-section'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('profile-compact-account-layer'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('nav-support')), findsNothing);

    await _tapNav(tester, 'nav-profile');
    expect(
      find.byKey(
        const ValueKey('profile-compact-account-layer'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    await _tapNav(tester, 'nav-protection');
    expect(
      find.byKey(
        const ValueKey('profile-compact-account-layer'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('new user first launch completion is persisted', (tester) async {
    final store = _FakeFirstLaunchStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('first-launch-new-user')));
    await tester.pumpAndSettle();

    expect(store.markCalls, 1);
    expect(store.completed, isTrue);
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(store.readCalls, 2);
    expect(
      find.byKey(const ValueKey('first-launch-choice-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );
  });

  testWidgets('returning first launch restores through unified redeem',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-restore-screen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('first-launch-manual-key-warning')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('first-launch-restore-code-field')),
      'POKROV-ACCESS-2026',
    );
    await tester.tap(find.byKey(const ValueKey('first-launch-restore-redeem')));
    await tester.pumpAndSettle();

    expect(bootstrapper.redeemCalls, 1);
    expect(bootstrapper.lastRedeemCode, 'POKROV-ACCESS-2026');
    expect(bootstrapper.lastRedeemHostPlatform, HostPlatform.android);
    expect(launched, isEmpty);
    expect(
      find.byKey(const ValueKey('first-launch-restore-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );
    expect(
      bootstrapper.firstSessionEvents.map((event) => event.split(':')[1]),
      containsAllInOrder(<String>[
        'app_first_open',
        'existing_access_selected',
        'first_home_seen',
      ]),
    );
  });

  testWidgets('returning first launch opens main bot pairing code',
      (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('first-launch-open-telegram-code')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'tg');
    expect(launched.single.queryParameters['domain'], 'pokrov_vpnbot');
    expect(launched.single.queryParameters['start'], 'pair_device');
  });

  testWidgets('returning first launch claims a one-time device code',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('first-launch-restore-code-field')),
      'ABCD-9XYZ',
    );
    await tester.tap(find.byKey(const ValueKey('first-launch-restore-redeem')));
    await tester.pumpAndSettle();

    expect(bootstrapper.pairingClaimCalls, 1);
    expect(bootstrapper.lastPairingCode, 'ABCD-9XYZ');
    expect(bootstrapper.redeemCalls, 0);
    expect(bootstrapper.subscriptionCalls, greaterThanOrEqualTo(2));
    expect(
      find.byKey(const ValueKey('first-launch-restore-screen')),
      findsNothing,
    );
    expect(
        find.text('Устройство и профиль привязаны. Код больше не действует.'),
        findsOneWidget);
  });

  testWidgets('returning first launch rejects raw subscription links locally',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-manual-key-warning')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('first-launch-restore-code-field')),
      'https://connect.pokrov.space/s8Kx2mP7qR4wT/raw-subscription-token',
    );
    await tester.tap(find.byKey(const ValueKey('first-launch-restore-redeem')));
    await tester.pumpAndSettle();

    expect(bootstrapper.redeemCalls, 0);
    expect(
      find.textContaining('Ссылка подключения не привязывает аккаунт'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('first-launch-restore-screen')),
      findsOneWidget,
    );
  });

  testWidgets('renders premium shell v2 with compact first screen',
      (tester) async {
    _expectFeatureLabelHelpersCovered(const [
      '_accessPoolLabel',
      '_accessMainLabel',
      '_accessShortValue',
      '_telegramBonusHomeLabel',
      '_routeModeShortLabel',
    ]);
    _expectSharedShellWidgetHelpersCovered(const [
      '_SeedBackdrop',
      '_StatusPill',
    ]);
    _expectAppShellImplementationHelpersCovered(const ['_MotionScope']);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('mobile-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('motion-policy')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-boot-reveal')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.text('POKROV VPN'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-location-chip'))).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const ValueKey('home-route-chip'))).dy,
        1,
      ),
    );
    final homeWarpTile = find.byKey(const ValueKey('home-warp-tile'));
    expect(homeWarpTile, findsOneWidget);
    expect(find.textContaining('Дополнительная защита'), findsNothing);
    expect(find.byKey(const ValueKey('home-warp-info-action')), findsOneWidget);
    expect(find.descendant(of: homeWarpTile, matching: find.text('WARP')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('home-access-strip')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-telegram-bonus-pill')), findsNothing);
    expect(find.byKey(const ValueKey('home-news-card')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-location-chip')),
        matching: find.byType(Text),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-route-chip')),
        matching: find.byType(Text),
      ),
      findsWidgets,
    );

    expect(find.text('Р’Р°С€ РѕСЃРЅРѕРІРЅРѕР№ СЂРµРіРёРѕРЅ'), findsNothing);
    expect(find.text('РќРѕРІРѕСЃС‚Рё Рё СѓРІРµРґРѕРјР»РµРЅРёСЏ'), findsNothing);
    expect(find.text('Р§С‚Рѕ РѕСЃС‚Р°РµС‚СЃСЏ РїСЂРѕСЃС‚С‹Рј'), findsNothing);
    expect(find.text('РЎС‚Р°С‚СѓСЃ РїРѕРґРєР»СЋС‡РµРЅРёСЏ'), findsNothing);
    expect(find.text('РЈСЃРёР»РµРЅРЅС‹Р№ СЂРµР¶РёРј'), findsNothing);
    expect(find.text('Telegram-Р±РѕРЅСѓСЃ'), findsNothing);
    expect(find.text('Email Рё РєР°Р±РёРЅРµС‚'), findsNothing);

    await _tapNav(tester, 'nav-profile');
    expect(find.text('Р’С‹ СЂР°РЅСЊС€Рµ РїРѕР»СЊР·РѕРІР°Р»РёСЃСЊ POKROV?'),
        findsNothing);
    expect(find.text('Telegram-Р±РѕРЅСѓСЃ'), findsNothing);
    expect(find.text('Email Рё РєР°Р±РёРЅРµС‚'), findsNothing);
    expect(find.byKey(const ValueKey('profile-section-sync')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-section-app')), findsOneWidget);
    expect(find.text('Р‘РѕРЅСѓСЃС‹'), findsNothing);
    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(support, findsOneWidget);
    expect(find.byKey(const ValueKey('profile-guides-action')), findsOneWidget);
    final diagnostics =
        find.byKey(const ValueKey('profile-diagnostics-action'));
    await tester.dragUntilVisible(
      diagnostics,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(diagnostics, findsOneWidget);
  });

  testWidgets('home renders admin promotion only when backend exposes one',
      (tester) async {
    const summary = AppFirstBonusSummary(
      referralCount: 0,
      referralCode: 'POKROV',
      referralBonusDays: 10,
      streakMonths: 0,
      lastWheelSpin: '',
      channelBonusPremiumDays: 5,
      channelBonusClaimedAt: '',
      openingBonusPremiumDays: 5,
      openingBonusClaimed: true,
      channelUsername: 'pokrov_vpn',
      tierKey: 'starter',
      tierPercent: 0,
      paidReferrals: 0,
      nextTierKey: '',
      nextTierAt: 0,
      promoSlots: AppFirstPromoSlots(
        surface: 'app',
        accessState: 'trial',
        remoteAvailable: true,
        fallbackBehavior: 'contextual_only_when_remote_unavailable',
        mode: 'whitelist_slots',
        slots: <AppFirstPromoSlot>[
          AppFirstPromoSlot(
            slotId: 'home-tg-bonus',
            contentId: 'tg-bonus',
            enabled: true,
            title: 'Подарок за Telegram',
            body: 'Подпишитесь на канал и заберите дополнительные дни.',
            ctaLabel: 'Открыть',
            ctaHref: 'https://t.me/pokrov_vpn',
            placement: 'home_banner',
            dismissible: true,
            kind: 'promo',
            goal: 'telegram_bonus',
          ),
          AppFirstPromoSlot(
            slotId: 'rewards-only',
            contentId: 'rewards',
            enabled: true,
            title: 'Только в бонусах',
            body: 'Не должен появиться на Home.',
            ctaLabel: 'Открыть',
            ctaHref: 'https://t.me/pokrov_vpn',
            placement: 'rewards',
            kind: 'promo',
            goal: 'rewards',
          ),
        ],
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: summary,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-news-card')), findsNothing);
    expect(find.byKey(const ValueKey('home-admin-promo-card')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-admin-promo-dismiss')), findsOneWidget);
    expect(find.text('Подарок за Telegram'), findsOneWidget);
    expect(find.text('Только в бонусах'), findsNothing);
    final dismissPromo = find.byKey(const ValueKey('home-admin-promo-dismiss'));
    await tester.ensureVisible(dismissPromo);
    await tester.pumpAndSettle();
    await tester.tap(dismissPromo);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-admin-promo-card')), findsNothing);
  });

  testWidgets('home renders exact ready winback commercial terms',
      (tester) async {
    const summary = AppFirstBonusSummary(
      referralCount: 0,
      referralCode: 'POKROV',
      referralBonusDays: 10,
      streakMonths: 0,
      lastWheelSpin: '',
      channelBonusPremiumDays: 5,
      channelBonusClaimedAt: '',
      openingBonusPremiumDays: 5,
      openingBonusClaimed: true,
      channelUsername: 'pokrov_vpn',
      tierKey: 'starter',
      tierPercent: 0,
      paidReferrals: 0,
      nextTierKey: '',
      nextTierAt: 0,
      promoSlots: AppFirstPromoSlots(
        surface: 'app',
        accessState: 'expired_or_blocked',
        remoteAvailable: true,
        fallbackBehavior: 'contextual_only_when_remote_unavailable',
        mode: 'whitelist_slots',
        slots: <AppFirstPromoSlot>[
          AppFirstPromoSlot(
            slotId: 'app.home.banner',
            contentId: 'winback_offer',
            enabled: true,
            title: 'Верните защиту',
            body: 'Три месяца по персональной цене.',
            ctaLabel: 'Вернуться',
            ctaHref:
                'https://pay.pokrov.space/checkout/?checkout_ticket=ticket',
            placement: 'home_banner',
            dismissible: false,
            wholeCardClickable: false,
            endsAt: '2099-08-25T18:30:00Z',
            countdownMode: 'ends_at',
            pilotId: 'release_1_2_winback_paid_7_30d',
            pilotRevision: '2026-08-22.1',
            pilotContractSha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            commercialRevision: '2026-08-21.1',
            campaignId: 'cmp_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            offerId: 'off_cccccccccccccccccccccccccccccccc',
            creativeId: 'crv_dddddddddddddddddddddddddddddddd',
            variant: 'a',
            assignmentId: 'asg_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            impressionId: 'imp_ffffffffffffffffffffffffffffffff',
            clickId: 'clk_11111111111111111111111111111111',
            offerState: 'ready',
            reasonCode: 'ready',
            planCode: '3_months',
            currency: 'RUB',
            basePriceRub: 669,
            finalPriceRub: 602,
            benefitPercent: 10,
            remainingQuotaLowerBound: 12,
            termsUrl: 'https://pokrov.space/offer/',
            kind: 'first_party_winback',
            goal: 'winback_paid_access',
          ),
        ],
      ),
    );
    final opened = <Uri>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: summary,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-admin-promo-card')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-admin-promo-price')), findsOneWidget);
    expect(find.text('669 ₽ → 602 ₽'), findsOneWidget);
    expect(
      find.textContaining('доступно не более 12'),
      findsOneWidget,
    );
    final terms = find.byKey(const ValueKey('home-admin-promo-terms'));
    expect(terms, findsOneWidget);
    await tester.ensureVisible(terms);
    await tester.pumpAndSettle();
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(opened, <Uri>[Uri.parse('https://pokrov.space/offer/')]);
  });

  testWidgets('home admin promotion ignores unsafe CTA schemes',
      (tester) async {
    const summary = AppFirstBonusSummary(
      referralCount: 0,
      referralCode: 'POKROV',
      referralBonusDays: 10,
      streakMonths: 0,
      lastWheelSpin: '',
      channelBonusPremiumDays: 5,
      channelBonusClaimedAt: '',
      openingBonusPremiumDays: 5,
      openingBonusClaimed: true,
      channelUsername: 'pokrov_vpn',
      tierKey: 'starter',
      tierPercent: 0,
      paidReferrals: 0,
      nextTierKey: '',
      nextTierAt: 0,
      promoSlots: AppFirstPromoSlots(
        surface: 'app',
        accessState: 'trial',
        remoteAvailable: true,
        fallbackBehavior: 'contextual_only_when_remote_unavailable',
        mode: 'whitelist_slots',
        slots: <AppFirstPromoSlot>[
          AppFirstPromoSlot(
            slotId: 'unsafe-home-promo',
            contentId: 'unsafe',
            enabled: true,
            title: 'Важное сообщение',
            body: 'Проверяем безопасную ссылку.',
            ctaLabel: 'Открыть',
            ctaHref: 'javascript://pokrov.space/steal',
            placement: 'home_banner',
            dismissible: true, // user-dismissable remote Home campaign
            kind: 'promo',
            goal: 'safety',
          ),
        ],
      ),
    );
    final opened = <Uri>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: summary,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await tester.pumpAndSettle();

    final promo = find.byKey(const ValueKey('home-admin-promo-card'));
    expect(promo, findsOneWidget);
    expect(find.text('Открыть'), findsNothing);
    await tester.ensureVisible(promo);
    await tester.pumpAndSettle();
    await tester.tap(promo);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets(
      'home promo stays usable at 320px with countdown and mandatory policy',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final summary = AppFirstBonusSummary(
      referralCount: 0,
      referralCode: 'POKROV',
      referralBonusDays: 10,
      streakMonths: 0,
      lastWheelSpin: '',
      channelBonusPremiumDays: 5,
      channelBonusClaimedAt: '',
      openingBonusPremiumDays: 5,
      openingBonusClaimed: true,
      channelUsername: 'pokrov_vpn',
      tierKey: 'starter',
      tierPercent: 0,
      paidReferrals: 0,
      nextTierKey: '',
      nextTierAt: 0,
      promoSlots: AppFirstPromoSlots(
        surface: 'app',
        accessState: 'paid_unlimited',
        remoteAvailable: true,
        fallbackBehavior: 'contextual_only_when_remote_unavailable',
        mode: 'whitelist_slots',
        serverTime: DateTime.now().toUtc().toIso8601String(),
        slots: <AppFirstPromoSlot>[
          AppFirstPromoSlot(
            slotId: 'mandatory-sale',
            contentId: 'partner_promo',
            enabled: true,
            title: 'Скидка −70% только сегодня',
            body:
                'Готовая акция не должна выталкивать кнопку или обрезать важный текст на узком экране.',
            badgeLabel: '24 часа',
            ctaLabel: 'Посмотреть предложение',
            ctaHref: 'https://pokrov.space/pricing/',
            placement: 'home_banner',
            dismissible: false,
            countdownMode: 'ends_at',
            countdownLabel: 'Осталось',
            endsAt: DateTime.now()
                .toUtc()
                .add(const Duration(hours: 24))
                .toIso8601String(),
            kind: 'promo',
            goal: 'renewal',
          ),
          const AppFirstPromoSlot(
            slotId: 'global-info',
            contentId: 'incident_notice',
            enabled: true,
            title: '',
            body: '',
            ctaLabel: '',
            ctaHref: '',
            mediaType: 'image',
            mediaUrl:
                'https://api.pokrov.space/api/public/promo-media/demo.png',
            imageLayout: 'media_only',
            mediaWidth: 1600,
            mediaHeight: 900,
            placement: 'global_banner',
            dismissible: true,
            kind: 'notice',
            goal: 'status',
          ),
          const AppFirstPromoSlot(
            slotId: 'banner-info',
            contentId: 'partner_promo',
            enabled: true,
            title: 'Демо −70%',
            body: 'Короткое описание акции.',
            ctaLabel: 'Подробнее',
            ctaHref: 'https://pokrov.space/pricing/',
            mediaType: 'animated_image',
            mediaUrl:
                'https://api.pokrov.space/api/public/promo-media/demo.gif',
            imageLayout: 'banner',
            mediaWidth: 1600,
            mediaHeight: 900,
            placement: 'home_corner',
            dismissible: true,
            kind: 'promo',
            goal: 'renewal',
          ),
        ],
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: summary,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'before promo scroll');
    final card = find.byKey(const ValueKey('home-admin-promo-card'));
    await tester.ensureVisible(card);
    await tester.pump();

    expect(card, findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-admin-promo-dismiss')), findsNothing);
    expect(find.byKey(const ValueKey('home-admin-promo-countdown')),
        findsOneWidget);
    expect(find.text('Посмотреть предложение'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final globalCard = find.byKey(
      const ValueKey('home-admin-promo-global-info-card'),
    );
    expect(globalCard, findsOneWidget);
    await tester.ensureVisible(globalCard);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final globalDismiss = find.byKey(
      const ValueKey('home-admin-promo-global-info-dismiss'),
    );
    final globalMedia = find.byKey(
      const ValueKey('home-admin-promo-global-info-media'),
    );
    expect(globalDismiss, findsOneWidget);
    expect(globalMedia, findsOneWidget);
    expect(
      tester.getRect(globalDismiss).bottom,
      lessThanOrEqualTo(tester.getRect(globalMedia).top),
      reason: 'media-only close hit target must not cover the artwork',
    );
    expect(
      tester.getRect(globalDismiss).right,
      lessThanOrEqualTo(tester.getRect(globalCard).right),
      reason: 'media-only close must stay inside the promo frame',
    );
    final bannerCard = find.byKey(
      const ValueKey('home-admin-promo-banner-info-card'),
    );
    expect(bannerCard, findsOneWidget);
    await tester.ensureVisible(bannerCard);
    await tester.pump();
    final bannerDismiss = find.byKey(
      const ValueKey('home-admin-promo-banner-info-dismiss'),
    );
    final bannerMedia = find.byKey(
      const ValueKey('home-admin-promo-banner-info-media'),
    );
    expect(bannerDismiss, findsOneWidget);
    expect(bannerMedia, findsOneWidget);
    expect(
      tester.getRect(bannerMedia).top,
      lessThanOrEqualTo(tester.getRect(bannerCard).top + 2),
      reason: 'banner artwork must not gain an empty close-button header',
    );
    expect(
      tester.getRect(bannerDismiss).top,
      greaterThanOrEqualTo(tester.getRect(bannerMedia).bottom),
      reason: 'banner close target must sit with copy, not over artwork',
    );
    final cardRect = tester.getRect(card);
    final actionRect = tester.getRect(
      find.byKey(const ValueKey('home-admin-promo-action')),
    );
    expect(actionRect.left, greaterThanOrEqualTo(cardRect.left));
    expect(actionRect.right, lessThanOrEqualTo(cardRect.right));
    expect(actionRect.bottom, lessThanOrEqualTo(cardRect.bottom));
  });

  testWidgets('startup update downloads through verified Android installer',
      (tester) async {
    final launched = <Uri>[];
    final installed = <ClientAppUpdateInfo>[];
    final installCompleter = Completer<PokrovClientUpdateInstallStatus>();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      clientAppsMetadata: const ClientAppsMetadata(
        android: ClientAppPlatformMetadata(
          platform: 'android',
          primaryUrl:
              'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov-android-universal.apk',
          mirrorUrl: '',
          version: '1.0.1-beta',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          size: 123456,
          releaseNotes: 'Небольшие исправления бета-версии.',
          releaseNotesUrl: '',
          publishedAt: '2026-06-07T00:00:00Z',
          update: ClientAppUpdateInfo(
            platform: 'android',
            channel: 'beta',
            latestVersion: '1.0.1-beta',
            minSupportedVersion: '1.0.0-beta',
            updatePolicy: 'recommended',
            url:
                'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov-android-universal.apk',
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            size: 123456,
            releaseNotes: 'Небольшие исправления бета-версии.',
            releaseNotesUrl: '',
            publishedAt: '2026-06-07T00:00:00Z',
          ),
        ),
        windows: ClientAppPlatformMetadata.emptyWindows,
        docsUrl: 'https://pokrov.space/install/',
        updatedAt: '2026-06-07T00:00:00Z',
        updateCheckMode: 'prompt',
        silentUpdate: false,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
        clientUpdateInstaller: (update) {
          installed.add(update);
          return installCompleter.future;
        },
        clientUpdateProgressReader: () async =>
            const PokrovClientUpdateProgress(
          phase: PokrovClientUpdateProgressPhase.downloading,
          downloadedBytes: 61728,
          totalBytes: 123456,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.clientAppsCalls, 1);
    expect(bootstrapper.lastClientAppsCurrentVersion, pokrovClientVersion);
    expect(bootstrapper.lastClientAppsChannel, 'stable');
    expect(find.byKey(const ValueKey('client-update-prompt')), findsOneWidget);
    expect(find.text('Небольшие исправления бета-версии.'), findsOneWidget);
    expect(find.text('Свежая версия: 1.0.1-beta.'), findsOneWidget);
    expect(find.text('Официальный канал POKROV · 121 КБ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('client-update-download')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('client-update-download-progress')),
        findsOneWidget);
    expect(find.text('Скачано 50%'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('client-update-progress-bar')),
    );
    expect(progress.value, 0.5);

    installCompleter.complete(
      PokrovClientUpdateInstallStatus.installerOpened,
    );
    await tester.pumpAndSettle();

    expect(installed, hasLength(1));
    expect(installed.single.url, contains('/Kiwunaka/pokrov/releases/'));
    expect(launched, isEmpty);
    expect(find.byKey(const ValueKey('client-update-download-progress')),
        findsNothing);
  });

  testWidgets('startup update check ignores untrusted download metadata',
      (tester) async {
    final launched = <Uri>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      clientAppsMetadata: const ClientAppsMetadata(
        android: ClientAppPlatformMetadata(
          platform: 'android',
          primaryUrl:
              'https://github.com/Kiwunaka/pokrov/releases/download/v1.0.1-beta/pokrov-android-universal.apk',
          mirrorUrl: '',
          version: '1.0.1-beta',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          size: 123456,
          releaseNotes: 'Небольшие исправления бета-версии.',
          releaseNotesUrl: '',
          publishedAt: '2026-06-07T00:00:00Z',
          update: ClientAppUpdateInfo(
            platform: 'android',
            channel: 'beta',
            latestVersion: '1.0.1-beta',
            minSupportedVersion: '1.0.0-beta',
            updatePolicy: 'required',
            url: 'https://evil.example/pokrov-android-universal.apk',
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            size: 123456,
            releaseNotes: 'Небольшие исправления бета-версии.',
            releaseNotesUrl: '',
            publishedAt: '2026-06-07T00:00:00Z',
          ),
        ),
        windows: ClientAppPlatformMetadata.emptyWindows,
        docsUrl: 'https://pokrov.space/install/',
        updatedAt: '2026-06-07T00:00:00Z',
        updateCheckMode: 'prompt',
        silentUpdate: false,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.clientAppsCalls, 1);
    expect(find.byKey(const ValueKey('client-update-prompt')), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('home status opens independent protection checks',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('home-connection-details-action')),
        findsOneWidget);
    expect(find.text('Состояние защиты'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('home-connection-details-action')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Состояние защиты'), findsOneWidget);
    expect(find.byKey(const ValueKey('protection-summary')), findsOneWidget);
    expect(find.text('Туннель'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('protection-details-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Туннель'), findsOneWidget);
    expect(find.text('Адреса сайтов'), findsOneWidget);
    expect(find.text('Выход через VPN'), findsOneWidget);
    expect(find.text('Маршруты'), findsOneWidget);
    expect(
      find.text('POKROV проверяет соединение на этом устройстве.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('protection-repair-action')),
      findsOneWidget,
    );
  });

  testWidgets('protection center maps Android runtime failures to safe copy',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'running',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'tls_handshake_failed at https://10.24.0.5:443/vless',
          'last_failure_kind': 'tls_handshake_failed',
          'hostDiagnosticsSummary':
              'resolver_timeout 10.24.0.5:443 protocol=vless',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-connection-details-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('protection-details-toggle')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Защищённый канал до выбранной локации не отвечает. Попробуйте другую локацию или подключитесь снова.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('tls_handshake_failed'), findsNothing);
    expect(find.textContaining('resolver_timeout'), findsNothing);
    expect(find.textContaining('10.24.0.5'), findsNothing);
    expect(find.textContaining('vless'), findsNothing);
  });

  testWidgets(
      'protection repair runs one bounded disconnect stage connect loop',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final runtimeCalls = <String>[];
    var phase = 'running';
    var coreEgressValidated = false;

    Map<String, Object?> snapshot(
        {String message = 'Runtime service is running.'}) {
      return <String, Object?>{
        'phase': phase,
        'artifactDirectory': '/host/runtime',
        'coreBinaryPath': '/host/runtime/libcore.aar',
        if (phase == 'running' || phase == 'configStaged')
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
        'supportsLiveConnect': true,
        'canInitialize': true,
        'canConnect': phase != 'artifactReady',
        'message': message,
        'hostHealth': phase == 'running'
            ? (coreEgressValidated ? 'healthy' : 'degraded')
            : 'unknown',
        'dnsState': phase == 'running' ? 'healthy' : 'unknown',
        'uplinkState': phase == 'running' ? 'healthy' : 'unknown',
        'core_egress_validated':
            phase == 'running' ? coreEgressValidated : null,
        'ipv4RouteCount': phase == 'running' ? 2 : 0,
        'ipv6RouteCount': phase == 'running' ? 1 : 0,
      };
    }

    messenger.setMockMethodCallHandler(channel, (call) async {
      runtimeCalls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot();
        case 'runtimeEngine.disconnect':
          phase = 'initialized';
          return snapshot(message: 'Runtime service stopped.');
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
          return snapshot(message: 'Managed profile staged.');
        case 'runtimeEngine.connect':
          phase = 'running';
          coreEgressValidated = true;
          return snapshot();
        case 'runtimeEngine.liveStats':
          return <String, Object?>{
            'available': true,
            'latencyMs': 41,
            'downlinkBps': 2048,
            'uplinkBps': 1024,
            'serverCode': 'nl-ams-01',
            'serverCountry': 'NL',
            'protocol': 'VLESS Reality',
          };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final store = _FakeClientExperienceStore();
    final launched = <Uri>[];
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
        clientExperienceStore: store,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-connection-details-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('protection-details-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Требует внимания'), findsOneWidget);
    expect(find.text('Готов'), findsOneWidget);
    expect(find.text('Не подтверждён'), findsOneWidget);
    expect(find.text('Назначены'), findsOneWidget);
    expect(find.textContaining('41 мс'), findsOneWidget);

    runtimeCalls.clear();
    final repairAction = find.byKey(const ValueKey('protection-repair-action'));
    expect(repairAction, findsOneWidget);
    expect(tester.getRect(repairAction).bottom, lessThanOrEqualTo(844));
    await tester.tap(repairAction);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('protection-repair-confirmation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('protection-repair-confirm')));
    await tester.pumpAndSettle();

    expect(
      runtimeCalls,
      containsAllInOrder(const <String>[
        'runtimeEngine.disconnect',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.disconnect'),
      hasLength(1),
    );
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(1),
    );
    expect(bootstrapper.calls, greaterThanOrEqualTo(1));
    expect(find.text('Активен'), findsOneWidget);
    expect(store.state.protectionEvents.first.kind, 'repair_success');
    expect(find.text('История защиты'), findsOneWidget);
    expect(
      tester.getRect(repairAction).top,
      lessThan(tester
          .getRect(find.byKey(const ValueKey('protection-history-card')))
          .top),
    );

    final addShortcut = find.byKey(const ValueKey('post-connect-shortcut-add'));
    await tester.ensureVisible(addShortcut);
    await tester.pumpAndSettle();
    await tester.tap(addShortcut);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-connect-shortcut-label')),
      'Docs',
    );
    await tester.enterText(
      find.byKey(const ValueKey('post-connect-shortcut-href')),
      'https://docs.example/start',
    );
    await tester.tap(
      find.byKey(const ValueKey('post-connect-shortcut-save')),
    );
    await tester.pumpAndSettle();

    expect(store.state.postConnectShortcuts.single.label, 'Docs');
    expect(launched, isEmpty);
    final shortcut = find.text('Docs');
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(launched.single, Uri.parse('https://docs.example/start'));
  });

  testWidgets('repair warns before disconnect and exposes three-step progress',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final disconnectResult = Completer<Object?>();
    var phase = 'running';
    var healthy = false;
    Map<String, Object?> snapshot({bool healthy = false}) => <String, Object?>{
          'phase': phase,
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'hostHealth': healthy ? 'healthy' : 'degraded',
          'dnsState': healthy ? 'healthy' : 'unknown',
          'uplinkState': healthy ? 'healthy' : 'unknown',
          'dns_ready': healthy,
          'core_egress_validated': healthy,
          'core_egress_validation_required': false,
          'message': healthy ? 'Protected.' : 'Needs repair.',
        };
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot(healthy: healthy);
        case 'runtimeEngine.disconnect':
          return disconnectResult.future;
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
          return snapshot();
        case 'runtimeEngine.connect':
          phase = 'running';
          healthy = true;
          return snapshot(healthy: healthy);
        case 'runtimeEngine.liveStats':
          return <String, Object?>{'available': false};
      }
      return null;
    });
    addTearDown(() {
      if (!disconnectResult.isCompleted) {
        phase = 'initialized';
        disconnectResult.complete(snapshot());
      }
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'repair-progress',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-connection-details-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('protection-repair-action')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Интернет может пропасть на несколько секунд'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('protection-repair-confirm')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('protection-repair-progress')),
      findsOneWidget,
    );
    expect(find.text('1. Останавливаем старое соединение'), findsOneWidget);
    expect(find.text('2. Обновляем профиль'), findsOneWidget);
    expect(find.text('3. Проверяем защиту'), findsOneWidget);

    phase = 'initialized';
    disconnectResult.complete(snapshot());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('protection-repair-progress')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('protection-repair-outcome')),
      findsOneWidget,
    );
    expect(find.text('Защита восстановлена'), findsOneWidget);
  });

  testWidgets(
      'repair profile failure keeps the sheet on the fresh stopped snapshot',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var phase = 'running';
    Map<String, Object?> snapshot() => <String, Object?>{
          'phase': phase,
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/libcore.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': phase != 'artifactReady',
          'message': phase == 'running'
              ? 'Runtime service is running.'
              : 'Runtime service stopped.',
        };
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot();
        case 'runtimeEngine.disconnect':
          phase = 'initialized';
          return snapshot();
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'never-staged',
        configPayload: '{}',
        materializedForRuntime: true,
      ),
      managedProfileFailure: const BootstrapFailure('Профиль недоступен.'),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await tester.tap(
      find.byKey(const ValueKey('home-connection-details-action')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('protection-details-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('protection-repair-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('protection-repair-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Отключён'), findsOneWidget);
    expect(find.text('Активен'), findsNothing);
    expect(
      find.text(
        'Восстановление не завершилось. Показано состояние после остановки туннеля.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('protection-repair-support')),
      findsOneWidget,
    );
  });

  testWidgets('profile uses grouped MVP account sections', (tester) async {
    _expectInfoSheetHelpersCovered(const ['_SettingsRow']);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    expect(find.byKey(const ValueKey('profile-section-plan-access')),
        findsOneWidget);
    final accessHeadline = tester.widget<Text>(
      find.text('Статус доступа уточняется'),
    );
    expect(accessHeadline.maxLines, 2);
    expect(accessHeadline.overflow, TextOverflow.clip);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('profile-connection-status-pill'),
        ),
        matching: find.byIcon(Icons.shield_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-section-sync')), findsOneWidget);
    final appSection = find.byKey(const ValueKey('profile-section-app'));
    await tester.dragUntilVisible(
      appSection,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(appSection, findsOneWidget);
    final supportSection =
        find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      supportSection,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('profile-section-support')), findsOneWidget);

    final diagnostics =
        find.byKey(const ValueKey('profile-diagnostics-action'));
    await tester.dragUntilVisible(
      diagnostics,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(diagnostics, findsOneWidget);
  });

  testWidgets(
      'live paid subscription replaces trial copy across home and profile',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'paid-ui',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: const ClientSubscriptionInfo(
        lane: 'paidUnlimited',
        expiresAt: '2026-07-22T00:00:00Z',
        daysLeft: 30,
        autoRenew: false,
        renewUrl: null,
        plans: <ClientSubscriptionPlan>[],
        trafficPolicy: <String, Object?>{},
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.text('Премиум · 30 дней'), findsOneWidget);
    expect(find.textContaining('пробного доступа'), findsNothing);

    await _tapNav(tester, 'nav-profile');
    await tester.pumpAndSettle();
    expect(find.text('30 дней доступа'), findsOneWidget);
    expect(find.text('30 дней'), findsWidgets);
    expect(find.textContaining('пробного доступа'), findsNothing);
  });

  testWidgets(
      'expired subscription replaces seed trial copy across home and profile',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'expired-ui',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: const ClientSubscriptionInfo(
        lane: 'expiredOrBlocked',
        expiresAt: '2026-07-22T00:00:00Z',
        daysLeft: 0,
        autoRenew: false,
        renewUrl: null,
        plans: <ClientSubscriptionPlan>[],
        trafficPolicy: <String, Object?>{'kind': 'blocked'},
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.text('Продлить'), findsOneWidget);
    expect(find.textContaining('пробного доступа'), findsNothing);

    await _tapNav(tester, 'nav-profile');
    await tester.pumpAndSettle();
    expect(find.text('Доступ не активен'), findsWidgets);
    expect(find.textContaining('пробного доступа'), findsNothing);
  });

  testWidgets('Android notification sheet keeps details inside the app',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Map<Object?, Object?>? savedArguments;
    var notificationSettingsCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.systemSurfacePreferences':
          return <String, Object?>{
            'showCountry': true,
            'showSpeed': true,
            'showRouteMode': true,
          };
        case 'runtimeEngine.updateSystemSurfacePreferences':
          savedArguments = call.arguments as Map<Object?, Object?>?;
          return call.arguments;
        case 'runtimeEngine.openNotificationSettings':
          notificationSettingsCalls += 1;
          return true;
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'system-surfaces',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');
    final action = find.byKey(
      const ValueKey('profile-system-surfaces-action'),
    );
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-system-surfaces-sheet')),
      findsOneWidget,
    );
    expect(find.text('Приватный статус'), findsOneWidget);
    expect(
      find.textContaining('только внутри разблокированного POKROV'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('system-surface-country-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('system-surface-speed-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('system-surface-route-toggle')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('system-surface-notification-settings-action'),
      ),
    );
    await tester.pumpAndSettle();

    expect(notificationSettingsCalls, 1);
    expect(savedArguments, isNull);
  });

  testWidgets(
      'profile explains managed free-profile states without premium copy',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final cases = <({FreeProfileAccess access, String label, String? notice})>[
      (
        access: const FreeProfileAccess(
          accessState: 'free_monthly',
          transition: FreeProfileTransition.softTransitionPending,
          activeRole: 'free_standard',
          softModeActive: false,
          provisioningJobId: 81,
          errorCode: null,
          isConsistent: true,
        ),
        label: 'Обновляем базовый доступ',
        notice:
            'Мы обновляем базовый доступ. Попробуйте подключиться через минуту.',
      ),
      (
        access: const FreeProfileAccess(
          accessState: 'free_monthly',
          transition: FreeProfileTransition.error,
          activeRole: 'free_standard',
          softModeActive: false,
          provisioningJobId: 81,
          errorCode: 'panel_timeout',
          isConsistent: true,
        ),
        label: 'Базовый доступ требует обновления',
        notice:
            'Не удалось обновить базовый доступ. Обновите настройки через минуту; если это повторится, обратитесь в поддержку.',
      ),
      (
        access: const FreeProfileAccess(
          accessState: 'free_soft_mode',
          transition: FreeProfileTransition.softActive,
          activeRole: 'free_soft',
          softModeActive: true,
          provisioningJobId: null,
          errorCode: null,
          isConsistent: true,
        ),
        label: 'Базовый режим',
        notice:
            'Лимит базового режима закончился. Доступ продолжится в базовом режиме.',
      ),
      (
        access: const FreeProfileAccess(
          accessState: 'free_monthly',
          transition: FreeProfileTransition.standard,
          activeRole: 'free_standard',
          softModeActive: false,
          provisioningJobId: null,
          errorCode: null,
          isConsistent: true,
        ),
        label: 'Базовый режим',
        notice: null,
      ),
    ];

    for (final testCase in cases) {
      final bootstrapper = _FakeBootstrapper(
        ManagedProfilePayload(
          profileName: 'free-profile-${testCase.access.transition.name}',
          configPayload: _materializedRuntimeConfig,
          materializedForRuntime: true,
          freeProfileAccess: testCase.access,
        ),
      );
      await tester.pumpWidget(
        PokrovSeedApp(
          appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
          bootstrapper: bootstrapper,
          firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        ),
      );
      await tester.pumpAndSettle();
      await _tapPrimaryConnectAndConfirmRouteScope(tester);
      await tester.pumpAndSettle();
      await _tapNav(tester, 'nav-profile');

      final accessSection =
          find.byKey(const ValueKey('profile-section-plan-access'));
      expect(
        find.descendant(of: accessSection, matching: find.text(testCase.label)),
        findsOneWidget,
      );
      if (testCase.notice == null) {
        expect(find.byKey(const ValueKey('profile-free-access-notice')),
            findsNothing);
      } else {
        expect(find.text(testCase.notice!), findsOneWidget);
      }
      expect(find.text('panel_timeout'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('profile theme selector switches light and dark mode',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    final themeAction = find.byKey(const ValueKey('profile-theme-action'));
    await tester.dragUntilVisible(
      themeAction,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    await tester.tap(themeAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-theme-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-theme-system')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-theme-light')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-theme-dark')), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('profile-theme-system')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('profile-theme-dark')));
    await tester.pumpAndSettle();

    expect(find.text('Тёмная'), findsOneWidget);
    expect(
      Theme.of(
              tester.element(find.byKey(const ValueKey('profile-section-app'))))
          .brightness,
      Brightness.dark,
    );

    await tester.tap(themeAction);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('profile-theme-dark')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('profile-theme-light')));
    await tester.pumpAndSettle();

    expect(find.text('Светлая'), findsOneWidget);
    expect(
      Theme.of(
              tester.element(find.byKey(const ValueKey('profile-section-app'))))
          .brightness,
      Brightness.light,
    );
    semantics.dispose();
  });

  testWidgets('profile legal rows open generated platform URLs',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        handoffLauncher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-profile');

    final offerAction = find.byKey(const ValueKey('profile-offer-action'));
    await tester.ensureVisible(offerAction);
    await tester.pumpAndSettle();
    await tester.tap(offerAction);
    await tester.pump();

    final privacyAction = find.byKey(const ValueKey('profile-privacy-action'));
    await tester.ensureVisible(privacyAction);
    await tester.pumpAndSettle();
    await tester.tap(privacyAction);
    await tester.pump();

    final releasesAction =
        find.byKey(const ValueKey('profile-releases-action'));
    await tester.ensureVisible(releasesAction);
    await tester.pumpAndSettle();
    await tester.tap(releasesAction);
    await tester.pump();

    expect(
      opened,
      <Uri>[
        Uri.parse('https://pokrov.space/offer/'),
        Uri.parse('https://pokrov.space/privacy/'),
        Uri.parse('https://github.com/Kiwunaka/pokrov/releases'),
      ],
    );
  });

  testWidgets('profile first layer stays compact and hides advanced controls',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    expect(find.byKey(const ValueKey('profile-compact-account-layer')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-redeem-code-action')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('profile-redeem-code-field')), findsNothing);
    expect(
        find.byKey(const ValueKey('profile-section-support')), findsOneWidget);
    expect(find.text('Р‘РѕРЅСѓСЃС‹'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Р”Р°, РѕС‚РєСЂС‹С‚СЊ'), findsNothing);
  });

  testWidgets('profile redeem uses native app-first endpoint', (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    await _openRedeemSheetFromProfile(tester);
    await tester.enterText(
      find.byKey(const ValueKey('profile-redeem-code-field')),
      'POKROV-ACCESS-2026',
    );
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pumpAndSettle();

    expect(bootstrapper.redeemCalls, 1);
    expect(bootstrapper.lastRedeemCode, 'POKROV-ACCESS-2026');
    expect(bootstrapper.lastRedeemHostPlatform, HostPlatform.android);
    expect(launched, isEmpty);
    expect(find.textContaining('Доступ обновлен'), findsWidgets);
  });

  testWidgets('profile gift redeem keeps access-updated confirmation',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      redeemResult: const AppFirstRedeemResult(
        ok: true,
        kind: 'gift',
        codePreview: '...2026',
        result: <String, dynamic>{},
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    await _openRedeemSheetFromProfile(tester);
    await tester.enterText(
      find.byKey(const ValueKey('profile-redeem-code-field')),
      'POKROV-GIFT-2026',
    );
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pumpAndSettle();

    expect(bootstrapper.redeemCalls, 1);
    expect(bootstrapper.lastRedeemCode, 'POKROV-GIFT-2026');
    expect(
      find.textContaining('Доступ обновлен'),
      findsWidgets,
    );
  });

  testWidgets('profile redeem keeps the sheet open on empty code',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    await _openRedeemSheetFromProfile(tester);

    await tester.enterText(
      find.byKey(const ValueKey('profile-redeem-code-field')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pumpAndSettle();

    // Empty input never closes the sheet; the field explains what to do.
    expect(find.byKey(const ValueKey('profile-redeem-sheet')), findsOneWidget);
    expect(find.text('Введите код активации.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-redeem-code-field')),
      'POKROV-ACCESS-2026',
    );
    await tester.pumpAndSettle();
    expect(find.text('Введите код активации.'), findsNothing);
  });

  testWidgets('profile cabinet opens through short-lived handoff',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      cabinetHandoff: CabinetHandoff(
        token: 'short-cabinet-token',
        handoffUrl: Uri.parse(
          'https://app.pokrov.space/profile?handoff_token=short-cabinet-token',
        ),
        expiresIn: const Duration(seconds: 120),
        targetPath: '/',
        scope: 'cabinet_handoff',
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final cabinetAction =
        find.byKey(const ValueKey('profile-open-cabinet-action'));
    await tester.dragUntilVisible(
      cabinetAction,
      find.byType(Scrollable).first,
      const Offset(0, -220),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();
    await tester.tap(cabinetAction);
    await tester.pumpAndSettle();

    expect(bootstrapper.cabinetCalls, 1);
    expect(bootstrapper.lastCabinetHostPlatform, HostPlatform.android);
    expect(bootstrapper.lastCabinetTargetPath, '/');
    expect(launched.single.host, 'app.pokrov.space');
    expect(
      launched.single.queryParameters['handoff_token'],
      'short-cabinet-token',
    );
  });

  for (final host in [HostPlatform.android, HostPlatform.windows]) {
    testWidgets('cabinet return refreshes subscription on ${host.name}',
        (tester) async {
      if (host == HostPlatform.windows) {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }
      final bootstrapper = _FakeBootstrapper(
        const ManagedProfilePayload(
          profileName: 'cabinet-return',
          configPayload: _materializedRuntimeConfig,
          materializedForRuntime: true,
        ),
        subscriptionInfo: const ClientSubscriptionInfo(
          lane: 'expiredOrBlocked',
          expiresAt: '',
          daysLeft: 0,
          autoRenew: false,
          renewUrl: null,
          plans: <ClientSubscriptionPlan>[],
          trafficPolicy: <String, Object?>{},
        ),
      );
      final launched = <Uri>[];
      await tester.pumpWidget(PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: host),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ));
      await tester.pumpAndSettle();
      await _tapNav(tester, 'nav-profile');
      await tester.pumpAndSettle();
      expect(find.text('Доступ не активен'), findsWidgets);
      final cabinet = find.byKey(const ValueKey('profile-open-cabinet-action'));
      await tester.dragUntilVisible(
        cabinet,
        find.byType(Scrollable).first,
        const Offset(0, -220),
        maxIteration: 8,
      );
      await tester.pumpAndSettle();
      await tester.tap(cabinet);
      await tester.pumpAndSettle();
      final callsBeforeReturn = bootstrapper.subscriptionCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      bootstrapper.subscriptionInfo = _paidSubscriptionInfo;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(bootstrapper.subscriptionCalls, callsBeforeReturn + 1);
      expect(bootstrapper.cabinetCalls, 1);
      expect(launched, hasLength(1));
      // Resume retains the current profile route; no second handoff or login.
      expect(cabinet, findsOneWidget);
      await tester.dragUntilVisible(
        find.text('30 дней доступа'),
        find.byType(Scrollable).first,
        const Offset(0, 220),
        maxIteration: 8,
      );
      expect(find.text('30 дней доступа'), findsOneWidget);
      expect(find.text('Доступ не активен'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  testWidgets('foreground account refresh coalesces and recovers after offline',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'foreground-account',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
      firstLaunchStore: _FakeFirstLaunchStore(completed: true),
    ));
    await tester.pumpAndSettle();
    final callsBeforeReturn = bootstrapper.subscriptionCalls;
    final bonusCallsBeforeReturn = bootstrapper.bonusSummaryCalls;
    final notificationCallsBeforeReturn = bootstrapper.notificationCalls;
    final refresh = Completer<void>();
    bootstrapper.subscriptionGate = refresh.future;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await _tapNav(tester, 'nav-profile');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(bootstrapper.subscriptionCalls, callsBeforeReturn + 1);
    expect(bootstrapper.bonusSummaryCalls, bonusCallsBeforeReturn);
    expect(bootstrapper.notificationCalls, notificationCallsBeforeReturn);
    expect(find.text('5 дней пробного доступа'), findsOneWidget);

    refresh.completeError(const BootstrapFailure(
      'Сервис не ответил вовремя.',
      operationalCode: 'API-002',
    ));
    await tester.pumpAndSettle();
    expect(find.text('5 дней пробного доступа'), findsOneWidget);
    expect(find.text('Доступ не активен'), findsNothing);
    expect(find.text('30 дней доступа'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    bootstrapper.subscriptionGate = null;
    bootstrapper.subscriptionInfo = _paidSubscriptionInfo;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(bootstrapper.subscriptionCalls, callsBeforeReturn + 2);
    expect(find.text('30 дней доступа'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
      'profile shows native Telegram identity without another link action',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: const ClientSubscriptionInfo(
        lane: 'paidUnlimited',
        expiresAt: '2027-01-01T00:00:00Z',
        daysLeft: 263,
        autoRenew: false,
        renewUrl: null,
        plans: <ClientSubscriptionPlan>[],
        trafficPolicy: <String, Object?>{},
        telegramLinked: true,
        telegramUsername: 'pokrov_owner',
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');
    final telegramRow =
        find.byKey(const ValueKey('profile-telegram-link-action'));
    await tester.dragUntilVisible(
      telegramRow,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    expect(find.text('@pokrov_owner'), findsOneWidget);
    expect(find.text('Привязать'), findsNothing);
    await tester.tap(telegramRow);
    await tester.pumpAndSettle();
    expect(bootstrapper.telegramLinkCalls, 0);
  });

  testWidgets('profile Telegram bonus works before payment', (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final telegramLink =
        find.byKey(const ValueKey('profile-telegram-link-action'));
    await tester.dragUntilVisible(
      telegramLink,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(telegramLink);
    await tester.pumpAndSettle();

    expect(bootstrapper.telegramLinkCalls, 1);
    expect(bootstrapper.lastTelegramLinkHostPlatform, HostPlatform.android);
    expect(bootstrapper.telegramLinkEvents, <String>['handoff_opened']);
    expect(launched.single.host, 't.me');
    expect(launched.single.queryParameters['start'], 'app-link-2026');

    final telegramCheck =
        find.byKey(const ValueKey('profile-telegram-claim-action'));
    await tester.dragUntilVisible(
      telegramCheck,
      find.byType(Scrollable).first,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(telegramCheck);
    await tester.pumpAndSettle();

    expect(bootstrapper.channelBonusCheckCalls, 1);
    expect(
        bootstrapper.lastChannelBonusCheckHostPlatform, HostPlatform.android);
    expect(find.textContaining('+5'), findsWidgets);

    final telegramClaim =
        find.byKey(const ValueKey('profile-telegram-claim-action'));
    await tester.dragUntilVisible(
      telegramClaim,
      find.byType(Scrollable).first,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(telegramClaim);
    await tester.pumpAndSettle();

    expect(bootstrapper.channelBonusClaimCalls, 1);
    expect(
        bootstrapper.lastChannelBonusClaimHostPlatform, HostPlatform.android);
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('profile verifies Telegram after returning from the bot',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (_) async => true,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');
    final telegramLink =
        find.byKey(const ValueKey('profile-telegram-link-action'));
    await Scrollable.ensureVisible(
      tester.element(telegramLink),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(telegramLink);
    await tester.pumpAndSettle();

    bootstrapper.subscriptionInfo = const ClientSubscriptionInfo(
      lane: 'trialPremium',
      expiresAt: '2026-08-22T00:00:00Z',
      daysLeft: 5,
      autoRenew: false,
      renewUrl: null,
      plans: <ClientSubscriptionPlan>[],
      trafficPolicy: <String, Object?>{},
      telegramLinked: true,
      telegramUsername: 'linked_owner',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      bootstrapper.telegramLinkEvents,
      <String>['handoff_opened', 'verify_requested'],
    );
    expect(find.text('@linked_owner'), findsOneWidget);
    expect(bootstrapper.telegramLinkCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('profile loads compact bonus summary with reward preview',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: _paidSubscriptionInfo,
      bonusSummary: const AppFirstBonusSummary(
        referralCount: 2,
        referralCode: 'POKROV2',
        referralBonusDays: 10,
        streakMonths: 3,
        lastWheelSpin: '',
        channelBonusPremiumDays: 10,
        channelBonusClaimedAt: '2026-06-03T12:00:00Z',
        openingBonusPremiumDays: 5,
        openingBonusClaimed: true,
        channelUsername: 'pokrov_vpn',
        tierKey: 'starter',
        tierPercent: 5,
        paidReferrals: 2,
        nextTierKey: 'pro',
        nextTierAt: 5,
        referralSummary: AppFirstReferralSummary(
          count: 4,
          code: 'POKROV3',
          link: 'https://t.me/pokrov_vpnbot?start=ref_POKROV3',
          bonusDays: 10,
          tierKey: 'starter',
          tierPercent: 5,
          paidReferrals: 2,
          nextTierKey: 'pro',
          nextTierAt: 5,
          conversion: AppFirstReferralConversion(
            invited: 4,
            activated: 3,
            paid: 2,
            rewarded: 1,
            activationPct: 75,
            paidPct: 50,
          ),
          history: <AppFirstReferralHistoryItem>[
            AppFirstReferralHistoryItem(
              id: 'ref-2',
              status: 'rewarded',
              createdAt: '2026-06-02T12:00:00Z',
              activatedAt: '2026-06-02T12:05:00Z',
              paidAt: '2026-06-03T12:00:00Z',
              holdUntil: '2026-06-10T12:00:00Z',
              rewardedAt: '2026-06-10T12:00:00Z',
            ),
          ],
          privacy: 'Имена и аккаунты приглашённых не показываются.',
        ),
        achievementItems: <AppFirstAchievementItem>[
          AppFirstAchievementItem(
            id: 'first_tunnel',
            title: 'Первый туннель',
            description: 'Подключение подтверждено.',
            unlocked: true,
          ),
        ],
        questItems: <AppFirstQuestItem>[
          AppFirstQuestItem(
            id: 'second_device',
            title: 'Добавить второе устройство',
            description: 'Свяжите ещё одно устройство.',
            progress: 1,
            target: 2,
            completed: false,
            actionHref: '/devices/',
            verification: 'active_account_devices',
          ),
        ],
        historyItems: <AppFirstBonusHistoryItem>[
          AppFirstBonusHistoryItem(
            kind: 'promo',
            source: 'promo',
            title: 'Промокод активирован',
            occurredAt: '2026-06-03T12:30:00Z',
            days: 7,
            discountPct: 0,
            codePreview: '...DAYS',
          ),
          AppFirstBonusHistoryItem(
            kind: 'telegram_channel',
            source: 'telegram',
            title: 'Telegram-бонус получен',
            occurredAt: '2026-06-03T12:00:00Z',
            days: 10,
            discountPct: 0,
            codePreview: '',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(
        find.byKey(const ValueKey('home-telegram-bonus-pill')), findsNothing);
    expect(find.text('+10 дней'), findsNothing);

    await _tapNav(tester, 'nav-profile');
    await tester.pumpAndSettle();

    final summarySection =
        find.byKey(const ValueKey('profile-section-bonus-summary'));
    await tester.dragUntilVisible(
      summarySection,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    expect(summarySection, findsOneWidget);
    expect(bootstrapper.bonusSummaryCalls, 1);
    expect(bootstrapper.lastBonusSummaryHostPlatform, HostPlatform.android);
    expect(find.byKey(const ValueKey('profile-bonus-summary-refresh')),
        findsNothing);
    expect(find.byKey(const ValueKey('profile-bonus-wheel-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-activity-calendar-action')),
        findsNothing);
    expect(find.byKey(const ValueKey('rewards-history-section')), findsNothing);
    expect(find.textContaining('POKROV3'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-bonus-wheel-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rewards-hub-sheet')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('rewards-history-section')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('rewards-history-item-0')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('rewards-history-item-1')), findsOneWidget);
    expect(find.text('Промокод активирован'), findsOneWidget);
    expect(find.text('Telegram-бонус получен'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rewards-referral-share-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-referral-copy-action')),
      findsOneWidget,
    );
    expect(find.textContaining('POKROV3'), findsNothing);
    expect(find.textContaining('+10'), findsWidgets);
    expect(find.text('Конверсия'), findsOneWidget);
    expect(find.text('Активировано'), findsNothing);
    expect(find.text('Последние приглашения'), findsOneWidget);
    expect(find.text('Бонус начислен'), findsOneWidget);
    expect(find.text('Имена и аккаунты приглашённых не показываются.'),
        findsOneWidget);
    expect(find.text('Полезные задачи'), findsNothing);
    expect(find.byKey(const ValueKey('rewards-quest-second_device')),
        findsNothing);
  });

  testWidgets('zero remaining days never resets to the advertised trial duration',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'zero-days-ui',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: const ClientSubscriptionInfo(
        lane: 'trialPremium',
        expiresAt: '',
        daysLeft: 0,
        autoRenew: false,
        renewUrl: null,
        plans: <ClientSubscriptionPlan>[],
        trafficPolicy: <String, Object?>{},
      ),
    );
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
      firstLaunchStore: _FakeFirstLaunchStore(completed: true),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 дней'), findsNothing);
    await _tapNav(tester, 'nav-profile');
    expect(find.text('Пробный доступ'), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const ValueKey('profile-section-plan-access')),
      matching: find.textContaining('5 дней'),
    ), findsNothing);
  });

  testWidgets('subscription refresh timeout does not claim missing entitlement',
      (tester) async {
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'pokrov-entitlement-observation-',
      );
      final observability = await PokrovClientObservability.start(
        hostPlatform: HostPlatform.android,
        directoryResolver: () async => directory,
      );
      final subscriptionGate = Completer<void>();
      final bootstrapper = _FakeBootstrapper(
        const ManagedProfilePayload(
          profileName: 'test-profile',
          configPayload: _materializedRuntimeConfig,
          materializedForRuntime: true,
        ),
        subscriptionGate: subscriptionGate.future,
      );
      await tester.pumpWidget(PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        observability: observability,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ));
      await tester.pump();
      subscriptionGate.completeError(const BootstrapFailure(
        'Сервис не ответил вовремя.',
        operationalCode: 'API-002',
      ));
      await tester.pumpAndSettle();
      await observability.flush();
      final refresh =
          observability.dispatcher.breadcrumbs.snapshot().singleWhere(
                (event) => event.name == 'app.entitlement.refresh.finished',
              );
      expect(refresh.errorCode, 'API-002');
      expect(find.textContaining(RegExp('пробного доступа|Пробный ·')),
          findsNothing);
      expect(find.text('Подписка'), findsOneWidget);
      await _tapNav(tester, 'nav-profile');
      expect(find.text('Статус доступа уточняется'), findsOneWidget);
      expect(find.text('Нет данных'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('profile-plan-details-action')));
      await tester.pumpAndSettle();
      expect(
        find.text('Статус подписки пока неизвестен. Проверьте его в личном кабинете.'),
        findsOneWidget,
      );
      expect(find.textContaining('Доступ активен.'), findsNothing);

      // Detach this test's observer before disposing the shell so its
      // fire-and-forget exit marker cannot race our temporary-file cleanup.
      await tester.pumpWidget(PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ));
      await tester.pumpWidget(const SizedBox.shrink());
      await observability.flush();
      await observability.markCleanExit();
      await directory.delete(recursive: true);
    });
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('startup orders subscription before bonus summary',
      (tester) async {
    final subscriptionGate = Completer<void>();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionGate: subscriptionGate.future,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pump();

    expect(bootstrapper.subscriptionCalls, 1);
    expect(bootstrapper.bonusSummaryCalls, 0);
    expect(
        bootstrapper.accountSummaryCallOrder, <String>['subscription:start']);

    subscriptionGate.complete();
    await tester.pumpAndSettle();

    expect(
      bootstrapper.accountSummaryCallOrder,
      <String>['subscription:start', 'subscription:end', 'bonus'],
    );
    expect(bootstrapper.bonusSummaryCalls, 1);
  });

  testWidgets('bonus preview keeps wheel and activity calendar non-mutating',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'trial-rewards-fallback',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    expect(find.byKey(const ValueKey('profile-bonus-wheel-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-activity-calendar-action')),
        findsNothing);
    expect(find.byKey(const ValueKey('rewards-wheel-card')), findsNothing);
    expect(find.byKey(const ValueKey('rewards-calendar-card')), findsNothing);

    await _openRewardsHubFromProfile(tester);

    expect(find.byKey(const ValueKey('rewards-paid-required-notice')),
        findsOneWidget);
    expect(find.text('Telegram +5 дней'), findsOneWidget);
    expect(
      find.text(
        'Telegram +5 дней доступен сейчас. Рулетка, календарь и приглашения откроются после первой оплаты.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('rewards-telegram-refresh-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-telegram-open-channel')),
        findsOneWidget);
    expect(
      find.text('Ссылка появится автоматически после первой оплаты.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-referral-share-action')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('rewards-referral-copy-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('rewards-wheel-card')), findsNothing);
    expect(find.byKey(const ValueKey('rewards-calendar-card')), findsNothing);
  });

  testWidgets('profile opens rewards hub with wheel and calendar preview',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: const AppFirstBonusSummary(
        referralCount: 3,
        referralCode: 'POKROV3',
        referralBonusDays: 10,
        streakMonths: 2,
        lastWheelSpin: '2026-06-03T12:00:00Z',
        channelBonusPremiumDays: 10,
        channelBonusClaimedAt: '2026-06-03T12:00:00Z',
        openingBonusPremiumDays: 5,
        openingBonusClaimed: true,
        channelUsername: 'pokrov_vpn',
        tierKey: 'starter',
        tierPercent: 5,
        paidReferrals: 3,
        nextTierKey: 'pro',
        nextTierAt: 5,
        wheelState: AppFirstBonusFeatureState(
          ok: true,
          enabled: true,
          state: 'ready',
          featureFlag: 'BONUS_WHEEL_ENABLED',
          featureFlagEnabled: true,
          actionEndpoint: '/api/bonuses/wheel/spin',
          lastActionAt: '2026-06-03T12:00:00Z',
          streakMonths: 0,
        ),
        calendarState: AppFirstBonusFeatureState(
          ok: true,
          enabled: true,
          state: 'ready',
          featureFlag: 'BONUS_CALENDAR_ENABLED',
          featureFlagEnabled: true,
          actionEndpoint: '/api/bonuses/calendar/checkin',
          lastActionAt: '',
          streakMonths: 2,
        ),
      ),
      subscriptionInfo: _paidSubscriptionInfo,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final wheelAction =
        find.byKey(const ValueKey('profile-bonus-wheel-action'));
    expect(wheelAction, findsOneWidget);
    expect(find.byKey(const ValueKey('profile-activity-calendar-action')),
        findsNothing);
    await tester.dragUntilVisible(
      wheelAction,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    await tester.tap(wheelAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rewards-hub-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-wheel-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-calendar-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-wheel-spin-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-calendar-checkin-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-achievements-section')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-referral-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-promo-slots-section')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('rewards-promo-slot-empty')), findsNothing);
  });

  testWidgets('rewards hub can run live wheel and calendar actions',
      (tester) async {
    const liveWheel = AppFirstBonusFeatureState(
      ok: true,
      enabled: true,
      state: 'ready',
      featureFlag: 'BONUS_WHEEL_ENABLED',
      featureFlagEnabled: true,
      actionEndpoint: '/api/bonuses/wheel/spin',
      lastActionAt: '',
      streakMonths: 0,
    );
    const liveCalendar = AppFirstBonusFeatureState(
      ok: true,
      enabled: true,
      state: 'ready',
      featureFlag: 'BONUS_CALENDAR_ENABLED',
      featureFlagEnabled: true,
      actionEndpoint: '/api/bonuses/calendar/checkin',
      lastActionAt: '',
      streakMonths: 0,
    );
    const summary = AppFirstBonusSummary(
      referralCount: 1,
      referralCode: 'POKROV1',
      referralBonusDays: 10,
      streakMonths: 1,
      lastWheelSpin: '',
      channelBonusPremiumDays: 5,
      channelBonusClaimedAt: '',
      openingBonusPremiumDays: 5,
      openingBonusClaimed: true,
      channelUsername: 'pokrov_vpn',
      tierKey: 'starter',
      tierPercent: 5,
      paidReferrals: 0,
      nextTierKey: 'pro',
      nextTierAt: 5,
      wheelState: liveWheel,
      calendarState: liveCalendar,
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: summary,
      subscriptionInfo: _paidSubscriptionInfo,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final wheelAction =
        find.byKey(const ValueKey('profile-bonus-wheel-action'));
    await tester.dragUntilVisible(
      wheelAction,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    await tester.tap(wheelAction);
    await tester.pumpAndSettle();

    final rewardsScroll = find.byType(Scrollable).last;
    final spinAction = find.byKey(const ValueKey('rewards-wheel-spin-action'));
    await tester.dragUntilVisible(
      spinAction,
      rewardsScroll,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(spinAction);
    await tester.pumpAndSettle();

    expect(bootstrapper.wheelSpinCalls, 1);
    expect(bootstrapper.lastWheelSpinHostPlatform, HostPlatform.android);
    expect(find.byKey(const ValueKey('rewards-wheel-result-reveal')),
        findsOneWidget);
    expect(find.text('+1 день'), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('rewards-hub-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    await _openRewardsHubFromProfile(tester);
    final calendarAction =
        find.byKey(const ValueKey('rewards-calendar-checkin-action'));
    await tester.dragUntilVisible(
      calendarAction,
      find.byType(Scrollable).last,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(calendarAction);
    await tester.pumpAndSettle();

    expect(bootstrapper.calendarCheckInCalls, 1);
    expect(bootstrapper.lastCalendarCheckInHostPlatform, HostPlatform.android);
  });

  testWidgets('profile rewards hub shows first-party promo slots',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: const AppFirstBonusSummary(
        referralCount: 1,
        referralCode: 'POKROV1',
        referralBonusDays: 10,
        streakMonths: 1,
        lastWheelSpin: '',
        channelBonusPremiumDays: 5,
        channelBonusClaimedAt: '',
        openingBonusPremiumDays: 5,
        openingBonusClaimed: true,
        channelUsername: 'pokrov_vpn',
        tierKey: 'starter',
        tierPercent: 5,
        paidReferrals: 0,
        nextTierKey: 'pro',
        nextTierAt: 5,
        promoSlots: AppFirstPromoSlots(
          surface: 'app',
          accessState: 'trial_premium',
          remoteAvailable: true,
          fallbackBehavior: 'contextual_only_when_remote_unavailable',
          mode: 'whitelist_slots',
          slots: <AppFirstPromoSlot>[
            AppFirstPromoSlot(
              slotId: 'telegram_bonus_app',
              contentId: 'telegram_bonus',
              enabled: true,
              title: 'Telegram +5 days',
              body: 'Connect Telegram and claim the reward.',
              placement: 'rewards',
              ctaLabel: 'Open',
              ctaHref: 'https://t.me/pokrov_vpnbot',
              kind: 'bonus',
              goal: 'bonus_claim',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final wheelAction =
        find.byKey(const ValueKey('profile-bonus-wheel-action'));
    await tester.dragUntilVisible(
      wheelAction,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    await tester.tap(wheelAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rewards-promo-slots-section')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('rewards-promo-slot-empty')), findsNothing);
    expect(find.byKey(const ValueKey('rewards-promo-slot-telegram_bonus_app')),
        findsOneWidget);
    expect(
        find.byKey(
            const ValueKey('rewards-promo-slot-telegram_bonus_app-action')),
        findsOneWidget);
    expect(find.text('Telegram +5 days'), findsOneWidget);
  });

  testWidgets('profile rewards hub opens referral share link', (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: _paidSubscriptionInfo,
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final wheelAction =
        find.byKey(const ValueKey('profile-bonus-wheel-action'));
    await tester.dragUntilVisible(
      wheelAction,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    await tester.tap(wheelAction);
    await tester.pumpAndSettle();

    final shareAction =
        find.byKey(const ValueKey('rewards-referral-share-action'));
    expect(shareAction, findsOneWidget);
    await tester.dragUntilVisible(
      shareAction,
      find.byKey(const ValueKey('rewards-hub-sheet')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    await tester.tap(shareAction);
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.toString(), contains('start=ref_POKROV1'));
  });

  testWidgets('rewards referral copy confirms in-sheet with icon morph',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      subscriptionInfo: _paidSubscriptionInfo,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    await _openRewardsHubFromProfile(tester);

    final copyAction =
        find.byKey(const ValueKey('rewards-referral-copy-action'));
    expect(copyAction, findsOneWidget);
    expect(
      find.descendant(
          of: copyAction, matching: find.byIcon(Icons.link_rounded)),
      findsOneWidget,
    );

    await tester.tap(copyAction);
    await tester.pumpAndSettle();

    // The confirmation morphs inside the sheet instead of a snack that
    // would render hidden underneath the open sheet.
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.descendant(
        of: copyAction,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    expect(find.text('Скопировать ссылку'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: copyAction, matching: find.byIcon(Icons.link_rounded)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-hub-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('rewards referral hides dead actions without a server link',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummary: const AppFirstBonusSummary(
        referralCount: 0,
        referralCode: '',
        referralBonusDays: 10,
        streakMonths: 0,
        lastWheelSpin: '',
        channelBonusPremiumDays: 5,
        channelBonusClaimedAt: '',
        openingBonusPremiumDays: 5,
        openingBonusClaimed: false,
        channelUsername: 'pokrov_vpn',
        tierKey: 'starter',
        tierPercent: 5,
        paidReferrals: 0,
        nextTierKey: 'pro',
        nextTierAt: 5,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');
    await _openRewardsHubFromProfile(tester);

    final unavailable =
        find.byKey(const ValueKey('rewards-referral-unavailable'));
    await tester.dragUntilVisible(
      unavailable,
      find.byKey(const ValueKey('rewards-hub-sheet')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    expect(unavailable, findsOneWidget);
    expect(
      find.byKey(const ValueKey('rewards-referral-share-action')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('rewards-referral-copy-action')),
      findsNothing,
    );
    expect(find.text('POKROV'), findsNothing);
  });

  testWidgets('profile opens subscription and email recovery sheets',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');
    final planAction =
        find.byKey(const ValueKey('profile-plan-details-action'));
    expect(planAction, findsOneWidget);
    await tester.tap(planAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-subscription-sheet')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('subscription-checkout-primary')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('subscription-cabinet-primary')),
        findsOneWidget);

    Navigator.of(tester.element(find.byKey(
      const ValueKey('profile-subscription-sheet'),
    ))).pop();
    await tester.pumpAndSettle();

    final emailAction = find.byKey(const ValueKey('profile-email-action'));
    await tester.dragUntilVisible(
      emailAction,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(emailAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-email-recovery-sheet')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('profile-email-add-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-email-cabinet-action')),
        findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('profile surfaces devices, notifications and subscription detail',
      (tester) async {
    _expectAppShellImplementationHelpersCovered(const ['_KeyValueLine']);

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      notificationsInbox: const ClientNotificationInbox(
        items: <ClientNotificationItem>[
          ClientNotificationItem(
            id: 'release.111',
            kind: 'release',
            title: 'Старое обновление',
            body: 'Уведомление можно убрать.',
            createdAt: '2026-08-17T10:00:00Z',
            ctaLabel: '',
            ctaHref: null,
            read: false,
          ),
        ],
        nextCursor: '',
        unreadCount: 1,
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        handoffLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');
    await tester.pumpAndSettle();

    // Subscription detail from the backend (days left + plan tariffs).
    await tester.tap(find.byKey(const ValueKey('profile-plan-details-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-subscription-sheet')),
        findsOneWidget);
    expect(find.text('Осталось дней'), findsOneWidget);
    Navigator.of(tester.element(
      find.byKey(const ValueKey('profile-subscription-sheet')),
    )).pop();
    await tester.pumpAndSettle();

    // Devices sheet lists sessions with a calm empty state.
    final devicesAction = find.byKey(const ValueKey('profile-devices-action'));
    await tester.dragUntilVisible(
      devicesAction,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(devicesAction);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-devices-sheet')), findsOneWidget);
    expect(find.text('Пока нет других устройств.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-device-pairing-issue')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('profile-device-pairing-issue')),
    );
    await tester.pumpAndSettle();
    expect(bootstrapper.pairingIssueCalls, 1);
    expect(find.text('ABCD-9XYZ'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('profile-device-pairing-cancel')),
    );
    await tester.pumpAndSettle();
    expect(bootstrapper.pairingCancelCalls, 1);
    expect(find.text('ABCD-9XYZ'), findsNothing);
    Navigator.of(tester.element(
      find.byKey(const ValueKey('profile-devices-sheet')),
    )).pop();
    await tester.pumpAndSettle();

    // Notifications inbox replaces the old static info sheet.
    final notificationsAction =
        find.byKey(const ValueKey('profile-notifications-action'));
    await tester.dragUntilVisible(
      notificationsAction,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(notificationsAction);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-notifications-sheet')),
        findsOneWidget);
    expect(find.text('Старое обновление'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('profile-notifications-clear')),
    );
    await tester.pumpAndSettle();
    expect(bootstrapper.dismissedNotificationIds, <String>['release.111']);
    expect(find.byKey(const ValueKey('profile-notifications-sheet')),
        findsNothing);

    expect(launched, isEmpty);
  });

  testWidgets('profile keeps account and settings actions grouped',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    expect(find.byKey(const ValueKey('settings-row-press-feedback')),
        findsWidgets);

    expect(find.byKey(const ValueKey('profile-account-details-action')),
        findsNothing);
    expect(find.byKey(const ValueKey('profile-open-cabinet-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-email-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-section-app')), findsOneWidget);
  });

  testWidgets('disabled rewards stay hidden instead of dead muted cards',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    final wheelAction =
        find.byKey(const ValueKey('profile-bonus-wheel-action'));
    await tester.dragUntilVisible(
      wheelAction,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(wheelAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rewards-wheel-card')), findsNothing);
    expect(find.byKey(const ValueKey('rewards-calendar-card')), findsNothing);
    expect(
        find.byKey(const ValueKey('rewards-wheel-spin-action')), findsNothing);
    expect(find.byKey(const ValueKey('rewards-calendar-checkin-action')),
        findsNothing);
  });

  testWidgets('P4 responsive width matrix keeps the app shell stable',
      (tester) async {
    _expectNavigationShellHelpersCovered(const [
      '_DesktopShell',
      '_MobileShell',
      '_DesktopSidebar',
      '_BrandLockup',
      '_BrandMark',
      '_SidebarItem',
    ]);

    final cases = <({double width, HostPlatform platform, String shellKey})>[
      (width: 360, platform: HostPlatform.android, shellKey: 'mobile-shell'),
      (width: 493, platform: HostPlatform.android, shellKey: 'mobile-shell'),
      (width: 700, platform: HostPlatform.android, shellKey: 'mobile-shell'),
      (
        width: 900,
        platform: HostPlatform.windows,
        shellKey: 'desktop-icon-rail'
      ),
      (
        width: 1024,
        platform: HostPlatform.windows,
        shellKey: 'desktop-icon-rail'
      ),
      (
        width: 1180,
        platform: HostPlatform.windows,
        shellKey: 'desktop-sidebar-expanded'
      ),
      (
        width: 1440,
        platform: HostPlatform.windows,
        shellKey: 'desktop-sidebar-expanded'
      ),
    ];
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final item in cases) {
      await tester.binding.setSurfaceSize(Size(item.width, 820));
      await tester.pumpWidget(
        PokrovSeedApp(
          appContext: buildSeedAppContext(hostPlatform: item.platform),
        ),
      );
      await tester.pumpAndSettle();
      await _completeFirstLaunchIfPresent(tester);

      expect(find.byKey(ValueKey(item.shellKey)), findsOneWidget);
      expect(find.text('Активен'), findsNothing);
      expect(
          find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
      if (item.platform == HostPlatform.android) {
        expect(find.byType(NavigationBar), findsOneWidget);
        if (item.width == 360) {
          expect(
            find.byKey(const ValueKey('home-access-badge-bloom-false')),
            findsNothing,
          );
          expect(find.text('Подписка'), findsOneWidget);
          expect(find.text('Затем — продлите доступ'), findsNothing);
          expect(find.byKey(const ValueKey('home-warp-info-action')),
              findsOneWidget);
          expect(find.text('Дополнительная защита'), findsNothing);
        }
      } else {
        expect(find.byType(NavigationBar), findsNothing);
      }
      expect(tester.takeException(), isNull, reason: 'width ${item.width}');
    }
  });

  testWidgets('expanded desktop sidebar animates label width and opacity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(
        find.byKey(const ValueKey('desktop-sidebar-expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-sidebar-label-motion')),
        findsWidgets);
  });

  testWidgets('windows shell hides unavailable enhanced protection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-icon-rail')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('desktop-sidebar-expanded')), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    final desktopControlSize =
        tester.getSize(find.byKey(const ValueKey('connect-disc-motion')));
    expect(desktopControlSize.width, inInclusiveRange(340, 380));
    expect(desktopControlSize.height, inInclusiveRange(88, 104));
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-news-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-telegram-bonus-pill')),
      findsOneWidget,
    );

    // Desktop header affordances stay honest: tooltips and icons describe
    // the actual targets (notifications inbox, rules tab).
    final detailsAction = tester.widget<IconButton>(
      find.byKey(const ValueKey('home-desktop-notifications-action')),
    );
    expect(detailsAction.tooltip, 'Уведомления');
    final rulesAction = tester.widget<IconButton>(
      find.byKey(const ValueKey('home-desktop-settings-action')),
    );
    expect(rulesAction.tooltip, 'Правила');

    expect(find.text('Р’Р°С€ РѕСЃРЅРѕРІРЅРѕР№ СЂРµРіРёРѕРЅ'), findsNothing);
    expect(find.text('РќРѕРІРѕСЃС‚Рё Рё СѓРІРµРґРѕРјР»РµРЅРёСЏ'), findsNothing);
    expect(find.text('РЈСЃРёР»РµРЅРЅС‹Р№ СЂРµР¶РёРј'), findsNothing);
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
    expect(find.textContaining('Дополнительная защита'), findsOneWidget);
    expect(find.textContaining('WARP'), findsOneWidget);

    await _tapNav(tester, 'nav-profile');
    expect(
      find.byKey(const ValueKey('profile-enhanced-protection-action')),
      findsOneWidget,
    );
  });

  testWidgets('windows profile controls autostart and close behavior',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saved = const PokrovWindowsShellPreferences(
      launchAtLogin: true,
      closeToTray: false,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        windowsShellPreferencesReader: () async => saved,
        windowsShellPreferencesUpdater: (next) async {
          saved = next;
          return next;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-profile');

    final action = find.byKey(
      const ValueKey('profile-windows-shell-action'),
    );
    final profileScrollable =
        find.ancestor(of: action, matching: find.byType(Scrollable)).first;
    await tester.dragUntilVisible(
      action,
      profileScrollable,
      const Offset(0, -300),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-windows-shell-sheet')),
      findsOneWidget,
    );
    expect(find.text('POKROV в Windows'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('windows-close-to-tray-toggle')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(saved.closeToTray, isTrue);
    expect(saved.launchAtLogin, isTrue);
  });

  testWidgets('enhanced protection asks for explicit consent before activation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(calls: runtimeCalls);

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          state: 'ready',
          wireguardConfigJson:
              '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2"}',
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);

    await _openEnhancedProtectionFromProfile(tester);

    expect(bootstrapper.calls, 1);
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-warp-consent-switch')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-warp-enable-action')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-warp-enable-action')));
    await tester.pumpAndSettle();

    expect(bootstrapper.warpConsentCalls, 1);
    expect(bootstrapper.lastWarpConsentEnabled, isTrue);
    expect(runtimeCalls, contains('runtimeEngine.invalidateManagedProfile'));
    expect(runtimeCalls, contains('runtimeEngine.disconnect'));
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(2),
    );
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsNothing);
    await _tapNav(tester, 'nav-protection');
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
  });

  testWidgets('home WARP switch changes consent without opening details',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          state: 'ready',
          wireguardConfigJson:
              '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2"}',
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-warp-inline-switch')), findsOneWidget);
    expect(find.bySemanticsLabel('WARP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-warp-inline-switch')));
    await tester.pumpAndSettle();

    expect(bootstrapper.warpConsentCalls, 1);
    expect(bootstrapper.lastWarpConsentEnabled, isTrue);
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsNothing);
    expect(
        find.byKey(const ValueKey('home-warp-state-enabled')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-warp-tile'))).value,
      'Включится при следующем подключении',
    );
    semantics.dispose();
  });

  testWidgets('home WARP tile is tappable as a whole and toggles the switch',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          state: 'ready',
          wireguardConfigJson:
              '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2"}',
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    // Tap the tile body, not the inline switch.
    await tester.tap(find.byKey(const ValueKey('home-warp-tile')));
    await tester.pumpAndSettle();

    expect(bootstrapper.warpConsentCalls, 1);
    expect(bootstrapper.lastWarpConsentEnabled, isTrue);
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsNothing);
    expect(
        find.byKey(const ValueKey('home-warp-state-enabled')), findsOneWidget);
  });

  testWidgets(
      'failed WARP connect falls back to ordinary VPN and stays visibly enabled',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      failAfterConnect: true,
      failApplyWarp: true,
    );
    const warpPolicy = WarpRuntimePolicy(
      enabled: true,
      runtimeReady: true,
      state: 'consented',
      userConsented: true,
      wireguardConfigJson:
          '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2"}',
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: warpPolicy,
      ),
      warpStatus: WarpControlStatus.fromPolicy(warpPolicy),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(2),
    );
    expect(runtimeCalls, contains('runtimeEngine.applyWarp'));
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.stageManagedProfile'),
      hasLength(2),
    );
    expect(find.text('Отключить'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-warp-state-fallback')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-warp-tile'))).value,
      'На паузе · обычный режим',
    );
    expect(bootstrapper.warpRuntimeEventCalls, 1);

    await tester.tap(find.byKey(const ValueKey('home-warp-inline-switch')));
    await tester.pumpAndSettle();
    expect(bootstrapper.lastWarpConsentEnabled, isFalse);
  });

  testWidgets('explicit WARP retry overrides one stale fallback status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stagedPayloads = <String>[];
    _installReadyRuntimeBridgeMock(stagedPayloads: stagedPayloads);
    const localPolicy = WarpRuntimePolicy.clientLocalDefault;
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: localPolicy,
      ),
      warpStatus: WarpControlStatus.fromPolicy(localPolicy).copyWith(
        state: 'fallback',
        consented: false,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('home-warp-inline-switch')));
    await tester.pumpAndSettle();
    bootstrapper.warpStatus = bootstrapper.warpStatus.copyWith(
      state: 'fallback',
      consented: true,
    );

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    final staged = jsonDecode(stagedPayloads.last) as Map<String, dynamic>;
    final endpoints = staged['endpoints'] as List<dynamic>;
    expect(
      endpoints.cast<Map<String, dynamic>>().singleWhere(
            (endpoint) => endpoint['tag'] == 'pokrov-warp',
          )['type'],
      'warp',
    );
    expect((staged['route'] as Map<String, dynamic>)['final'], 'pokrov-warp');
  });

  testWidgets('home WARP uses client-local defaults without server material',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy.disabled,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final warpTile = find.byKey(const ValueKey('home-warp-tile'));
    expect(warpTile, findsOneWidget);
    expect(find.descendant(of: warpTile, matching: find.text('WARP')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('home-warp-state-ready')), findsOneWidget);
    expect(tester.getSemantics(warpTile).value, 'Дополнительная защита');

    await tester.tap(find.byKey(const ValueKey('home-warp-inline-switch')));
    await tester.pumpAndSettle();

    expect(bootstrapper.warpConsentCalls, 1);
    expect(bootstrapper.lastWarpConsentEnabled, isTrue);
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsNothing);
    expect(
        find.text('WARP включится при следующем подключении.'), findsOneWidget);
    expect(find.textContaining('готовится'), findsNothing);
  });

  testWidgets('revoking WARP consent clears the local enabled state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stagedPayloads = <String>[];
    _installReadyRuntimeBridgeMock(stagedPayloads: stagedPayloads);

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy(
          enabled: true,
          runtimeReady: true,
          state: 'ready',
          wireguardConfigJson:
              '{"private-key":"test-private-key","local-address-ipv4":"172.16.0.2"}',
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    await _openEnhancedProtectionFromProfile(tester);
    await tester.tap(find.byKey(const ValueKey('home-warp-enable-action')));
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-protection');
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);

    await _openEnhancedProtectionFromProfile(tester);
    await tester.tap(find.byKey(const ValueKey('home-warp-consent-switch')));
    await tester.pumpAndSettle();

    expect(bootstrapper.warpConsentCalls, 2);
    expect(bootstrapper.lastWarpConsentEnabled, isFalse);

    // A later stale status/profile claiming consent must not undo this
    // explicit revoke when the next profile is staged.
    bootstrapper.warpStatus = bootstrapper.warpStatus.copyWith(
      consented: true,
      canEnable: false,
      state: 'consented',
    );
    await _tapNav(tester, 'nav-protection');
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(stagedPayloads.last, isNot(contains('test-private-key')));

    await _tapNav(tester, 'nav-protection');
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
  });

  testWidgets(
      'narrow windows shell uses a hamburger drawer instead of fixed sidebar',
      (tester) async {
    _expectNavigationShellHelpersCovered(const [
      '_DesktopDrawerShell',
      '_DesktopSidebar',
      '_BrandLockup',
      '_BrandMark',
      '_SidebarItem',
    ]);

    await tester.binding.setSurfaceSize(const Size(760, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-drawer-shell')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('desktop-sidebar-expanded')), findsNothing);
    expect(find.byKey(const ValueKey('desktop-icon-rail')), findsNothing);
    expect(find.byKey(const ValueKey('desktop-sidebar-hamburger')),
        findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('desktop-sidebar-hamburger')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('desktop-sidebar-drawer')), findsOneWidget);
  });

  testWidgets('home uses one compact animated connect control', (tester) async {
    _expectSharedShellWidgetHelpersCovered(const [
      '_ConnectOrbButton',
      '_ConnectOrbButtonState',
      'didChangeDependencies',
      '_syncControllers',
      'AnimatedBuilder',
      '_ConnectSettleLayer',
      '_ConnectDiscRimPainter',
      'paint',
      'shouldRepaint',
    ]);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('pokrov-brand-mark')), findsWidgets);
    expect(find.byKey(const ValueKey('connect-disc-motion')), findsOneWidget);
    final controlSize =
        tester.getSize(find.byKey(const ValueKey('connect-disc-motion')));
    expect(controlSize.width, inInclusiveRange(196, 228));
    expect(controlSize.height, controlSize.width);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('connect-disc-motion')),
        matching: find.byType(RepaintBoundary),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.byKey(const ValueKey('connect-disc-settle-layer')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('connect-disc-label')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-switcher')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-dot-motion')), findsNothing);
    expect(find.byKey(const ValueKey('home-chip-motion')), findsWidgets);
    expect(find.byKey(const ValueKey('home-chip-label-motion')), findsWidgets);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('РџРѕРґРєР»СЋС‡РёС‚СЊ'),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('preparation screens use geometry-matched motion skeletons',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-locations');

    expect(
      find.byKey(const ValueKey('locations-skeleton-list')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('motion-skeleton-line')), findsWidgets);

    await _tapNav(tester, 'nav-profile');

    expect(
      find.byKey(const ValueKey('account-skeleton-summary')),
      findsNothing,
    );
  });

  testWidgets('P5 rewards loading uses geometry-matched skeleton',
      (tester) async {
    final gate = Completer<void>();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      bonusSummaryGate: gate.future,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');

    final rewards = find.byKey(const ValueKey('profile-bonus-wheel-action'));
    await tester.dragUntilVisible(
      rewards,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(rewards);
    await tester.pumpAndSettle();

    final refresh = find.byKey(const ValueKey('rewards-refresh-action'));
    expect(refresh, findsOneWidget);

    expect(
        find.byKey(const ValueKey('rewards-skeleton-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('motion-skeleton-line')), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('rewards-skeleton-summary')), findsNothing);

    final refreshCalls = bootstrapper.bonusSummaryCalls;
    await tester.ensureVisible(refresh);
    await tester.pumpAndSettle();
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(bootstrapper.bonusSummaryCalls, refreshCalls + 1);
  });

  testWidgets('P5 support loading uses geometry skeleton instead of spinner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gate = Completer<void>();
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 701,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      listGate: gate.future,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-profile');

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('support-chat-skeleton')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('support-chat-screen')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-chat-skeleton')), findsNothing);
  });

  testWidgets('P5 Windows shortcuts navigate tabs and focus support composer',
      (tester) async {
    _expectAppShellImplementationHelpersCovered(const [
      '_SelectSeedTabIntent',
      '_FocusSupportComposerIntent',
      '_SendSupportMessageIntent',
    ]);

    await tester.binding.setSurfaceSize(const Size(1180, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 702,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('locations-auto-section')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-compact-account-layer')),
        findsOneWidget);

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('support-chat-composer')),
      'Shortcut message',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 1);
    expect(supportTicketService.lastBody, 'Shortcut message');
  });

  testWidgets('profile handoffs open safe external destinations',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final opened = <Uri>[];
    final appContext = buildSeedAppContext(hostPlatform: HostPlatform.windows);
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 777,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: appContext,
        supportTicketService: supportTicketService,
        handoffLauncher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    final checkout = find.byKey(const ValueKey('profile-checkout-action'));
    await tester.dragUntilVisible(
      checkout,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(checkout);
    await tester.pumpAndSettle();

    expect(opened.single.toString(),
        'https://pay.pokrov.space/checkout/?plan=1_month');

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    final atlas = find.byKey(const ValueKey('profile-guides-action'));
    await tester.ensureVisible(atlas);
    await tester.tap(atlas);
    await tester.pumpAndSettle();

    expect(opened.last.toString(), 'https://pokrov.space/guides/pokrov-app/');

    await tester.ensureVisible(support);
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-chat-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-chat-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-attach-diagnostics')),
        findsOneWidget);
    expect(opened.length, 2);

    await tester.enterText(
      find.byKey(const ValueKey('support-chat-composer')),
      'РќРµ РїРѕРґРєР»СЋС‡Р°РµС‚СЃСЏ',
    );
    await tester.tap(find.byKey(const ValueKey('support-chat-send')));
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 1);
    expect(supportTicketService.lastHostPlatform, HostPlatform.windows);
    expect(supportTicketService.lastBody, 'РќРµ РїРѕРґРєР»СЋС‡Р°РµС‚СЃСЏ');
    expect(supportTicketService.lastSubject, contains('POKROV'));
    expect(supportTicketService.lastStatusLabel, isEmpty);
    expect(supportTicketService.lastDiagnostics, isEmpty);
    expect(find.textContaining('#777'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-attach-diagnostics')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-diagnostics-preview')),
        findsOneWidget);
    expect(find.textContaining(appContext.hostPlatform.label), findsWidgets);
    expect(find.text('Предпросмотр диагностики'), findsOneWidget);
    expect(find.text('Код поддержки'), findsOneWidget);
    expect(find.text('Файлы пакета'), findsOneWidget);
    expect(find.text('build/identity.json'), findsOneWidget);
    expect(find.text('network/summary.json'), findsOneWidget);
    expect(find.text('redaction/report.json'), findsOneWidget);
    expect(find.text('Россия напрямую'), findsWidgets);
    expect(find.text('Статус VPN'), findsOneWidget);
    expect(find.textContaining('Сырые'), findsNothing);
    expect(find.textContaining('config'), findsNothing);
    expect(find.textContaining('конфиг'), findsNothing);
    expect(find.textContaining('адреса серверов'), findsNothing);
    expect(find.textContaining('://'), findsNothing);
    final copyCode =
        find.byKey(const ValueKey('support-diagnostics-copy-code'));
    expect(copyCode, findsOneWidget);
    await tester.ensureVisible(copyCode);
    await tester.tap(copyCode);
    await tester.pumpAndSettle();
    expect(clipboardText, startsWith('PSD1-'));
    expect(clipboardText, hasLength(24));
    expect(find.text('Код поддержки скопирован.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-diagnostics-close')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('support-feedback-bot-action')),
      findsNothing,
    );
    final feedbackForm = find.byKey(
      const ValueKey('support-feedback-form-action'),
    );
    await tester.ensureVisible(feedbackForm);
    await tester.tap(feedbackForm);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-feedback-form')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('support-feedback-category-bug')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('support-feedback-message')),
      'Плитка иногда показывает неверный статус.',
    );
    await tester.tap(
      find.byKey(const ValueKey('support-feedback-attach-diagnostics')),
    );
    await tester.tap(find.byKey(const ValueKey('support-feedback-submit')));
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 2);
    expect(supportTicketService.lastSubject, contains('ошибка'));
    expect(
      supportTicketService.lastBody,
      'Плитка иногда показывает неверный статус.',
    );
    expect(supportTicketService.lastDiagnostics, isNotEmpty);
    expect(opened, hasLength(2));
    expect(find.textContaining('отзыв #777 отправлен'), findsOneWidget);
  });

  testWidgets('home trial access strip opens the profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final opened = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        handoffLauncher: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final access = find.byKey(const ValueKey('home-access-strip'));
    await tester.dragUntilVisible(
      access,
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(access);
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(
      find.byKey(const ValueKey('profile-section-plan-access')),
      findsOneWidget,
    );
  });

  testWidgets(
      'support chat reuses a loaded ticket thread for follow-up replies',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final existingThread = _supportThread(
      id: 888,
      messages: <SupportTicketMessage>[
        _supportMessage(
          id: 1,
          ticketId: 888,
          senderRole: 'user',
          body: 'Connection fails',
        ),
        _supportMessage(
          id: 2,
          ticketId: 888,
          senderRole: 'admin',
          body: 'Try another location.',
        ),
      ],
    );
    final updatedThread = _supportThread(
      id: 888,
      messages: <SupportTicketMessage>[
        ...existingThread.messages,
        _supportMessage(
          id: 3,
          ticketId: 888,
          senderRole: 'user',
          body: 'Still broken',
        ),
      ],
    );
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 999,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      tickets: <SupportTicketThread>[existingThread],
      loadedThread: existingThread,
      sentThread: updatedThread,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('desktop-sidebar-hamburger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(supportTicketService.listCalls, 1);
    expect(supportTicketService.getCalls, 1);
    expect(find.text('Try another location.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-attach-diagnostics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-diagnostics-preview')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('support-diagnostics-attach-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-diagnostics-queued')),
        findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('support-chat-composer')),
      'Still broken',
    );
    await tester.tap(find.byKey(const ValueKey('support-chat-send')));
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 0);
    expect(supportTicketService.sendCalls, 1);
    expect(supportTicketService.lastTicketId, 888);
    expect(supportTicketService.lastReplyBody, 'Still broken');
    expect(supportTicketService.lastReplyRouteMode, RouteMode.allExceptRu);
    expect(supportTicketService.lastReplyStatusLabel, isNotEmpty);
    expect(supportTicketService.lastReplyDiagnostics?['platform'], 'windows');
    expect(supportTicketService.lastReplyDiagnostics?['route_mode'],
        RouteMode.allExceptRu.name);
    expect(supportTicketService.lastReplyDiagnostics?['connection_status'],
        isNotEmpty);
    expect(
        supportTicketService.lastReplyDiagnostics?['warp_status'], isNotEmpty);
    expect(
      supportTicketService.lastReplyDiagnostics?.keys.toSet(),
      <String>{
        'app_version',
        'platform',
        'route_mode',
        'connection_status',
        'warp_status',
      },
    );
    final diagnosticsJson =
        jsonEncode(supportTicketService.lastReplyDiagnostics);
    expect(diagnosticsJson, isNot(contains('WARP')));
    expect(diagnosticsJson, isNot(contains('wireguard')));
    expect(diagnosticsJson, isNot(contains('private-key')));
    expect(supportTicketService.lastReplyDiagnostics?.containsKey('raw_config'),
        isFalse);
    expect(
      supportTicketService.lastReplyDiagnostics
          ?.containsKey('subscription_url'),
      isFalse,
    );
    expect(
        find.byKey(const ValueKey('support-diagnostics-queued')), findsNothing);
    expect(find.text('Still broken'), findsOneWidget);
  });

  testWidgets(
      'support diagnostics actions stay reachable in constrained landscape',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(540, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);

    expect(find.byKey(const ValueKey('support-chat-composer')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const ValueKey('support-chat-send')).hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('support-attach-diagnostics')));
    await tester.pumpAndSettle();

    final cancel = find.byKey(const ValueKey('support-diagnostics-close'));
    final attach =
        find.byKey(const ValueKey('support-diagnostics-attach-next'));
    await tester.ensureVisible(cancel);
    await tester.ensureVisible(attach);

    expect(find.byKey(const ValueKey('support-diagnostics-preview')),
        findsOneWidget);
    expect(
      find.textContaining(
        'Код диагностики и показанная краткая сводка остаются доступны без загрузки',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('support-diagnostics-copy-code')),
      findsOneWidget,
    );
    expect(cancel.hitTestable(), findsOneWidget);
    expect(attach.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configured support key exposes encrypted offline delivery',
      (tester) async {
    final supportTicketService = _FakeEncryptedSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 902,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);
    await tester.tap(find.byKey(const ValueKey('support-attach-diagnostics')));
    await tester.pumpAndSettle();

    final encrypted =
        find.byKey(const ValueKey('support-diagnostics-send-encrypted'));
    await tester.ensureVisible(encrypted);
    expect(encrypted.hitTestable(), findsOneWidget);
    expect(
      find.textContaining('При обрыве сети сохранится только зашифрованный'),
      findsOneWidget,
    );

    await tester.tap(encrypted);
    await tester.pumpAndSettle();
    expect(supportTicketService.bundleCalls, 1);
    expect(
      find.textContaining('Зашифрованный пакет сохранен на устройстве'),
      findsOneWidget,
    );
  });

  testWidgets('support chat keeps optional actions out of the conversation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 901,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('desktop-sidebar-hamburger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-chat-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-issue-chips')), findsNothing);
    expect(
      find.byKey(const ValueKey('support-diagnostics-action')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('support-attach-diagnostics')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nav-ai-assistant')), findsNothing);

    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('support-chat-composer')),
    );
    expect(composer.controller?.text, isEmpty);
  });

  testWidgets('support history failure exposes one compact retry',
      (tester) async {
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 902,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      failListCalls: const <int>{1},
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);

    expect(
      find.byKey(const ValueKey('support-thread-lifecycle-offline')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('support-thread-refresh-action')),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('support-thread-refresh-action')),
    );
    await tester.pumpAndSettle();

    expect(supportTicketService.listCalls, 2);
    expect(
      find.byKey(const ValueKey('support-thread-lifecycle-ready')),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets(
      'support send retry preserves the draft without duplicate bubbles',
      (tester) async {
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 903,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      failCreateCalls: const <int>{1},
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);

    const draft = 'Не открываются сайты';
    final composer = find.byKey(const ValueKey('support-chat-composer'));
    await tester.enterText(composer, draft);
    await tester.tap(find.byKey(const ValueKey('support-chat-send')));
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 1);
    expect(
      find.byKey(const ValueKey('support-send-failure-notice')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(composer).controller?.text,
      draft,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('support-chat-message-list')),
        matching: find.text(draft),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('support-send-retry')));
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 2);
    expect(
      find.byKey(const ValueKey('support-send-failure-notice')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('support-chat-message-list')),
        matching: find.text(draft),
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(composer).controller?.text, isEmpty);
  });

  testWidgets('support AI entry preserves its purpose at 200 percent text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);

    final description = tester.widget<Text>(
      find.byKey(const ValueKey('support-ai-first-description')),
    );
    expect(description.maxLines, isNull);
    expect(tester.takeException(), isNull, reason: 'support at 200%');
  });

  testWidgets(
      'support AI assistant opens an honest mini chat and answers from the '
      'knowledge base', (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final assistantGate = Completer<void>();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      assistantReply: const ClientSupportAssistantReply(
        reply: '**Коротко:** Проверьте доступ. Подключение могло устареть.\n\n'
            '**Что сделать:** Переподключитесь. Затем проверьте выбранную страну.\n\n'
            '**Если не поможет:** Напишите в поддержку.',
        shouldEscalate: false,
        suggestedActions: <ClientSupportAssistantAction>[
          ClientSupportAssistantAction(
            key: 'retry_connect',
            label: 'Reconnect',
          ),
          ClientSupportAssistantAction(
            key: 'send_diagnostics',
            label: 'Attach diagnostics',
          ),
          ClientSupportAssistantAction(
            key: 'create_ticket',
            label: 'Write to support',
          ),
          ClientSupportAssistantAction(
            key: 'untrusted_action',
            label: 'Run hidden command',
          ),
        ],
        source: ClientSupportAssistantSource.pokrovAssistant,
      ),
      assistantGate: assistantGate.future,
    );
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 910,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _openSupportChatFromProfile(tester);

    // The existing automation greeting bubble now carries the unified
    // sparkle badge, matching the AI sheet styling.
    expect(find.text('ИИ'), findsOneWidget);

    final entry = find.byKey(const ValueKey('support-ai-first-card'));
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('support-assistant-sheet')),
      findsOneWidget,
    );
    expect(find.text('ИИ-помощник'), findsOneWidget);
    expect(
      find.text('WARP, локации, маршруты и системные разрешения'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-sheet-suggestions')),
      findsNothing,
    );
    expect(find.text('Не подключается'), findsNothing);
    expect(find.text('Медленно'), findsNothing);
    expect(find.text('Бонусы'), findsNothing);
    expect(
      find.byKey(const ValueKey('assistant-sheet-escalate')),
      findsOneWidget,
    );
    final sheetComposer = tester.widget<TextField>(
      find.byKey(const ValueKey('assistant-sheet-composer')),
    );
    expect(sheetComposer.textInputAction, TextInputAction.send);

    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Не получается подключиться',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('assistant-thinking-status')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('ИИ-помощник готовит ответ'), findsOneWidget);
    expect(find.text('ИИ-помощник готовит ответ…'), findsOneWidget);

    assistantGate.complete();
    await tester.pumpAndSettle();

    expect(bootstrapper.assistantCalls, 1);
    expect(bootstrapper.lastAssistantMessage, 'Не получается подключиться');
    expect(
      bootstrapper.lastAssistantDiagnostics?.keys.toSet(),
      <String>{
        'app_version',
        'platform',
        'route_mode',
        'connection_status',
        'connection_active',
        'current_location_label',
        'enhanced_protection_state',
        'enhanced_protection_consent',
        'enhanced_protection_available',
      },
    );
    expect(
      find.byKey(const ValueKey('assistant-thinking-status')),
      findsNothing,
    );
    expect(find.text('Не получается подключиться'), findsOneWidget);
    expect(find.text('Проверьте доступ.'), findsOneWidget);
    expect(find.text('Переподключитесь.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assistant-answer-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-answer-action')),
      findsOneWidget,
    );
    expect(find.text('Подключение могло устареть.'), findsNothing);
    expect(find.text('Затем проверьте выбранную страну.'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('assistant-answer-details-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подключение могло устареть.'), findsOneWidget);
    expect(find.text('Затем проверьте выбранную страну.'), findsOneWidget);
    expect(find.text('Напишите в поддержку.'), findsNothing);
    expect(
      find.byKey(const ValueKey('assistant-response-source-label')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('assistant-response-source-label')),
          )
          .data,
      'Помощник POKROV',
    );
    expect(find.text('ИИ'), findsWidgets);
    expect(
      find.byKey(const ValueKey('assistant-response-actions')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-action-retry_connect')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-action-send_diagnostics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-action-create_ticket')),
      findsNothing,
    );
    expect(find.text('Reconnect'), findsNothing);
    expect(find.text('Run hidden command'), findsNothing);
    expect(find.text('Нужен человек'), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('assistant-sheet-escalate'))),
      isA<TextButton>(),
    );

    await tester.tap(
      find.byKey(const ValueKey('assistant-action-retry_connect')),
    );
    await tester.pumpAndSettle();
    expect(bootstrapper.assistantCalls, 2);
    expect(
      bootstrapper.lastAssistantMessage,
      'Как безопасно переподключить POKROV?',
    );

    await tester.tap(find.byKey(const ValueKey('assistant-sheet-escalate')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('support-assistant-sheet')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('support-chat-screen')), findsOneWidget);
    final ticketComposer = tester.widget<TextField>(
      find.byKey(const ValueKey('support-chat-composer')),
    );
    expect(ticketComposer.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
      'support AI diagnostics action reuses the explicit attachment preview',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      assistantReply: const ClientSupportAssistantReply(
        reply: 'Приложите безопасную диагностику.',
        shouldEscalate: false,
        suggestedActions: <ClientSupportAssistantAction>[
          ClientSupportAssistantAction(
            key: 'send_diagnostics',
            label: 'Attach diagnostics',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);
    await tester.tap(find.byKey(const ValueKey('support-ai-first-card')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Подключение не работает',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('assistant-action-send_diagnostics')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('support-assistant-sheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('support-diagnostics-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('support-diagnostics-attach-next')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('support-diagnostics-attach-next')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('support-diagnostics-queued')),
      findsOneWidget,
    );
  });

  testWidgets(
      'support AI retry keeps one question bubble and returns concrete guidance',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      assistantReply: const ClientSupportAssistantReply(
        reply: '**Коротко:** Сначала проверьте обычное подключение.\n\n'
            '**Что сделать:** Выключите WARP, смените локацию, проверьте маршрут и системное разрешение VPN.',
        shouldEscalate: false,
        suggestedActions: <ClientSupportAssistantAction>[],
        source: ClientSupportAssistantSource.pokrovAssistant,
      ),
      assistantFailureCalls: const <int>{1},
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);
    await tester.tap(find.byKey(const ValueKey('support-ai-first-card')));
    await tester.pumpAndSettle();

    const question = 'Почему WARP не открывает сайты?';
    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      question,
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pumpAndSettle();

    expect(bootstrapper.assistantCalls, 1);
    expect(
      find.byKey(const ValueKey('assistant-request-failure-notice')),
      findsOneWidget,
    );
    expect(find.text(question), findsOneWidget);
    expect(
      find.text('Не нашёл ответа. Напишите в поддержку — ответит человек.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('assistant-request-retry')));
    await tester.pumpAndSettle();

    expect(bootstrapper.assistantCalls, 2);
    expect(bootstrapper.lastAssistantMessage, question);
    expect(find.text(question), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assistant-request-failure-notice')),
      findsNothing,
    );
    expect(
      find.text('Сначала проверьте обычное подключение.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Выключите WARP, смените локацию, проверьте маршрут и системное разрешение VPN.',
      ),
      findsOneWidget,
    );
    expect(find.text('Нужен человек'), findsOneWidget);
    expect(find.text('Передать в поддержку'), findsNothing);
    expect(
      tester.widget(find.byKey(const ValueKey('assistant-sheet-escalate'))),
      isA<TextButton>(),
    );
  });

  testWidgets('support AI composer stays above the Android keyboard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);
    await tester.tap(find.byKey(const ValueKey('support-ai-first-card')));
    await tester.pumpAndSettle();

    tester.view.viewInsets = FakeViewPadding(
      bottom: 260 * tester.view.devicePixelRatio,
    );
    await tester.pumpAndSettle();

    const visibleBottom = 380.0;
    expect(
      tester
          .getRect(find.byKey(const ValueKey('support-assistant-sheet')))
          .bottom,
      lessThanOrEqualTo(visibleBottom + 0.1),
    );
    expect(
      find.byKey(const ValueKey('assistant-sheet-composer')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-sheet-escalate')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'support AI assistant resets a failed continuation and keeps sessions sheet-local',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      assistantReply: const ClientSupportAssistantReply(
        reply: 'Продолжаем проверку подключения.',
        shouldEscalate: false,
        suggestedActions: <ClientSupportAssistantAction>[],
        assistantSessionId: 'session_1234567890abcdef',
      ),
      assistantFailureCalls: const <int>{2},
    );
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 912,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _openSupportChatFromProfile(tester);

    await tester.tap(find.byKey(
      const ValueKey('support-ai-first-card'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Не подключается',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Сайты всё ещё не открываются',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Начнём новую видимую цепочку',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pumpAndSettle();

    expect(
      bootstrapper.assistantSessionIds,
      <String?>[null, 'session_1234567890abcdef', null],
    );
    expect(
      bootstrapper.assistantDiagnostics
          .map((diagnostics) => diagnostics.keys.toSet()),
      everyElement(
        <String>{
          'app_version',
          'platform',
          'route_mode',
          'connection_status',
          'connection_active',
          'current_location_label',
          'enhanced_protection_state',
          'enhanced_protection_consent',
          'enhanced_protection_available',
        },
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('support-assistant-sheet')),
      findsNothing,
    );

    await tester.tap(find.byKey(
      const ValueKey('support-ai-first-card'),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Начнём заново',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-sheet-send')));
    await tester.pumpAndSettle();

    expect(
      bootstrapper.assistantSessionIds,
      <String?>[null, 'session_1234567890abcdef', null, null],
    );
  });

  testWidgets(
      'support AI assistant admits a missing answer instead of improvising',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      assistantReply: const ClientSupportAssistantReply(
        reply: '',
        shouldEscalate: true,
        suggestedActions: <ClientSupportAssistantAction>[],
      ),
    );
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 911,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _openSupportChatFromProfile(tester);

    await tester.tap(find.byKey(
      const ValueKey('support-ai-first-card'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('assistant-sheet-composer')),
      'Вопрос без ответа в базе',
    );
    // textInputAction.send submits the composer like the keyboard would.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(bootstrapper.assistantCalls, 1);
    expect(
      find.text('Не нашёл ответа. Напишите в поддержку — ответит человек.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-sheet-escalate')),
      findsOneWidget,
    );
    expect(find.text('Передать в поддержку'), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('assistant-sheet-escalate'))),
      isA<FilledButton>(),
    );
    expect(supportTicketService.calls, 0);
  });

  testWidgets('support chat polls active ticket and shows operator reply',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final existingThread = _supportThread(
      id: 889,
      status: 'open',
      statusTitle: 'Open',
      messages: <SupportTicketMessage>[
        _supportMessage(
          id: 1,
          ticketId: 889,
          senderRole: 'user',
          body: 'Need help',
        ),
      ],
    );
    final refreshedThread = _supportThread(
      id: 889,
      status: 'in_progress',
      statusTitle: 'В работе',
      messages: <SupportTicketMessage>[
        ...existingThread.messages,
        _supportMessage(
          id: 2,
          ticketId: 889,
          senderRole: 'admin',
          body: 'Operator is checking the route now.',
        ),
      ],
    );
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 889,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      tickets: <SupportTicketThread>[existingThread],
      loadedThreads: <SupportTicketThread>[
        existingThread,
        refreshedThread,
      ],
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('desktop-sidebar-hamburger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(supportTicketService.getCalls, 1);
    expect(find.byKey(const ValueKey('support-thread-lifecycle-tracking')),
        findsOneWidget);
    expect(find.text('Operator is checking the route now.'), findsNothing);

    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(supportTicketService.getCalls, greaterThanOrEqualTo(2));
    expect(find.text('Operator is checking the route now.'), findsOneWidget);
    expect(find.byKey(const ValueKey('support-thread-lifecycle-operator')),
        findsOneWidget);
    expect(find.text('Поддержка ответила'), findsOneWidget);
  });

  testWidgets('support polling stops while the app is in background',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'support-polling-lifecycle',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final thread = _supportThread(
      id: 891,
      status: 'open',
      statusTitle: 'Open',
      messages: <SupportTicketMessage>[
        _supportMessage(
          id: 1,
          ticketId: 891,
          senderRole: 'user',
          body: 'Need help',
        ),
      ],
    );
    final service = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 891,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      tickets: <SupportTicketThread>[thread],
      loadedThread: thread,
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        supportTicketService: service,
      ),
    );
    await tester.pumpAndSettle();
    await _openSupportChatFromProfile(tester);
    expect(service.getCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(service.getCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(service.getCalls, 2);
  });

  testWidgets('support chat shows offline lifecycle hint after poll failure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final existingThread = _supportThread(
      id: 890,
      status: 'open',
      statusTitle: 'Open',
      messages: <SupportTicketMessage>[
        _supportMessage(
          id: 1,
          ticketId: 890,
          senderRole: 'user',
          body: 'Need help',
        ),
      ],
    );
    final supportTicketService = _FakeSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 890,
        statusTitle: 'Open',
        messageCount: 1,
      ),
      tickets: <SupportTicketThread>[existingThread],
      loadedThread: existingThread,
      failGetAfter: 2,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        supportTicketService: supportTicketService,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('desktop-sidebar-hamburger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();

    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-thread-lifecycle-tracking')),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(supportTicketService.getCalls, greaterThanOrEqualTo(2));
    expect(find.byKey(const ValueKey('support-thread-lifecycle-offline')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('support-thread-refresh-action')),
        findsOneWidget);
    final failedReads = supportTicketService.getCalls;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(supportTicketService.getCalls, failedReads + 1);
  });

  testWidgets('rules show selected-apps editor and hide beta prose',
      (tester) async {
    _expectFeatureLabelHelpersCovered(const [
      '_routeModeShortLabel',
      '_routeModeRowTitle',
      '_routeModeRowSummary',
      '_PresetRow',
      '_rulesPresetIcon',
      '_rulesPresetStatusLabel',
    ]);
    _expectSharedShellWidgetHelpersCovered(const ['_SectionCard']);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-rules');

    final modeHelp = find.byKey(const ValueKey('rules-mode-help-action'));
    await tester.dragUntilVisible(
      modeHelp,
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(modeHelp, findsOneWidget);
    expect(find.text('Р’С‹Р±СЂР°РЅРЅС‹Рµ РїСЂРёР»РѕР¶РµРЅРёСЏ'), findsNothing);
    expect(find.byKey(const ValueKey('rules-mode-row-allExceptRu')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rules-mode-row-fullTunnel')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rules-mode-row-excludedApps')),
        findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rules-mode-row-allExceptRu')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rules-mode-row-allExceptRu')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );

    final selectedAppsStatus =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      selectedAppsStatus,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(selectedAppsStatus, findsOneWidget);
    expect(find.byKey(const ValueKey('rules-catalog-version')), findsNothing);
    expect(find.textContaining('2026-04-13'), findsNothing);

    final banksPreset = find.byKey(const ValueKey('rules-preset-ru-banks'));
    final gosuslugiPreset =
        find.byKey(const ValueKey('rules-preset-gosuslugi'));

    await tester.dragUntilVisible(
      banksPreset,
      find.byType(Scrollable).first,
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();

    expect(banksPreset, findsOneWidget);
    expect(gosuslugiPreset, findsOneWidget);
    expect(find.byKey(const ValueKey('rules-preset-messengers')), findsNothing);
    expect(
      find.descendant(of: banksPreset, matching: find.text('Активно')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gosuslugiPreset, matching: find.text('Активно')),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      selectedAppsStatus,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: selectedAppsStatus,
        matching: find.byKey(const ValueKey('rules-selected-app-input')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: selectedAppsStatus,
        matching: find.byKey(const ValueKey('rules-selected-app-pick')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('rules-selected-app-manual-toggle')),
        findsOneWidget);
    expect(find.textContaining('package id'), findsNothing);
    expect(find.textContaining('имя процесса'), findsNothing);
    expect(find.textContaining('geoip'), findsNothing);
    expect(find.textContaining('.srs'), findsNothing);
    expect(find.textContaining('CIDR'), findsNothing);
    expect(find.textContaining('rule_set'), findsNothing);
    expect(find.text('Р’С‹Р±СЂР°РЅРЅС‹Рµ РїСЂРёР»РѕР¶РµРЅРёСЏ РІ beta'),
        findsNothing);
    expect(
        find.text('Р§С‚Рѕ Р·РЅР°С‡РёС‚ РєР°Р¶РґС‹Р№ СЂРµР¶РёРј'), findsNothing);
  });

  testWidgets(
      'windows rules use region and process copy instead of mobile presets',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-rules');
    await tester.pumpAndSettle();

    expect(find.text('Маршруты Windows'), findsNothing);
    expect(find.text('Правила подключения'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('rules-preset-ru-region')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rules-preset-local-network')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rules-preset-selected-apps')),
      findsNothing,
    );
    expect(find.text('Российские банки'), findsNothing);
    expect(find.text('Госуслуги'), findsNothing);
    expect(find.text('Маркетплейсы'), findsNothing);

    final selectedAppsSection =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      selectedAppsSection,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: selectedAppsSection,
        matching: find.text('Только выбранные'),
      ),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('rules-selected-app-pick')), findsOneWidget);
    expect(find.text('Выбрать приложение'), findsOneWidget);
  });

  testWidgets('advanced routing controls persist real rules, DNS and LAN',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(760, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeClientExperienceStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');

    expect(find.byKey(const ValueKey('rules-dns-lan')), findsNothing);
    await _openAdvancedRules(tester);

    final dnsCard = find.byKey(const ValueKey('rules-dns-lan'));
    await tester.dragUntilVisible(
      dnsCard,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-ad-block-toggle')));
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.dnsPreset, PokrovDnsPreset.adguard);
    final directDnsToggle =
        find.byKey(const ValueKey('rules-dns-direct-toggle'));
    await tester.ensureVisible(directDnsToggle);
    await tester.pumpAndSettle();
    await tester.tap(directDnsToggle);
    await tester.pumpAndSettle();
    expect(
      store.state.routingPreferences.dnsTransport,
      PokrovDnsTransport.direct,
    );
    final lanToggle = find.byKey(const ValueKey('rules-lan-toggle'));
    await tester.ensureVisible(lanToggle);
    await tester.pumpAndSettle();
    await tester.tap(lanToggle);
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.allowLan, isFalse);

    final purposeCard = find.byKey(const ValueKey('rules-purpose-routes'));
    await tester.dragUntilVisible(
      purposeCard,
      find.byType(Scrollable).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-purpose-video')));
    await tester.pumpAndSettle();
    expect(
      store.state.routingPreferences.purposeRoutes,
      contains(PokrovPurposeRoute.video),
    );

    final customCard = find.byKey(const ValueKey('rules-custom-routes'));
    await tester.dragUntilVisible(
      customCard,
      find.byType(Scrollable).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-custom-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rules-custom-value-input')),
      'private.example',
    );
    await tester.tap(find.byKey(const ValueKey('rules-custom-save')));
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.overrides, hasLength(1));
    expect(
      store.state.routingPreferences.overrides.single.value,
      'private.example',
    );

    final changeSummary = find.byKey(const ValueKey('rules-change-summary'));
    await tester.dragUntilVisible(
      changeSummary,
      find.byType(Scrollable).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(changeSummary, findsOneWidget);
    expect(
      find.textContaining('DNS и локальная сеть'),
      findsOneWidget,
    );
    expect(find.textContaining('готовые маршруты'), findsOneWidget);
    expect(find.textContaining('свои правила'), findsOneWidget);
    expect(find.text('Сохранить изменения'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rules-apply-changes')));
    await tester.pumpAndSettle();
    expect(changeSummary, findsNothing);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('rules-route-explainer')),
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.enterText(
      find.byKey(const ValueKey('rules-route-explainer-input')),
      'private.example',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('rules-route-explainer-result')),
      findsOneWidget,
    );
    expect(find.text('Через POKROV VPN'), findsOneWidget);

    expect(store.writeCalls, greaterThanOrEqualTo(4));
    semantics.dispose();
  });

  testWidgets(
      'external Smart DNS lab requires custom direct DoH and an eligible purpose',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState.empty().copyWith(
        routingPreferences: const PokrovRoutingPreferences.defaults().copyWith(
          purposeRoutes: const <PokrovPurposeRoute>{PokrovPurposeRoute.ai},
          dnsPreset: PokrovDnsPreset.custom,
          dnsTransport: PokrovDnsTransport.direct,
          customDnsUrl: 'https://smart.example/dns-query',
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');
    await _openAdvancedRules(tester);

    final smartDnsToggle =
        find.byKey(const ValueKey('rules-external-smart-dns-toggle'));
    await tester.dragUntilVisible(
      smartDnsToggle,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(smartDnsToggle);
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.externalSmartDnsEnabled, isTrue);
    expect(
      find.textContaining('IP-адрес не скрывается'),
      findsWidgets,
    );

    final purposeCard = find.byKey(const ValueKey('rules-purpose-routes'));
    await tester.dragUntilVisible(
      purposeCard,
      find.byType(Scrollable).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-purpose-ai')));
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.externalSmartDnsEnabled, isFalse);
  });

  testWidgets('expert rules use one apply operation and one reconnect',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      retainHealthyConnectedSnapshot: true,
    );
    final store = _FakeClientExperienceStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'rules-apply-test',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    runtimeCalls.clear();

    await _tapNav(tester, 'nav-rules');
    await _openAdvancedRules(tester);
    final dnsCard = find.byKey(const ValueKey('rules-dns-lan'));
    await tester.dragUntilVisible(
      dnsCard,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    final adBlockToggle = find.byKey(const ValueKey('rules-ad-block-toggle'));
    await tester.ensureVisible(adBlockToggle);
    await tester.pumpAndSettle();
    await tester.tap(adBlockToggle);
    await tester.pumpAndSettle();
    final lanToggle = find.byKey(const ValueKey('rules-lan-toggle'));
    await tester.ensureVisible(lanToggle);
    await tester.pumpAndSettle();
    await tester.tap(lanToggle);
    await tester.pumpAndSettle();

    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.disconnect'),
      isEmpty,
    );
    final apply = find.byKey(const ValueKey('rules-apply-changes'));
    await tester.dragUntilVisible(
      apply,
      find.byType(Scrollable).first,
      const Offset(0, -340),
    );
    await tester.pumpAndSettle();
    expect(find.text('Применить и переподключить'), findsOneWidget);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.disconnect'),
      hasLength(1),
    );
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(1),
    );
    expect(
      find.text('Правила подключения применены.'),
      findsWidgets,
    );
  });

  testWidgets('Windows advanced settings retain service VPN and TUN stack',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeClientExperienceStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');

    expect(
      find.byKey(const ValueKey('rules-windows-connection')),
      findsNothing,
    );
    await _openAdvancedRules(tester);

    final card = find.byKey(const ValueKey('rules-windows-connection'));
    await tester.dragUntilVisible(
      card,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('rules-windows-tun-stack')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('rules-windows-tun-stack')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rules-windows-stack-mixed')),
    );
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.tunStack, PokrovTunStack.mixed);

    expect(
      store.state.routingPreferences.windowsConnectionMode,
      PokrovWindowsConnectionMode.vpn,
    );
    expect(
      find.byKey(const ValueKey('rules-windows-tun-stack')),
      findsOneWidget,
    );
  });

  testWidgets('trusted Wi-Fi detects, stores and enables a real network rule',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeClientExperienceStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        clientExperienceStore: store,
        currentWifiProbe: () async => const PokrovWifiNetworkStatus(
          connected: true,
          name: 'Home WiFi',
          permissionRequired: false,
          reason: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');
    await _openAdvancedRules(tester);

    final card = find.byKey(const ValueKey('rules-trusted-wifi'));
    await tester.dragUntilVisible(
      card,
      find.byType(Scrollable).first,
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rules-trusted-wifi-detect')),
    );
    await tester.pumpAndSettle();

    expect(store.state.routingPreferences.trustedWifiNames, ['Home WiFi']);
    expect(find.text('Сеть «Home WiFi» добавлена.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('rules-trusted-wifi-toggle')),
    );
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.pauseOnTrustedWifi, isTrue);
  });

  testWidgets('trusted Wi-Fi accepts a manual network without framework errors',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeClientExperienceStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');
    await _openAdvancedRules(tester);

    final card = find.byKey(const ValueKey('rules-trusted-wifi'));
    await tester.dragUntilVisible(
      card,
      find.byType(Scrollable).first,
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rules-trusted-wifi-manual')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rules-trusted-wifi-manual-input')),
      'POKROV-QA-TEST',
    );
    await tester.tap(
      find.byKey(const ValueKey('rules-trusted-wifi-manual-save')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      store.state.routingPreferences.trustedWifiNames,
      <String>['POKROV-QA-TEST'],
    );
  });

  testWidgets('trusted Wi-Fi blocks connect before runtime staging',
      (tester) async {
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(calls: runtimeCalls);
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState.empty().copyWith(
        routingPreferences: const PokrovRoutingPreferences.defaults().copyWith(
          trustedWifiNames: const ['Home WiFi'],
          pauseOnTrustedWifi: true,
        ),
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'test-profile',
            configPayload: '{}',
            materializedForRuntime: true,
          ),
        ),
        clientExperienceStore: store,
        currentWifiProbe: () async => const PokrovWifiNetworkStatus(
          connected: true,
          name: 'Home WiFi',
          permissionRequired: false,
          reason: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    runtimeCalls.clear();

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    expect(runtimeCalls, isNot(contains('runtimeEngine.initialize')));
    expect(runtimeCalls, isNot(contains('runtimeEngine.stageManagedProfile')));
    expect(runtimeCalls, isNot(contains('runtimeEngine.connect')));
    expect(find.textContaining('доверенной сети «Home WiFi»'), findsWidgets);
  });

  testWidgets('Android rules open the host VPN settings action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var openCalls = 0;

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        vpnSettingsLauncher: () async {
          openCalls += 1;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');
    await _openAdvancedRules(tester);

    final action = find.byKey(const ValueKey('rules-open-vpn-settings'));
    await tester.dragUntilVisible(
      action,
      find.byType(Scrollable).first,
      const Offset(0, -620),
    );
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(openCalls, 1);
  });

  testWidgets('desktop shell controller attaches and detaches with the app',
      (tester) async {
    final controller = PokrovShellController();
    expect(controller.attached, isFalse);

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.attached, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(controller.attached, isFalse);
  });

  testWidgets(
      'desktop shell waits for saved route scope before elevated continuation',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final controller = PokrovShellController();
    final store = _DelayedClientExperienceStore(
      const PokrovClientExperienceState.empty().copyWith(
        firstRouteScopeConfirmed: true,
        firstRouteScopeMode: RouteMode.fullTunnel,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        // The shell-controller gate is shared. Android's test bridge makes
        // the runtime independently ready so this regression isolates the
        // delayed preference restore that broke Windows tray handoff.
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        shellController: controller,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pump();

    expect(controller.attached, isTrue);
    expect(controller.canToggle, isFalse);

    store.releaseStaleRead();
    await tester.pumpAndSettle();

    expect(controller.canToggle, isTrue);
  });

  testWidgets('rules lets user add a custom selected app identifier',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-rules');
    final selectedAppsSection =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      selectedAppsSection,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('rules-selected-app-manual-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rules-selected-app-manual-fields')),
        findsOneWidget);
    // Revealing the manual field focuses it for immediate typing.
    final manualInput = tester.widget<TextField>(
      find.byKey(const ValueKey('rules-selected-app-input')),
    );
    expect(manualInput.autofocus, isTrue);

    // Invalid manual input surfaces inline validation instead of silently
    // doing nothing.
    await tester.enterText(
      find.byKey(const ValueKey('rules-selected-app-input')),
      'плохое имя!',
    );
    await tester.tap(find.byKey(const ValueKey('rules-selected-app-add')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Не получилось добавить'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('rules-selected-app-input')),
      'com.example.special',
    );
    await tester.tap(find.byKey(const ValueKey('rules-selected-app-add')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Не получилось добавить'), findsNothing);
    expect(find.byKey(const ValueKey('rules-selected-app-com.example.special')),
        findsOneWidget);
    expect(find.text('com.example.special'), findsNothing);
    expect(find.text('Special'), findsOneWidget);

    await _tapNav(tester, 'nav-protection');
    await tester.pumpAndSettle();

    final routeChip = find.byKey(const ValueKey('home-route-chip'));
    expect(routeChip, findsOneWidget);
    expect(
      find.descendant(
        of: routeChip,
        matching: find.text('Только выбранные'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Android can keep selected apps direct and route the rest by VPN',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-rules');

    final excludedMode =
        find.byKey(const ValueKey('rules-mode-row-excludedApps'));
    await tester.dragUntilVisible(
      excludedMode,
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.tap(excludedMode);
    await tester.pumpAndSettle();

    final appsSection =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      appsSection,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    final picker = find.byKey(const ValueKey('rules-selected-app-pick'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      find.text('Выбранные приложения будут работать напрямую.'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Российские и локальные сервисы остаются на обычном подключении.'),
      findsNothing,
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'rules-selected-app-option-org.telegram.messenger',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Напрямую без POKROV'), findsOneWidget);
    expect(find.textContaining('Напрямую: 1'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('rules-selected-app-org.telegram.messenger'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'RU app presets classify installed packages and confirm both modes',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.listInstalledApps') {
        return <Map<String, Object?>>[
          <String, Object?>{
            'label': 'Chrome',
            'identifier': 'com.android.chrome',
            'subtitle': 'com.android.chrome',
          },
          <String, Object?>{
            'label': 'Яндекс Браузер',
            'identifier': 'com.yandex.browser',
            'subtitle': 'com.yandex.browser',
          },
        ];
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-rules');
    final ruPresets = find.byKey(const ValueKey('rules-ru-app-presets'));
    await tester.dragUntilVisible(
      ruPresets,
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(ruPresets, findsOneWidget);

    final directPreset =
        find.byKey(const ValueKey('rules-ru-apps-direct-preset'));
    await tester.tap(directPreset);
    await tester.pumpAndSettle();
    expect(find.text('RU-приложения напрямую'), findsOneWidget);
    expect(find.text('Яндекс Браузер'), findsOneWidget);
    expect(find.text('Chrome'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rules-ru-preset-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Напрямую: 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rules-selected-app-com.yandex.browser')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rules-selected-app-com.android.chrome')),
      findsNothing,
    );

    await tester.dragUntilVisible(
      ruPresets,
      find.byType(Scrollable).first,
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-ru-apps-vpn-preset')));
    await tester.pumpAndSettle();
    expect(find.text('Только RU-приложения через VPN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rules-ru-preset-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Через VPN: 1'), findsOneWidget);

    final picker = find.byKey(const ValueKey('rules-selected-app-pick'));
    await tester.dragUntilVisible(
      picker,
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rules-selected-app-filter-ru')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('rules-selected-app-option-com.yandex.browser'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('rules-selected-app-option-com.android.chrome'),
      ),
      findsNothing,
    );
  });

  testWidgets('rules app picker adds a known Android application',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-rules');
    final selectedAppsSection =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      selectedAppsSection,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    final openPicker = find.byKey(const ValueKey('rules-selected-app-pick'));
    await tester.dragUntilVisible(
      openPicker,
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.ensureVisible(openPicker);
    await tester.pumpAndSettle();
    await tester.tap(openPicker);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rules-selected-app-picker-sheet')),
        findsOneWidget);

    final telegramOption = find.byKey(
      const ValueKey(
        'rules-selected-app-option-org.telegram.messenger',
      ),
    );
    await tester.tap(
      find.descendant(of: telegramOption, matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('rules-selected-app-picker-sheet')),
      findsNothing,
    );
    await Scrollable.ensureVisible(
      tester.element(
        find.byKey(
          const ValueKey('rules-section-selected-apps'),
          skipOffstage: false,
        ),
      ),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('rules-selected-app-org.telegram.messenger'),
      ),
      findsOneWidget,
    );

    await _tapNav(tester, 'nav-protection');
    final routeChip = find.byKey(const ValueKey('home-route-chip'));
    expect(
      find.descendant(
        of: routeChip,
        matching: find.text('Только выбранные'),
      ),
      findsOneWidget,
    );
    // Settle the iOS bounce-back ballistic left by the picker drag before
    // the tree is disposed (BouncingScrollPhysics keeps a timer otherwise).
    await tester.pumpAndSettle();
  });

  testWidgets('rules app picker can use native Android catalog',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1024, 556));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetViewInsets);
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.listInstalledApps') {
        return <Map<String, Object?>>[
          <String, Object?>{
            'label': 'Signal',
            'identifier': 'org.thoughtcrime.securesms',
            'subtitle': 'org.thoughtcrime.securesms',
            'iconPngBase64':
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          },
          <String, Object?>{
            'label': 'Signal',
            'identifier': 'org.signal.clone',
            'subtitle': 'org.signal.clone',
          },
        ];
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-rules');
    final selectedAppsSection =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      selectedAppsSection,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    final nativePicker = find.byKey(
      const ValueKey('rules-selected-app-pick'),
    );
    final rulesScrollable = find
        .ancestor(of: nativePicker, matching: find.byType(Scrollable))
        .first;
    await tester.dragUntilVisible(
      nativePicker,
      rulesScrollable,
      const Offset(0, -180),
    );
    await tester.ensureVisible(nativePicker);
    await tester.pumpAndSettle();
    await tester.tap(nativePicker);
    await tester.pumpAndSettle();

    final nativeOption = find.byKey(
      const ValueKey(
        'rules-selected-app-option-org.thoughtcrime.securesms',
      ),
    );
    expect(nativeOption, findsOneWidget);
    expect(
      find.descendant(of: nativeOption, matching: find.byType(Image)),
      findsOneWidget,
    );
    tester.view.viewInsets = FakeViewPadding(
      bottom: 220 * tester.view.devicePixelRatio,
    );
    await tester.pumpAndSettle();
    final visibleBottom =
        556.0 - tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    expect(
      tester
          .getRect(
              find.byKey(const ValueKey('rules-selected-app-picker-sheet')))
          .bottom,
      lessThanOrEqualTo(visibleBottom + 0.1),
    );
    expect(tester.getRect(nativeOption).bottom,
        lessThanOrEqualTo(visibleBottom + 0.1));
    await tester.binding.setSurfaceSize(const Size(1024, 400));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 240 * tester.view.devicePixelRatio,
    );
    await tester.pumpAndSettle();
    final shortVisibleBottom =
        400.0 - tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('rules-selected-app-picker-sheet')),
          )
          .bottom,
      lessThanOrEqualTo(shortVisibleBottom + 0.1),
    );
    expect(
      tester.getRect(nativeOption).bottom,
      lessThanOrEqualTo(shortVisibleBottom + 0.1),
    );
    await tester.binding.setSurfaceSize(const Size(1024, 556));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Signal · 1'), findsOneWidget);
    expect(find.text('Signal · 2'), findsOneWidget);
    expect(find.text('org.thoughtcrime.securesms'), findsNothing);
    expect(find.text('org.signal.clone'), findsNothing);
    final availableSemantics = tester.widget<Semantics>(
      find.descendant(of: nativeOption, matching: find.byType(Semantics)).first,
    );
    expect(availableSemantics.properties.label, 'Signal · 2');
    expect(availableSemantics.properties.value, 'Не выбрано');
    expect(availableSemantics.properties.hint, 'Добавить приложение');
    expect(availableSemantics.properties.button, isTrue);
    expect(availableSemantics.properties.enabled, isTrue);
    expect(availableSemantics.properties.selected, isFalse);

    await tester.tap(nativeOption);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey('rules-selected-app-org.thoughtcrime.securesms'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('rules-selected-app-org.thoughtcrime.securesms'),
        ),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    final reopenPicker = find.byKey(const ValueKey('rules-selected-app-pick'));
    await Scrollable.ensureVisible(
      tester.element(reopenPicker),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(reopenPicker);
    await tester.pumpAndSettle();
    final selectedOption = find.byKey(
      const ValueKey(
        'rules-selected-app-option-org.thoughtcrime.securesms',
      ),
    );
    final selectedSemantics = tester.widget<Semantics>(
      find
          .descendant(of: selectedOption, matching: find.byType(Semantics))
          .first,
    );
    expect(selectedSemantics.properties.label, 'Signal · 2');
    expect(selectedSemantics.properties.value, 'Уже выбрано');
    expect(selectedSemantics.properties.enabled, isFalse);
    expect(selectedSemantics.properties.selected, isTrue);
    expect(find.bySemanticsLabel(RegExp('org\\.signal')), findsNothing);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();

    // Rows live inside an AnimatedSize wrapper so inserts/removals settle
    // smoothly; removing deletes the row.
    expect(
      find.ancestor(
        of: find.byKey(
          const ValueKey('rules-selected-app-org.thoughtcrime.securesms'),
        ),
        matching: find.byType(AnimatedSize),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey('rules-selected-app-org.thoughtcrime.securesms'),
        ),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('rules-selected-app-org.thoughtcrime.securesms'),
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('advanced settings open as diagnostics without acknowledgement',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    final advanced = find.byKey(const ValueKey('profile-diagnostics-action'));
    await tester.dragUntilVisible(
      advanced,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('diagnostics-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('diagnostics-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('diagnostics-freshness')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('diagnostics-evidence-tunnel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diagnostics-evidence-dns')),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('diagnostics-bundle-categories')),
      find.byKey(const ValueKey('diagnostics-scroll')),
      const Offset(0, -260),
    );
    expect(
      find.byKey(const ValueKey('diagnostics-redaction-count')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('diagnostics creates a case with one encrypted bundle action',
      (tester) async {
    final service = _FakeEncryptedSupportTicketService(
      const SupportTicketReceipt(
        ticketId: 1204,
        statusTitle: 'Open',
        messageCount: 1,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        supportTicketService: service,
        protectionProbe: (_) async => const PokrovHttpsProbeResult.healthy(),
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-profile');

    final diagnostics =
        find.byKey(const ValueKey('profile-diagnostics-action'));
    await tester.dragUntilVisible(
      diagnostics,
      find.byType(Scrollable).first,
      const Offset(0, -260),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    expect(diagnostics.hitTestable(), findsOneWidget);
    await tester.tap(diagnostics);
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey('diagnostics-create-case-bundle'));
    await tester.dragUntilVisible(
      create,
      find.byKey(const ValueKey('diagnostics-scroll')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(service.bundleCalls, 1);
    expect(service.lastBundleHostPlatform, HostPlatform.android);
    expect(service.lastBundleTicketId, isNull,
        reason: 'null asks the transfer service to create the case first');
    expect(service.lastBundleCaseSummary, contains(pokrovClientVersion));
    expect(service.lastPreparedBundle?.preview.profile.name, 'summary');
    final delivery = find.byKey(const ValueKey('diagnostics-delivery-result'));
    await tester.ensureVisible(delivery);
    expect(find.textContaining('Обращение #1204 создано'), findsOneWidget);
  });

  testWidgets(
      'android protection surface keeps degraded runtime messaging consumer friendly',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'core_egress_validated': true,
            'message': 'Android runtime service is running.',
            'hostDiagnostics': <String, Object?>{
              'health': 'degraded',
              'dnsStatus': 'degraded',
              'uplinkStatus': 'healthy',
              'summary': 'DNS degraded on the current uplink.',
            },
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('home-status-switcher')), findsOneWidget);
    expect(find.textContaining('POKROV'), findsWidgets);
    expect(find.textContaining('Host diagnostics'), findsNothing);
  });

  testWidgets('windows observes service loss after a long connected session',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger = tester.binding.defaultBinaryMessenger;
    var phase = 'running';
    var snapshotCalls = 0;
    var egressHealthy = true;
    Completer<Map<String, Object?>>? heldSnapshot;
    var heldSnapshotClaimed = false;
    Map<String, Object?> hostSnapshot() => <String, Object?>{
      'phase': phase,
      'artifactDirectory': '/host/runtime',
      'coreBinaryPath': '/host/runtime/pokrov-core.dll',
      'stagedConfigPath': phase == 'initialized'
          ? null : '/host/runtime/managed-profile.json',
      'supportsLiveConnect': true,
      'canInitialize': true,
      'canConnect': phase == 'configStaged',
      'hostHealth': phase == 'running' ? 'healthy' : 'unknown',
      'dnsState': phase == 'running' ? 'healthy' : 'unknown',
      'uplinkState': phase == 'running' ? 'healthy' : 'unknown',
      'core_egress_validated': phase == 'running' && egressHealthy,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          snapshotCalls += 1;
          if (heldSnapshot != null && !heldSnapshotClaimed) {
            heldSnapshotClaimed = true;
            return heldSnapshot.future;
          }
        case 'runtimeEngine.initialize':
          phase = 'initialized';
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
        case 'runtimeEngine.connect':
          phase = 'running';
        case 'runtimeEngine.disconnect':
          phase = 'initialized';
        default:
          return null;
      }
      return hostSnapshot();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final controller = PokrovShellController();
    final bootstrapper = _FakeBootstrapper(const ManagedProfilePayload(
      profileName: 'windows-service-restart',
      configPayload: _materializedRuntimeConfig,
      materializedForRuntime: true,
    ));
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      bootstrapper: bootstrapper,
      shellController: controller,
      firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      clientExperienceStore:
          _FakeClientExperienceStore(const PokrovClientExperienceState.empty()),
      windowsTunnelAuthorizer: () async =>
          PokrovWindowsTunnelAuthorization.allowed,
    ));
    await tester.pumpAndSettle();
    expect(controller.isConnected, isTrue);
    var statusNotifications = 0;
    controller.addListener(() => statusNotifications += 1);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(statusNotifications, 0,
        reason: 'unchanged local status must not rebuild the shell and tray');
    egressHealthy = false;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(controller.isConnected, isFalse);
    expect(statusNotifications, 1,
        reason: 'a health change in the running phase must reach the UI');
    egressHealthy = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(controller.isConnected, isTrue);
    expect(statusNotifications, 2);
    phase = 'initialized'; // SCM restarted; its durable recovery cleared TUN.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(controller.isConnected, isFalse);
    expect(find.text('Подключено'), findsNothing);
    expect(bootstrapper.calls, 0, reason: 'local status must not fetch profiles');

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    expect(controller.isConnected, isTrue);
    expect(bootstrapper.calls, 1);
    final staleRunningSnapshot = hostSnapshot();
    heldSnapshot = Completer<Map<String, Object?>>();
    addTearDown(() {
      if (!heldSnapshot!.isCompleted) heldSnapshot.complete(hostSnapshot());
    });
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final callsWhilePending = snapshotCalls;
    await tester.pump(const Duration(seconds: 10));
    expect(snapshotCalls, callsWhilePending,
        reason: 'only one local status request may be in flight');
    expect(controller.canToggle, isTrue,
        reason: 'attached=${controller.attached} busy=${controller.isBusy}');
    await controller.toggleConnection();
    await tester.pumpAndSettle();
    expect(controller.isConnected, isFalse);
    heldSnapshot.complete(staleRunningSnapshot);
    await tester.pumpAndSettle();
    expect(controller.isConnected, isFalse,
        reason: 'a late status response cannot undo an explicit disconnect');
    await tester.pumpWidget(const SizedBox.shrink());
    final callsAtDispose = snapshotCalls;
    await tester.pump(const Duration(seconds: 5));
    expect(snapshotCalls, callsAtDispose);
  });

  testWidgets('android refreshes delayed degraded host health after connect',
      (tester) async {
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      reportDegradedAfterConnect: true,
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-delayed-health',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    // The Android host owns an up-to-eight-second selected-outbound probe;
    // the shell refreshes after its bounded 11-second completion window.
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(find.text('Нужно внимание'), findsOneWidget);
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.snapshot').length,
      greaterThanOrEqualTo(2),
    );
  });

  for (final (
        description: description,
        hostPlatform: hostPlatform,
        coreEgressValidated: coreEgressValidated,
        expectedStatus: expectedStatus,
      ) in <({
    String description,
    HostPlatform hostPlatform,
    bool? coreEgressValidated,
    String expectedStatus,
  })>[
    (
      description: 'waits for selected-outbound egress proof',
      hostPlatform: HostPlatform.android,
      coreEgressValidated: null,
      expectedStatus: 'Проверяем…',
    ),
    (
      description: 'marks failed selected-outbound egress degraded',
      hostPlatform: HostPlatform.android,
      coreEgressValidated: false,
      expectedStatus: 'Нужно внимание',
    ),
    (
      description: 'shows connected after selected-outbound egress proof',
      hostPlatform: HostPlatform.android,
      coreEgressValidated: true,
      expectedStatus: 'Подключено',
    ),
  ]) {
    testWidgets('android running $description', (tester) async {
      const channel = MethodChannel('space.pokrov/runtime_engine');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'runtimeEngine.snapshot') {
          return null;
        }
        return <String, Object?>{
          'phase': 'running',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Runtime service is running.',
          'hostHealth': 'healthy',
          'dnsState': 'healthy',
          'uplinkState': 'healthy',
          'core_egress_validated': coreEgressValidated,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(
        PokrovSeedApp(
          appContext: buildSeedAppContext(hostPlatform: hostPlatform),
        ),
      );
      await tester.pumpAndSettle();
      await _completeFirstLaunchIfPresent(tester);

      final status = find.descendant(
        of: find.byKey(const ValueKey('home-connection-details-action')),
        matching: find.text(expectedStatus),
      );
      expect(status, findsOneWidget);
      if (coreEgressValidated != true) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-connection-details-action')),
            matching: find.text('Подключено'),
          ),
          findsNothing,
        );
      }
    });
  }

  testWidgets('explicit inactive subscription blocks cached reconnect on profile 503', (tester) async {
    final calls = <String>[];
    _installReadyRuntimeBridgeMock(calls: calls,
      retainHealthyConnectedSnapshot: true);
    final bootstrapper = _CachedBootstrapper(const ManagedProfilePayload(
      profileName: 'cached-profile', configPayload: _materializedRuntimeConfig,
      materializedForRuntime: true, cacheEntryId: 'cached-entry',
    ));
    bootstrapper.subscriptionInfo = const ClientSubscriptionInfo(
      lane: 'expiredOrBlocked', expiresAt: '', daysLeft: 0,
      autoRenew: false, renewUrl: null, plans: [], trafficPolicy: {},
    );
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
    ));
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'runtimeEngine.connect'), isEmpty);
    expect(bootstrapper.provenEntries, isEmpty);
  });

  testWidgets('explicit inactive subscription disconnects a cached tunnel on resume', (tester) async {
    final calls = <String>[];
    _installReadyRuntimeBridgeMock(calls: calls,
      retainHealthyConnectedSnapshot: true);
    final bootstrapper = _CachedBootstrapper(const ManagedProfilePayload(
      profileName: 'cached-profile', configPayload: _materializedRuntimeConfig,
      materializedForRuntime: true, cacheEntryId: 'cached-entry',
    ));
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
    ));
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'runtimeEngine.connect').length, 1);
    bootstrapper.subscriptionInfo = const ClientSubscriptionInfo(
      lane: 'expiredOrBlocked', expiresAt: '', daysLeft: 0,
      autoRenew: false, renewUrl: null, plans: [], trafficPolicy: {},
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'runtimeEngine.disconnect').length, 1);
    expect(find.text('Подключено'), findsNothing);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'runtimeEngine.connect').length, 1);
  });

  testWidgets('inactive subscription during native connect stops the settled tunnel', (tester) async {
    final calls = <String>[];
    final connectGate = Completer<void>();
    _installReadyRuntimeBridgeMock(calls: calls,
      retainHealthyConnectedSnapshot: true, connectGate: connectGate.future);
    final bootstrapper = _CachedBootstrapper(const ManagedProfilePayload(
      profileName: 'cached-profile', configPayload: _materializedRuntimeConfig,
      materializedForRuntime: true, cacheEntryId: 'cached-entry',
    ));
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
    ));
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls.where((c) => c == 'runtimeEngine.connect').length, 1);
    bootstrapper.subscriptionInfo = const ClientSubscriptionInfo(
      lane: 'expiredOrBlocked', expiresAt: '', daysLeft: 0,
      autoRenew: false, renewUrl: null, plans: [], trafficPolicy: {},
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    connectGate.complete();
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'runtimeEngine.disconnect').length, 1);
    expect(find.text('Подключено'), findsNothing);
  });

  for (final status in [503, 403]) {
    testWidgets('cached Android profile handles API $status after app restart', (tester) async {
      final calls = <String>[];
      final staged = <String>[];
      _installReadyRuntimeBridgeMock(calls: calls, stagedPayloads: staged,
        retainHealthyConnectedSnapshot: true);
      final bootstrapper = _CachedBootstrapper(const ManagedProfilePayload(
        profileName: 'cached-profile', configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true, cacheEntryId: 'cached-entry',
      ), status: status);
      await tester.pumpWidget(PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ));
      await tester.pumpAndSettle();
      await _completeFirstLaunchIfPresent(tester);
      await _tapPrimaryConnectAndConfirmRouteScope(tester);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'runtimeEngine.connect').length, status == 503 ? 1 : 0);
      expect(staged.length, status == 503 ? 1 : 0);
      expect(bootstrapper.cacheReads, isNotEmpty);
      if (status == 503) expect(bootstrapper.provenEntries, contains('cached-entry'));
    });
  }

  testWidgets('manual retry after egress failure retains the cached profile during API outage', (tester) async {
    final calls = <String>[];
    _installReadyRuntimeBridgeMock(calls: calls, failAfterConnect: true);
    final bootstrapper = _CachedBootstrapper(const ManagedProfilePayload(
      profileName: 'cached-profile', configPayload: _materializedRuntimeConfig,
      materializedForRuntime: true, cacheEntryId: 'cached-entry',
    ));
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: bootstrapper,
    ));
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Подключено'), findsNothing);
    final invalidations = calls.where((c) => c == 'runtimeEngine.invalidateManagedProfile').length;
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'runtimeEngine.connect').length, 2);
    expect(bootstrapper.cacheReads, contains(true));
    expect(calls.where((c) => c == 'runtimeEngine.invalidateManagedProfile').length, invalidations);
  });

  testWidgets('android egress fail-closed stop clears the connected home state',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final runtimeCalls = <String>[];
    var connected = false;
    var runningSnapshots = 0;

    Map<String, Object?> snapshot() {
      if (!connected) {
        return <String, Object?>{
          'phase': 'artifactReady',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': false,
          'message': 'Host bridge ready.',
        };
      }
      runningSnapshots += 1;
      if (runningSnapshots >= 2) {
        return <String, Object?>{
          'phase': 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'core_egress_validated': false,
          'last_failure_kind': 'core_egress_probe_failed',
          'last_stop_reason': 'core_egress_probe_failed',
          'message':
              'POKROV не подтвердил защищенное подключение и отключил системный VPN.',
        };
      }
      return <String, Object?>{
        'phase': 'running',
        'artifactDirectory': '/host/runtime',
        'coreBinaryPath': '/host/runtime/pokrov-core.aar',
        'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
        'supportsLiveConnect': true,
        'canInitialize': true,
        'canConnect': true,
        'core_egress_validated': null,
        'message': 'Runtime service is running.',
      };
    }

    messenger.setMockMethodCallHandler(channel, (call) async {
      runtimeCalls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot();
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime initialized.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged.',
          };
        case 'runtimeEngine.connect':
          connected = true;
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'core_egress_validated': null,
            'message': 'Runtime service is running.',
          };
        case 'runtimeEngine.invalidateManagedProfile':
          connected = false;
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Cached profile invalidated.',
          };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-egress-failure',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-location-chip')),
        matching: find.text('Автоматически'),
      ),
      findsOneWidget,
    );
    expect(find.text('Подключено'), findsNothing);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.textContaining('core_egress_probe_failed'), findsNothing);
    expect(runtimeCalls.where((c) => c == 'runtimeEngine.invalidateManagedProfile').length,
        lessThanOrEqualTo(1)); // Initial route consent may invalidate; failure does not.
  });

  for (final (
        host,
        labFallback,
        baselineFails,
        proofUnavailable,
        bootstrapRefused,
      )
      in [
        (HostPlatform.android, false, false, false, false),
        (HostPlatform.android, true, false, false, false),
        (HostPlatform.windows, true, false, false, false),
        (HostPlatform.android, true, true, false, false),
        (HostPlatform.android, true, false, true, false),
        (HostPlatform.android, true, false, false, true),
      ]) {
    testWidgets(
      'managed fallback on ${host.name} (lab: $labFallback, baseline failure: $baselineFails, unavailable: $proofUnavailable, refused: $bootstrapRefused)',
      (tester) async {
        const channel = MethodChannel('space.pokrov/runtime_engine');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var connectCalls = 0;
        var firstConnectSnapshots = 0;

        Map<String, Object?> runtimeState(
          String phase, {
          bool? egressValidated,
          String message = 'Runtime ready.',
          String? failureKind,
        }) => <String, Object?>{
          'phase': phase,
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          if (phase == 'configStaged' || phase == 'running')
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': phase == 'configStaged' || phase == 'running',
          if (phase == 'running') 'hostHealth': 'healthy',
          if (phase == 'running') 'dnsState': 'healthy',
          if (phase == 'running') 'uplinkState': 'healthy',
          if (phase == 'running' || egressValidated != null)
            'core_egress_validated': egressValidated,
          if (failureKind != null) 'last_failure_kind': failureKind,
          if (failureKind != null) 'last_stop_reason': failureKind,
          'message': message,
        };

        messenger.setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'runtimeEngine.snapshot':
              if (connectCalls == 0) {
                return runtimeState('artifactReady');
              }
              if (baselineFails && connectCalls > 1) {
                return runtimeState(
                  'configStaged',
                  egressValidated: false,
                  failureKind: 'core_egress_probe_failed',
                  message: 'Fixture path failed.',
                );
              }
              if (connectCalls == 1) {
                firstConnectSnapshots += 1;
                if (firstConnectSnapshots >= 2 ||
                    host == HostPlatform.windows) {
                  return runtimeState(
                    'configStaged',
                    egressValidated: false,
                    failureKind: proofUnavailable
                        ? 'core_egress_probe_unavailable'
                        : 'core_egress_probe_failed',
                    message:
                        'POKROV не подтвердил защищенное подключение и отключил системный VPN.',
                  );
                }
                return runtimeState(
                  'running',
                  message: 'Runtime service is running.',
                );
              }
              return runtimeState(
                'running',
                egressValidated: true,
                message: 'Runtime service is running.',
              );
            case 'runtimeEngine.initialize':
              return runtimeState('initialized');
            case 'runtimeEngine.stageManagedProfile':
              return runtimeState('configStaged');
            case 'runtimeEngine.connect':
              connectCalls += 1;
              if ((host == HostPlatform.windows && connectCalls == 1) ||
                  (baselineFails && connectCalls > 1)) {
                return runtimeState(
                  'configStaged',
                  egressValidated: false,
                  failureKind: 'core_egress_probe_failed',
                  message: 'Fixture path failed.',
                );
              }
              return runtimeState(
                'running',
                egressValidated: connectCalls > 1 ? true : null,
                message: 'Runtime service is running.',
              );
            case 'runtimeEngine.invalidateManagedProfile':
              return runtimeState('initialized');
          }
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

        const smartConnect = SmartConnectProfile(
          eligible: true,
          fallbackRequired: false,
          shortlistReason: 'eligible',
          shortlistLimit: 2,
          shortlistRevision: 'failover-shortlist',
          transportProfile: 'reality',
          profileRevision: 'failover-profile',
          fallbackOrder: <String>['nl', 'ru-spb'],
          shortlist: <SmartConnectNode>[
            SmartConnectNode(
              code: 'nl',
              country: 'Netherlands',
              rank: 1,
              rankHint: SmartConnectRankHint(
                healthScore: 96,
                cpuPercent: 8,
                panelLatencyMs: 24,
                backendPenalty: 0,
                cpuPenalty: 0,
                stickyPreferred: false,
              ),
            ),
            SmartConnectNode(
              code: 'ru-spb',
              country: 'Russia',
              rank: 2,
              rankHint: SmartConnectRankHint(
                healthScore: 92,
                cpuPercent: 12,
                panelLatencyMs: 40,
                backendPenalty: 0,
                cpuPenalty: 0,
                stickyPreferred: false,
              ),
            ),
          ],
          stickiness: SmartConnectStickiness(
            preferredNodeCode: '',
            thresholdPercent: 15,
            latestSampleAt: '',
            stickinessApplied: false,
          ),
        );
        const basePayload = ManagedProfilePayload(
          profileName: 'automatic-egress-failover',
          configPayload: _materializedRuntimeConfig,
          materializedForRuntime: true,
          smartConnect: smartConnect,
        );
        final bootstrapper = _FakeBootstrapper(
          basePayload,
          managedProfileResolver: (call, excludedNodeCodes) =>
              bootstrapRefused && call > 1
              ? throw const BootstrapFailure(
                  'Резервное подключение недоступно.',
                  statusCode: 503,
                )
              : labFallback && call == 1
              ? const ManagedProfilePayload(
                  profileName: 'owned-lab-profile',
                  configPayload: _materializedRuntimeConfig,
                  materializedForRuntime: true,
                  tcpFallbackFromRevision: 'lab-generation-1',
                )
              : basePayload.copyWith(
                  resolvedNodeCode: call == 1 ? 'nl' : 'ru-spb',
                ),
        );
        final store = _FakeClientExperienceStore();

        await tester.pumpWidget(
          PokrovSeedApp(
            appContext: buildSeedAppContext(hostPlatform: host),
            bootstrapper: bootstrapper,
            windowsTunnelAuthorizer: () async =>
                PokrovWindowsTunnelAuthorization.allowed,
            firstLaunchStore: _FakeFirstLaunchStore(completed: true),
            clientExperienceStore: store,
          ),
        );
        await tester.pumpAndSettle();
        await _tapPrimaryConnectAndConfirmRouteScope(tester);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(connectCalls, proofUnavailable || bootstrapRefused ? 1 : 2);
        expect(bootstrapper.calls, proofUnavailable ? 1 : 2);
        expect(bootstrapper.excludedNodeCodeRequests.first, isEmpty);
        expect(
          bootstrapper.excludedNodeCodeRequests.last,
          labFallback ? isEmpty : <String>{'nl'},
        );
        expect(
          bootstrapper.tcpFallbackRequests,
          proofUnavailable
              ? ['']
              : labFallback
              ? ['', 'lab-generation-1']
              : ['', ''],
        );
        expect(store.state.preferredNodeCode, isEmpty);
        expect(
          store.state.automaticNodeQuarantineUntil,
          baselineFails
              ? contains('ru-spb')
              : labFallback
              ? isEmpty
              : contains('nl'),
        );
        expect(bootstrapper.lastRouteMode, store.state.firstRouteScopeMode);
        expect(
          find.text('Отключить'),
          baselineFails || proofUnavailable || bootstrapRefused
              ? findsNothing
              : findsOneWidget,
        );
        if (!baselineFails && !proofUnavailable && !bootstrapRefused) {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('home-location-chip')),
              matching: find.text('Россия'),
            ),
            findsOneWidget,
          );
        }
        final attemptsBeforeWait = connectCalls;
        await tester.pump(const Duration(seconds: 20));
        await tester.pumpAndSettle();
        expect(connectCalls, attemptsBeforeWait);
      },
    );
  }

  testWidgets('stale Android egress poll cannot override a newer connection',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final stalePoll = Completer<Map<String, Object?>>();
    var connectRun = 0;
    var stalePollStarted = false;

    Map<String, Object?> runtimeSnapshot({required bool running}) =>
        <String, Object?>{
          'phase': running ? 'running' : 'configStaged',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'core_egress_validated': null,
          'message':
              running ? 'Runtime service is running.' : 'Runtime stopped.',
        };

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          if (connectRun == 0) {
            return <String, Object?>{
              'phase': 'artifactReady',
              'artifactDirectory': '/host/runtime',
              'coreBinaryPath': '/host/runtime/pokrov-core.aar',
              'supportsLiveConnect': true,
              'canInitialize': true,
              'canConnect': false,
              'message': 'Host bridge ready.',
            };
          }
          if (connectRun == 1 && !stalePollStarted) {
            stalePollStarted = true;
            return stalePoll.future;
          }
          return runtimeSnapshot(running: true);
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime initialized.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return runtimeSnapshot(running: false);
        case 'runtimeEngine.connect':
          connectRun += 1;
          return runtimeSnapshot(running: true);
        case 'runtimeEngine.disconnect':
          return runtimeSnapshot(running: false);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-stale-egress-poll',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(stalePollStarted, isTrue);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(connectRun, 2);

    stalePoll.complete(<String, Object?>{
      ...runtimeSnapshot(running: false),
      'core_egress_validated': false,
      'last_failure_kind': 'core_egress_probe_failed',
      'last_stop_reason': 'core_egress_probe_failed',
      'message':
          'POKROV не подтвердил защищенное подключение и отключил системный VPN.',
    });
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Отключить'), findsOneWidget);
    expect(find.text('Не защищено'), findsNothing);
    expect(find.textContaining('core_egress_probe_failed'), findsNothing);
  });

  testWidgets('android protection surface hides raw top-level host diagnostics',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android tun established.',
            'default_network_interface': 'wlan0',
            'default_network_index': 42,
            'dns_ready': false,
            'last_failure_kind': 'default_network_unavailable',
            'ipv4_route_count': 2,
            'ipv6_route_count': 0,
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('home-status-switcher')), findsOneWidget);
    expect(find.textContaining('POKROV'), findsWidgets);
    expect(
        find.textContaining('РџРѕСЃР»РµРґРЅСЏСЏ РѕС€РёР±РєР°'), findsNothing);
    expect(
      find.text('POKROV РІРєР»СЋС‡РµРЅ.'),
      findsNothing,
    );
  });

  testWidgets('shows a single logical location in locations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-locations');

    expect(
        find.byKey(const ValueKey('locations-auto-section')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('locations-skeleton-list')), findsOneWidget);
    expect(
        find.textContaining('РџРѕР»РЅС‹Р№ РґРѕСЃС‚СѓРї РёСЃРїРѕР»СЊР·СѓРµС‚'),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('locations-auto-help-action')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('POKROV'), findsWidgets);
  });

  testWidgets(
      'stale manual location can return to automatic before provisioning',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState.empty().copyWith(
        preferredNodeCode: 'nl',
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'stale-location-recovery',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');

    final autoLocation = find.byKey(
      const ValueKey('locations-auto-section'),
    );
    expect(
      find.descendant(of: autoLocation, matching: find.text('Вручную')),
      findsOneWidget,
    );
    expect(
      find.textContaining('вернуть авто'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('locations-auto-help-action')),
    );
    await tester.pumpAndSettle();

    expect(store.state.preferredNodeCode, isEmpty);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.text('Автоматический выбор включен. Подключите POKROV.'),
      findsOneWidget,
    );
  });

  testWidgets('recent automatic node stays automatic after restart',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState.empty().copyWith(
        recentNodeCodes: <String>['nl-ams-01'],
        preferredNodeCode: '',
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'automatic-restart',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');

    final autoLocation = find.byKey(
      const ValueKey('locations-auto-section'),
    );
    expect(
      find.descendant(of: autoLocation, matching: find.text('Вручную')),
      findsNothing,
    );
    expect(store.state.preferredNodeCode, isEmpty);

    await _tapNav(tester, 'nav-protection');
    await _tapPrimaryConnectAndConfirmRouteScope(tester);

    expect(bootstrapper.lastPreferredNodeCode, isEmpty);
  });

  testWidgets(
      'automatic Smart Connect stickiness never becomes a manual preference',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();
    const smartConnect = SmartConnectProfile(
      eligible: true,
      fallbackRequired: false,
      shortlistReason: 'eligible',
      shortlistLimit: 1,
      shortlistRevision: 'auto-stickiness',
      transportProfile: 'reality',
      profileRevision: 'auto-profile',
      fallbackOrder: <String>['free'],
      shortlist: <SmartConnectNode>[
        SmartConnectNode(
          code: 'free',
          country: 'Russia',
          rank: 1,
          rankHint: SmartConnectRankHint(
            healthScore: 96,
            cpuPercent: 8,
            panelLatencyMs: 24,
            backendPenalty: 0,
            cpuPenalty: 0,
            stickyPreferred: true,
          ),
        ),
      ],
      stickiness: SmartConnectStickiness(
        preferredNodeCode: 'free',
        thresholdPercent: 15,
        latestSampleAt: '',
        stickinessApplied: true,
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'automatic-stickiness',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        smartConnect: smartConnect,
        resolvedNodeCode: 'free',
      ),
    );
    final store = _FakeClientExperienceStore();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    expect(bootstrapper.lastPreferredNodeCode, isEmpty);
    expect(store.state.preferredNodeCode, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-location-chip')),
        matching: find.text('Россия'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();

    expect(bootstrapper.calls, greaterThanOrEqualTo(2));
    expect(bootstrapper.lastPreferredNodeCode, isEmpty);
    expect(store.state.preferredNodeCode, isEmpty);
  });

  testWidgets('locations screen renders backend catalog cities',
      (tester) async {
    final semantics = tester.ensureSemantics();
    _expectFeatureLabelHelpersCovered(const [
      '_smartConnectNodeTitle',
      '_smartConnectNodeCity',
      '_smartConnectQualityLabel',
      '_locationQualityLabel',
    ]);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();

    final freshMeasurement = DateTime.now().toUtc().toIso8601String();
    final futureMeasurement = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: ClientLocationsCatalog(
        auto: const ClientLocationAuto(
          enabled: true,
          currentCode: 'nl-ams-01',
        ),
        countries: <ClientLocationCountry>[
          ClientLocationCountry(
            code: 'nl',
            country: 'Netherlands',
            cities: <ClientLocationCity>[
              ClientLocationCity(
                code: 'nl-ams-01',
                city: 'Amsterdam',
                healthScore: 0.94,
                latencyMs: 38,
                premium: true,
                load: 0.31,
                measuredAt: freshMeasurement,
              ),
              ClientLocationCity(
                code: 'nl-ams-slow',
                city: 'Amsterdam slow',
                healthScore: 0.94,
                latencyMs: 1700,
                premium: true,
                load: 0.31,
                measuredAt: freshMeasurement,
              ),
              const ClientLocationCity(
                code: 'nl-ams-stale',
                city: 'Amsterdam stale',
                healthScore: 0.99,
                latencyMs: 12,
                premium: true,
                load: 0.10,
                measuredAt: '2026-07-23T10:15:00+00:00',
              ),
              const ClientLocationCity(
                code: 'nl-ams-invalid-time',
                city: 'Amsterdam invalid time',
                healthScore: 0.99,
                latencyMs: 13,
                premium: false,
                load: 0.11,
                measuredAt: 'not-a-time',
              ),
              ClientLocationCity(
                code: 'nl-ams-future',
                city: 'Amsterdam future',
                healthScore: 0.99,
                latencyMs: 14,
                premium: false,
                load: 0.12,
                measuredAt: futureMeasurement,
              ),
              ClientLocationCity(
                code: 'nl-ams-invalid-score',
                city: 'Amsterdam invalid score',
                healthScore: 150,
                latencyMs: 15,
                premium: false,
                load: 0.13,
                measuredAt: freshMeasurement,
              ),
              ClientLocationCity(
                code: 'nl-ams-missing-score',
                city: 'Amsterdam missing score',
                healthScore: null,
                latencyMs: 16,
                premium: false,
                load: 0.14,
                measuredAt: freshMeasurement,
              ),
            ],
          ),
        ],
        freePoolCode: 'nl-free',
        profileRevision: 'rev-locations',
        transportProfile: 'reality',
        query: '',
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        nodeLatencyProbe: (_, __) async => const <String, int>{
          'nl-ams-01': 38,
          'nl-ams-slow': 1700,
        },
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();

    expect(bootstrapper.locationsCatalogCalls, greaterThanOrEqualTo(1));
    final callsBeforeRefresh = bootstrapper.locationsCatalogCalls;
    expect(
      find.byKey(const ValueKey('locations-refresh-measurements')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('locations-refresh-measurements')),
    );
    await tester.pumpAndSettle();
    expect(bootstrapper.locationsCatalogCalls, greaterThan(callsBeforeRefresh));
    expect(
      find.byKey(const ValueKey('locations-catalog-city-nl-ams-01')),
      findsOneWidget,
    );
    final favoriteTarget = tester.getSize(
      find.byKey(const ValueKey('locations-favorite-nl-ams-01')),
    );
    expect(favoriteTarget.width, greaterThanOrEqualTo(48));
    expect(favoriteTarget.height, greaterThanOrEqualTo(48));
    expect(find.text('Амстердам'), findsWidgets);
    expect(find.textContaining('38 мс'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('locations-catalog-city-nl-ams-01')),
        matching: find.textContaining('31%'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('locations-catalog-city-nl-ams-01')),
        matching: find.text('Нидерланды · Отлично'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('locations-catalog-city-nl-ams-slow')),
        matching: find.text('Нидерланды · Медленно'),
      ),
      findsOneWidget,
    );
    final staleRow =
        find.byKey(const ValueKey('locations-catalog-city-nl-ams-stale'));
    await tester.ensureVisible(staleRow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: staleRow,
        matching: find.textContaining('устарел'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: staleRow, matching: find.textContaining('— мс')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: staleRow,
        matching: find.textContaining('10%'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: staleRow, matching: find.textContaining('Отлично')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('locations-signal-nl-ams-stale')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('location-flag-NL')),
      findsWidgets,
    );

    for (final code in const ['nl-ams-invalid-time', 'nl-ams-future']) {
      final row = find.byKey(ValueKey('locations-catalog-city-$code'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row, matching: find.textContaining('Отлично')),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('— мс')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('%')),
        findsOneWidget,
      );
    }

    for (final code in const [
      'nl-ams-invalid-score',
      'nl-ams-missing-score',
    ]) {
      final invalidScoreRow =
          find.byKey(ValueKey('locations-catalog-city-$code'));
      await tester.ensureVisible(invalidScoreRow);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: invalidScoreRow,
          matching: find.text('Нидерланды · Базовый'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('locations-signal-$code')),
        findsNothing,
      );
    }
    expect(find.text('Premium'), findsNothing);
    expect(find.text('Free'), findsNothing);
    semantics.dispose();
  });

  testWidgets('manual city scrolls every variant into the safe sheet viewport',
      (tester) async {
    // Reproduces the 408 logical-pixel Huawei width and the compact sheet body
    // left above EMUI's bottom system area.
    await tester.binding.setSurfaceSize(const Size(408, 350));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();
    const catalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'de-fra'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'de',
          country: 'Germany',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'de-fra',
              city: 'Frankfurt',
              healthScore: 0.95,
              latencyMs: 31,
              premium: true,
              load: 0.24,
              variants: <ClientLocationVariant>[
                ClientLocationVariant(
                  id: 'direct',
                  label: 'Обычный',
                  description: 'Прямое подключение',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini',
                  label: 'Белые списки',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini-2',
                  label: 'Белые списки тип 2',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini-3',
                  label: 'Белые списки тип 3',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
              ],
            ),
          ],
        ),
      ],
      freePoolCode: '',
      profileRevision: 'variant-rev',
      transportProfile: 'ru_bridge_relay',
      query: '',
    );
    final store = _FakeClientExperienceStore();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'variant-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: catalog,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();

    final cityRow = find.byKey(const ValueKey('locations-catalog-city-de-fra'));
    final locationsList = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    expect(locationsList, findsOneWidget);
    await tester.scrollUntilVisible(
      cityRow,
      120,
      scrollable: locationsList,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: cityRow,
        matching: find.textContaining('Обычный / Белые списки +2'),
      ),
      findsOneWidget,
    );
    final cityPressSurface = find.ancestor(
      of: cityRow,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == 'PokrovSettingsRowPressSurface',
      ),
    );
    expect(cityPressSurface, findsOneWidget);
    final dynamic cityPressSurfaceWidget = tester.widget(cityPressSurface);
    cityPressSurfaceWidget.onTap();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('location-variant-sheet-title')),
      findsOneWidget,
    );
    expect(find.text('Обычный'), findsOneWidget);
    expect(find.text('Белые списки'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('location-variant-sheet-scroll')),
      findsOneWidget,
    );

    final sheetScroll =
        find.byKey(const ValueKey('location-variant-sheet-scroll'));
    final finalVariant = find.byKey(const ValueKey('location-variant-mini-3'));
    final initialTop = tester.getTopLeft(finalVariant).dy;
    await tester.drag(sheetScroll, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.drag(sheetScroll, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(finalVariant).dy, lessThan(initialTop));
    expect(tester.getBottomRight(finalVariant).dy, lessThanOrEqualTo(350));

    await tester.tap(finalVariant);
    await tester.pumpAndSettle();
    expect(bootstrapper.lastPreferredNodeCode, 'de-fra');
    expect(bootstrapper.lastPreferredVariantId, 'mini-3');
    expect(store.state.preferredVariantId, 'mini-3');
  });

  testWidgets('catalog refresh resets a removed preferred variant to direct',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    const catalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'de-fra'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'de',
          country: 'Germany',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'de-fra',
              city: 'Frankfurt',
              healthScore: 0.95,
              latencyMs: 31,
              premium: true,
              load: 0.24,
              variants: <ClientLocationVariant>[
                ClientLocationVariant(
                  id: 'direct',
                  label: 'Обычный',
                  description: 'Прямое подключение',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini',
                  label: 'Белые списки',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
              ],
            ),
          ],
        ),
      ],
      freePoolCode: '',
      profileRevision: 'variant-removed-rev',
      transportProfile: 'ru_bridge_relay',
      query: '',
    );
    final store = _FakeClientExperienceStore(
      PokrovClientExperienceState.fromJson(<String, dynamic>{
        'preferredNodeCode': 'de-fra',
        'preferredVariantId': 'mini-3',
        'firstRouteScopeConfirmed': true,
        'firstRouteScopeMode': 'fullTunnel',
      }),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'removed-variant-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: catalog,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();

    expect(store.state.preferredNodeCode, 'de-fra');
    expect(store.state.preferredVariantId, 'direct');
    final subtitle = find.byKey(
      const ValueKey('locations-catalog-subtitle-de-fra'),
    );
    expect(tester.widget<Text>(subtitle).data, contains('Обычный'));

    await _tapNav(tester, 'nav-protection');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(bootstrapper.lastPreferredNodeCode, 'de-fra');
    expect(bootstrapper.lastPreferredVariantId, 'direct');
  });

  testWidgets(
      'selected city shows active, available and unavailable variant status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(408, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final observedAt = DateTime.now().millisecondsSinceEpoch;
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      variantProbeSnapshot: <String, Object?>{
        'observedAtMs': observedAt,
        'activeVariantId': 'mini',
        'results': <Object?>[
          <String, Object?>{
            'id': 'direct',
            'status': 'unavailable',
            'errorCategory': 'url_test_failed',
          },
          <String, Object?>{
            'id': 'mini',
            'status': 'available',
            'latencyMs': 74,
            'measuredAtMs': observedAt,
            'errorCategory': '',
          },
        ],
        'errorCategory': '',
      },
    );
    const catalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'de-fra'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'de',
          country: 'Germany',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'de-fra',
              city: 'Frankfurt',
              healthScore: 0.95,
              latencyMs: 31,
              premium: true,
              load: 0.24,
              variants: <ClientLocationVariant>[
                ClientLocationVariant(
                  id: 'direct',
                  label: 'Обычный',
                  description: 'Прямое подключение',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini',
                  label: 'Белые списки',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
                ClientLocationVariant(
                  id: 'mini-2',
                  label: 'Белые списки тип 2',
                  description: 'Для ограниченных сетей',
                  available: true,
                ),
              ],
            ),
          ],
        ),
      ],
      freePoolCode: '',
      profileRevision: 'variant-status-rev',
      transportProfile: 'ru_bridge_relay',
      query: '',
    );
    final store = _FakeClientExperienceStore(
      PokrovClientExperienceState.fromJson(<String, dynamic>{
        'preferredNodeCode': 'de-fra',
        'preferredVariantId': 'mini',
      }),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'variant-status-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: catalog,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();
    final cityRow = find.byKey(
      const ValueKey('locations-catalog-city-de-fra'),
    );
    await tester.ensureVisible(cityRow);
    final cityPressSurface = find.ancestor(
      of: cityRow,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == 'PokrovSettingsRowPressSurface',
      ),
    );
    final dynamic cityPressSurfaceWidget = tester.widget(cityPressSurface);
    cityPressSurfaceWidget.onTap();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('location-variant-refresh')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('location-variant-status-mini')),
      findsOneWidget,
    );
    expect(find.text('74 мс'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('location-variant-active-mini')),
      findsOneWidget,
    );
    expect(find.text('Сейчас работает'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('location-variant-freshness-mini')),
      findsOneWidget,
    );
    expect(find.text('сейчас'), findsWidgets);
    expect(
      find.byKey(const ValueKey('location-variant-status-direct')),
      findsOneWidget,
    );
    expect(find.text('Недоступно'), findsNWidgets(2));

    final retryMini = find.byKey(
      const ValueKey('location-variant-refresh-mini'),
    );
    await tester.ensureVisible(retryMini);
    await tester.tap(retryMini);
    await tester.pumpAndSettle();
    expect(
      runtimeCalls
          .where((call) => call == 'runtimeEngine.measureLocationVariants'),
      hasLength(2),
    );
  });

  testWidgets('location refresh spinner stays out of the Auto card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final refreshGate = Completer<void>();
    addTearDown(() {
      if (!refreshGate.isCompleted) {
        refreshGate.complete();
      }
    });
    const catalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'de-fra'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'de',
          country: 'Germany',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'de-fra',
              city: 'Frankfurt',
              healthScore: 0.95,
              latencyMs: 31,
              premium: true,
              load: 0.24,
            ),
          ],
        ),
      ],
      freePoolCode: '',
      profileRevision: 'cached-rev',
      transportProfile: 'reality',
      query: '',
    );
    final store = _FakeClientExperienceStore(
      PokrovClientExperienceState.fromJson(<String, dynamic>{
        'cachedLocations': catalog.toJson(),
        'locationsCachedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'refresh-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: catalog,
      locationsCatalogGate: refreshGate.future,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-locations')));
    await tester.pump(const Duration(milliseconds: 500));

    final autoCard = find.byKey(const ValueKey('locations-auto-section'));
    final refreshButton =
        find.byKey(const ValueKey('locations-refresh-measurements'));
    expect(
      find.descendant(
        of: autoCard,
        matching: find.byType(CupertinoActivityIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: refreshButton,
        matching: find.byType(CupertinoActivityIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('Автоматически'), findsOneWidget);
    refreshGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('WARP with a white-list variant fails before runtime staging',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(calls: runtimeCalls);
    final store = _FakeClientExperienceStore(
      PokrovClientExperienceState.fromJson(<String, dynamic>{
        'preferredNodeCode': 'de-fra',
        'preferredVariantId': 'mini',
        'firstRouteScopeConfirmed': true,
        'firstRouteScopeMode': 'fullTunnel',
      }),
    );
    const warpPolicy = WarpRuntimePolicy(
      enabled: true,
      runtimeReady: true,
      state: 'active',
      mode: 'warp_over_proxy',
      source: 'client_local',
      userConsented: true,
      id: 'p1',
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'blocked-warp-variant',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: warpPolicy,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('WARP пока нельзя использовать'),
      findsWidgets,
    );
    expect(runtimeCalls, isNot(contains('runtimeEngine.stageManagedProfile')));
    expect(runtimeCalls, isNot(contains('runtimeEngine.connect')));
  });

  testWidgets('locations stay readable at 200 percent on narrow Android',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );
    _installReadyRuntimeBridgeMock();

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'narrow-locations',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: const ClientLocationsCatalog(
        auto: ClientLocationAuto(enabled: true, currentCode: 'de-fra-01'),
        countries: <ClientLocationCountry>[
          ClientLocationCountry(
            code: 'de',
            country: 'Germany',
            cities: <ClientLocationCity>[
              ClientLocationCity(
                code: 'de-fra-01',
                city: 'Frankfurt',
                healthScore: 0.95,
                latencyMs: 31,
                premium: true,
                load: 0.24,
                measuredAt: '2026-08-11T12:00:00Z',
              ),
            ],
          ),
        ],
        freePoolCode: '',
        profileRevision: 'rev-narrow-locations',
        transportProfile: 'reality',
        query: '',
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'initial home layout');
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'route scope sheet layout');
    await _confirmFirstRouteScopeIfPresent(tester);
    expect(tester.takeException(), isNull, reason: 'connected home layout');
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'locations layout');

    final automaticTitle = find.text('Автоматически');
    expect(automaticTitle, findsOneWidget);
    expect(tester.getSize(automaticTitle).width, greaterThan(120));
    expect(
      find.byKey(const ValueKey('locations-refresh-measurements')),
      findsOneWidget,
    );

    final city = find.byKey(
      const ValueKey('locations-catalog-city-de-fra-01'),
    );
    await tester.scrollUntilVisible(
      city,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(city, findsOneWidget);
    expect(
      tester
          .getSize(
            find.descendant(of: city, matching: find.text('Франкфурт')),
          )
          .width,
      greaterThan(100),
    );
    final subtitle = tester.widget<Text>(
      find.byKey(
        const ValueKey('locations-catalog-subtitle-de-fra-01'),
      ),
    );
    final metrics = tester.widget<Text>(
      find.byKey(
        const ValueKey('locations-catalog-metrics-de-fra-01'),
      ),
    );
    expect(subtitle.maxLines, 2);
    expect(metrics.maxLines, 2);
    expect(tester.takeException(), isNull, reason: 'scrolled locations layout');
  });

  testWidgets(
      'cached catalog allows recovery selection before Smart Connect resolves',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();

    const cachedCatalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'nl-ams-01'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'nl',
          country: 'Netherlands',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'nl-ams-01',
              city: 'Amsterdam',
              healthScore: 0.94,
              latencyMs: 38,
              premium: false,
              load: 0.31,
              measuredAt: '2026-07-23T10:15:00Z',
            ),
          ],
        ),
      ],
      freePoolCode: 'nl-free',
      profileRevision: 'rev-locations',
      transportProfile: 'reality',
      query: '',
    );
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState(
        favoriteNodeCodes: <String>[],
        recentNodeCodes: <String>[],
        protectionEvents: <PokrovProtectionEvent>[],
        postConnectShortcuts: <PokrovPostConnectShortcut>[],
        cachedLocations: cachedCatalog,
        locationsCachedAt: '2026-07-23T10:15:01Z',
        cachedNotifications: null,
        notificationsCachedAt: '',
      ),
    );
    const staleServerSmartConnect = SmartConnectProfile(
      eligible: true,
      fallbackRequired: false,
      shortlistReason: 'eligible',
      shortlistLimit: 5,
      shortlistRevision: 'short-stale',
      transportProfile: 'reality',
      profileRevision: 'rev-locations',
      fallbackOrder: <String>['ru-spb'],
      shortlist: <SmartConnectNode>[],
      stickiness: SmartConnectStickiness(
        preferredNodeCode: 'ru-spb',
        thresholdPercent: 15,
        latestSampleAt: '',
        stickinessApplied: true,
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-without-smart-connect',
        configPayload: '{}',
        materializedForRuntime: true,
        smartConnect: staleServerSmartConnect,
      ),
      locationsCatalogFailure: 'offline',
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapNav(tester, 'nav-locations');

    final city = find.byKey(const ValueKey('locations-catalog-city-nl-ams-01'));
    expect(city, findsOneWidget);
    expect(
      find.byKey(const ValueKey('locations-selection-locked')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('locations-selection-locked-nl-ams-01'),
      ),
      findsNothing,
    );
    await tester.tap(city, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(store.state.recentNodeCodes, <String>['nl-ams-01']);
    expect(store.state.preferredNodeCode, 'nl-ams-01');
    expect(
      find.text('Локация сохранена. Подключите POKROV.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('locations-favorite-nl-ams-01')),
    );
    await tester.pumpAndSettle();
    expect(store.state.favoriteNodeCodes, <String>['nl-ams-01']);
    expect(store.state.recentNodeCodes, <String>['nl-ams-01']);

    await _tapNav(tester, 'nav-protection');
    expect(find.text('Амстердам'), findsOneWidget);
    expect(
      find.text('Локация сохранена. Подключите POKROV, чтобы применить.'),
      findsOneWidget,
    );

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    expect(bootstrapper.lastPreferredNodeCode, 'nl-ams-01');
    expect(store.state.preferredNodeCode, 'nl-ams-01');
    expect(find.text('Амстердам'), findsOneWidget);
  });

  testWidgets(
      'manual location restarts the active tunnel and promotes the fresh profile',
      (tester) async {
    final semantics = tester.ensureSemantics();
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final runtimeCalls = <String>[];
    var phase = 'artifactReady';
    var reusableProfile = false;

    Map<String, Object?> snapshot({String message = 'Runtime ready.'}) {
      return <String, Object?>{
        'phase': phase,
        'artifactDirectory': '/host/runtime',
        'coreBinaryPath': '/host/runtime/pokrov-core.aar',
        if (reusableProfile && (phase == 'configStaged' || phase == 'running'))
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
        'supportsLiveConnect': true,
        'canInitialize': true,
        'canConnect': phase != 'artifactReady',
        'message': message,
        'hostHealth': phase == 'running' ? 'healthy' : 'unknown',
        'dnsState': phase == 'running' ? 'healthy' : 'unknown',
        'uplinkState': phase == 'running' ? 'healthy' : 'unknown',
        'core_egress_validated': phase == 'running',
      };
    }

    messenger.setMockMethodCallHandler(channel, (call) async {
      runtimeCalls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return snapshot();
        case 'runtimeEngine.initialize':
          phase = 'initialized';
          return snapshot(message: 'Runtime initialized.');
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
          reusableProfile = true;
          return snapshot(message: 'Managed profile staged.');
        case 'runtimeEngine.invalidateManagedProfile':
          reusableProfile = false;
          return snapshot(message: 'Reusable profile invalidated.');
        case 'runtimeEngine.disconnect':
          phase = 'initialized';
          return snapshot(message: 'Runtime service stopped.');
        case 'runtimeEngine.connect':
          phase = 'running';
          return snapshot(message: 'Runtime service is running.');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const catalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'ru-spb'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'ru',
          country: 'Russia',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'ru-spb',
              city: 'Санкт-Петербург',
              healthScore: 0.94,
              latencyMs: 38,
              premium: true,
              load: 0.31,
              measuredAt: '2026-07-23T10:15:00Z',
            ),
          ],
        ),
        ClientLocationCountry(
          code: 'de',
          country: 'Germany',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'de-fra',
              city: 'Frankfurt',
              healthScore: 0.94,
              latencyMs: 42,
              premium: true,
              load: 0.31,
              measuredAt: '2026-07-23T10:15:00Z',
            ),
          ],
        ),
      ],
      freePoolCode: 'nl-free',
      profileRevision: 'rev-locations',
      transportProfile: 'reality',
      query: '',
    );
    const smartConnect = SmartConnectProfile(
      eligible: true,
      fallbackRequired: false,
      shortlistReason: 'eligible',
      shortlistLimit: 5,
      shortlistRevision: 'short-locations',
      transportProfile: 'reality',
      profileRevision: 'rev-locations',
      fallbackOrder: <String>['ru-spb', 'de-fra'],
      shortlist: <SmartConnectNode>[
        SmartConnectNode(
          code: 'ru-spb',
          country: 'Russia',
          rank: 1,
          rankHint: SmartConnectRankHint(
            healthScore: 94,
            cpuPercent: 10,
            panelLatencyMs: 38,
            backendPenalty: 0,
            cpuPenalty: 0,
            stickyPreferred: true,
          ),
        ),
        SmartConnectNode(
          code: 'de-fra',
          country: 'Germany',
          rank: 2,
          rankHint: SmartConnectRankHint(
            healthScore: 94,
            cpuPercent: 10,
            panelLatencyMs: 42,
            backendPenalty: 0,
            cpuPenalty: 0,
            stickyPreferred: false,
          ),
        ),
      ],
      stickiness: SmartConnectStickiness(
        preferredNodeCode: 'ru-spb',
        thresholdPercent: 15,
        latestSampleAt: '',
        stickinessApplied: true,
      ),
    );
    final nodePreferenceGate = Completer<void>();
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-locations',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        smartConnect: smartConnect,
        resolvedNodeCode: 'ru-spb',
      ),
      locationsCatalog: catalog,
      nodePreferenceGate: nodePreferenceGate.future,
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();
    final initialLocationSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('locations-semantics-ru-spb')),
    );
    expect(initialLocationSemantics.properties.selected, isFalse);
    expect(initialLocationSemantics.properties.value, 'Не выбрано');
    await _tapNav(tester, 'nav-protection');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-location-chip')),
        matching: find.text('Санкт-Петербург'),
      ),
      findsOneWidget,
    );
    runtimeCalls.clear();
    await _tapNav(tester, 'nav-locations');
    final frankfurt =
        find.byKey(const ValueKey('locations-catalog-city-de-fra'));
    await tester.ensureVisible(frankfurt);
    await tester.tap(frankfurt, warnIfMissed: false);
    await tester.pump();
    nodePreferenceGate.complete();
    await tester.pumpAndSettle();
    expect(
      runtimeCalls,
      containsAllInOrder(const <String>[
        'runtimeEngine.invalidateManagedProfile',
        'runtimeEngine.disconnect',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );

    await _tapNav(tester, 'nav-protection');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-location-chip')),
        matching: find.text('Франкфурт'),
      ),
      findsOneWidget,
    );
    expect(find.text('Подключено'), findsOneWidget);
    expect(
      find.text('Локация применена.'),
      findsOneWidget,
    );

    await _tapNav(tester, 'nav-locations');
    final preferredLocationSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('locations-semantics-de-fra')),
    );
    expect(preferredLocationSemantics.properties.selected, isTrue);
    expect(preferredLocationSemantics.properties.value, 'Выбрано');
    final autoLocation = find.byKey(const ValueKey('locations-auto-section'));
    expect(
      find.descendant(of: autoLocation, matching: find.text('Вручную')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: autoLocation,
        matching: find.byIcon(Icons.location_on_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: autoLocation,
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('locations-catalog-city-de-fra')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    // A later delayed failure must leave the last confirmed preference intact.
    final failedPreferenceGate = Completer<void>();
    bootstrapper.nodePreferenceGate = failedPreferenceGate.future;
    bootstrapper.nodePreferenceFailure =
        const BootstrapFailure('Локация временно недоступна.');
    final saintPetersburg =
        find.byKey(const ValueKey('locations-catalog-city-ru-spb'));
    await tester.ensureVisible(saintPetersburg);
    await tester.tap(saintPetersburg, warnIfMissed: false);
    await tester.pump();
    failedPreferenceGate.complete();
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-protection');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-location-chip')),
        matching: find.text('Франкфурт'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('locations keep cached catalog favorites and recents offline',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();

    const cachedCatalog = ClientLocationsCatalog(
      auto: ClientLocationAuto(enabled: true, currentCode: 'nl-ams-01'),
      countries: <ClientLocationCountry>[
        ClientLocationCountry(
          code: 'nl',
          country: 'Netherlands',
          cities: <ClientLocationCity>[
            ClientLocationCity(
              code: 'nl-ams-01',
              city: 'Amsterdam',
              healthScore: 0.94,
              latencyMs: 38,
              premium: true,
              load: 0.31,
              measuredAt: '2026-07-23T10:15:00Z',
            ),
          ],
        ),
      ],
      freePoolCode: 'nl-free',
      profileRevision: 'rev-locations',
      transportProfile: 'reality',
      query: '',
    );
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState(
        favoriteNodeCodes: <String>['nl-ams-01'],
        recentNodeCodes: <String>[],
        protectionEvents: <PokrovProtectionEvent>[],
        postConnectShortcuts: <PokrovPostConnectShortcut>[],
        cachedLocations: cachedCatalog,
        locationsCachedAt: '2026-07-23T10:15:01Z',
        cachedNotifications: null,
        notificationsCachedAt: '',
      ),
    );
    const smartConnect = SmartConnectProfile(
      eligible: true,
      fallbackRequired: false,
      shortlistReason: 'eligible',
      shortlistLimit: 5,
      shortlistRevision: 'short-test',
      transportProfile: 'reality',
      profileRevision: 'rev-locations',
      fallbackOrder: <String>['nl-ams-01'],
      shortlist: <SmartConnectNode>[],
      stickiness: SmartConnectStickiness(
        preferredNodeCode: '',
        thresholdPercent: 15,
        latestSampleAt: '',
        stickinessApplied: false,
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
        smartConnect: smartConnect,
      ),
      locationsCatalogFailure: 'offline',
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);
    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');

    expect(find.text('Амстердам'), findsOneWidget);
    expect(find.text('Избранное'), findsOneWidget);
    expect(find.text('Нет свежих данных'), findsOneWidget);
    expect(
        find.textContaining('Показываем сохранённый список'), findsOneWidget);

    final favoriteAction =
        find.byKey(const ValueKey('locations-favorite-nl-ams-01'));
    await tester.tap(favoriteAction);
    await tester.pumpAndSettle();
    expect(store.state.favoriteNodeCodes, isEmpty);

    final cachedCity = find.byKey(
      const ValueKey('locations-catalog-city-nl-ams-01'),
      skipOffstage: false,
    );
    await tester.ensureVisible(cachedCity);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('locations-semantics-nl-ams-01')),
    );
    await tester.pumpAndSettle();
    expect(store.state.recentNodeCodes, <String>['nl-ams-01']);
    expect(store.writeCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('home bell opens cached notifications when refresh is offline',
      (tester) async {
    final store = _FakeClientExperienceStore(
      const PokrovClientExperienceState(
        favoriteNodeCodes: <String>[],
        recentNodeCodes: <String>[],
        protectionEvents: <PokrovProtectionEvent>[],
        postConnectShortcuts: <PokrovPostConnectShortcut>[],
        cachedLocations: null,
        locationsCachedAt: '',
        cachedNotifications: ClientNotificationInbox(
          items: <ClientNotificationItem>[
            ClientNotificationItem(
              id: 'incident.cached',
              kind: 'incident',
              title: 'Сохранённый инцидент',
              body: 'Последняя подтверждённая сводка.',
              createdAt: '2026-07-23T10:15:00Z',
              ctaLabel: '',
              ctaHref: null,
              read: false,
            ),
          ],
          nextCursor: '',
          unreadCount: 1,
        ),
        notificationsCachedAt: '2026-07-23T10:15:01Z',
      ),
    );
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload: '{}',
        materializedForRuntime: true,
      ),
      notificationsFailure: 'offline',
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final action = find.byKey(const ValueKey('home-notifications-action'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Сохранённый инцидент'), findsOneWidget);
    expect(
      find.textContaining('Показываем сохранённые уведомления'),
      findsOneWidget,
    );
    expect(bootstrapper.markedNotificationIds, <String>['incident.cached']);
  });

  testWidgets('primary connect action auto-prepares and starts host runtime',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    final stagedPayloads = <String>[];
    var connected = false;
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
      ),
    );

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          if (connected) {
            return <String, Object?>{
              'phase': 'running',
              'artifactDirectory': '/host/runtime',
              'coreBinaryPath': '/host/runtime/pokrov-core.aar',
              'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
              'supportsLiveConnect': true,
              'canInitialize': true,
              'canConnect': true,
              'core_egress_validated': true,
              'message': 'Android runtime service is running.',
            };
          }
          return <String, Object?>{
            'phase': 'artifactReady',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          stagedPayloads.add(arguments['configPayload'].toString());
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.connect':
          connected = true;
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'core_egress_validated': true,
            'message': 'Android runtime service is running.',
          };
        case 'runtimeEngine.disconnect':
          connected = false;
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Runtime service stopped.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-connect-route-scope-sheet')),
      findsOneWidget,
    );
    expect(calls, isNot(contains('runtimeEngine.connect')));
    expect(bootstrapper.calls, 0);
    await _confirmFirstRouteScopeIfPresent(tester);

    expect(find.byKey(const ValueKey('connect-disc-connected-settle')),
        findsOneWidget);
    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.initialize',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
    expect(bootstrapper.calls, 1);
    expect(bootstrapper.lastHostPlatform, HostPlatform.android);
    expect(bootstrapper.lastRouteMode, RouteMode.allExceptRu);
    expect(stagedPayloads.single, contains('"proxy"'));
    expect(stagedPayloads.single, isNot(contains('"final":"direct"')));

    await tester.tap(connectAction);
    await tester.pumpAndSettle();
    await tester.tap(connectAction);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('first-connect-route-scope-sheet')),
      findsNothing,
    );
  });

  testWidgets('long connect exposes the current stage and details after 10s',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final connectResult = Completer<Object?>();
    var connectCalls = 0;
    const staged = <String, Object?>{
      'phase': 'configStaged',
      'artifactDirectory': '/host/runtime',
      'coreBinaryPath': '/host/runtime/pokrov-core.aar',
      'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
      'supportsLiveConnect': true,
      'canInitialize': true,
      'canConnect': true,
      'message': 'Managed profile staged.',
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return staged;
        case 'runtimeEngine.stageManagedProfile':
          return staged;
        case 'runtimeEngine.connect':
          connectCalls += 1;
          return connectResult.future;
      }
      return null;
    });
    addTearDown(() {
      if (!connectResult.isCompleted) {
        connectResult.complete(staged);
      }
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'slow-connect',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    final scope =
        find.byKey(const ValueKey('first-connect-scope-whole-device'));
    await tester.tap(scope);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(connectCalls, 1);
    expect(
      find.byKey(const ValueKey('home-slow-connection-notice')),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 10));

    expect(
      find.byKey(const ValueKey('home-slow-connection-notice')),
      findsOneWidget,
    );
    expect(find.text('Подключение занимает больше времени'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-slow-connection-details')),
      findsOneWidget,
    );

    connectResult.complete(<String, Object?>{
      ...staged,
      'phase': 'running',
      'core_egress_validated': true,
      'hostHealth': 'healthy',
      'dnsState': 'healthy',
      'uplinkState': 'healthy',
      'message': 'Runtime service is running.',
    });
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-slow-connection-notice')),
      findsNothing,
    );
  });

  testWidgets('first route scope blocks an empty selected-apps list',
      (tester) async {
    final calls = <String>[];
    _installReadyRuntimeBridgeMock(calls: calls);
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-selected-apps',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('runtimeEngine.connect')));
    await _confirmFirstRouteScopeIfPresent(
      tester,
      mode: RouteMode.selectedApps,
    );

    expect(bootstrapper.lastRouteMode, isNull);
    expect(bootstrapper.calls, 0);
    expect(calls, isNot(contains('runtimeEngine.connect')));
  });

  testWidgets(
      'late client-experience restore cannot replace first-connect route choice',
      (tester) async {
    final calls = <String>[];
    _installReadyRuntimeBridgeMock(calls: calls);
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-race-safe-route',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    final store = _DelayedClientExperienceStore(
      const PokrovClientExperienceState.empty().copyWith(
        firstRouteScopeConfirmed: true,
        firstRouteScopeMode: RouteMode.allExceptRu,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('first-connect-route-scope-sheet')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('first-connect-scope-selected-apps')),
    );
    await tester.pump();
    store.releaseStaleRead();
    await tester.pumpAndSettle();

    expect(store.state.firstRouteScopeConfirmed, isTrue);
    expect(store.state.firstRouteScopeMode, RouteMode.selectedApps);
    expect(bootstrapper.lastRouteMode, isNull);
    expect(calls, isNot(contains('runtimeEngine.connect')));
  });

  testWidgets('first route scope confirmation survives a shell restart',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final store = _FakeClientExperienceStore();
    final firstBootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-first-shell',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: firstBootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('first-connect-route-scope-sheet')),
      findsOneWidget,
    );
    await _confirmFirstRouteScopeIfPresent(
      tester,
      mode: RouteMode.selectedApps,
    );
    expect(store.state.firstRouteScopeConfirmed, isTrue);
    expect(store.state.firstRouteScopeMode, RouteMode.selectedApps);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final restartedBootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-restarted-shell',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: restartedBootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-connect-route-scope-sheet')),
      findsNothing,
    );
    expect(restartedBootstrapper.calls, 0);
    expect(restartedBootstrapper.lastRouteMode, isNull);
  });

  testWidgets('primary connect activates once from pointer and keyboard',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    var phase = 'artifactReady';

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': phase,
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            if (phase == 'configStaged' || phase == 'running')
              'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': phase == 'configStaged' || phase == 'running',
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          phase = 'initialized';
          return <String, Object?>{
            'phase': phase,
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          phase = 'configStaged';
          return <String, Object?>{
            'phase': phase,
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.connect':
          phase = 'running';
          return <String, Object?>{
            'phase': phase,
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
          };
        case 'runtimeEngine.disconnect':
          phase = 'initialized';
          return <String, Object?>{
            'phase': phase,
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime service stopped.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final label = find.descendant(
      of: find.byKey(const ValueKey('connect-disc-label')),
      matching: find.text('Подключить'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(label));
    await mouse.down(tester.getCenter(label));
    await mouse.up();
    await tester.pumpAndSettle();
    await _confirmFirstRouteScopeIfPresent(tester);

    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.initialize',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
    expect(
        calls.where((call) => call == 'runtimeEngine.connect'), hasLength(1));

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    final focusable = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: connectAction,
        matching: find.byKey(const ValueKey('primary-connect-focusable')),
      ),
    );
    final focusNode = focusable.focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      calls.where((call) => call == 'runtimeEngine.disconnect'),
      hasLength(1),
    );
  });

  testWidgets('bootstrap failures surface as a calm recovery banner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'artifactReady',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final bootstrapper = _ThrowingBootstrapper(
      'POKROV РЅРµ СЃРјРѕРі СЃРІСЏР·Р°С‚СЊСЃСЏ СЃ СЃРµСЂРІРёСЃРѕРј РїРѕРґРіРѕС‚РѕРІРєРё.',
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.tap(connectAction);
    await tester.pumpAndSettle();
    await _confirmFirstRouteScopeIfPresent(tester);

    expect(
      find.byKey(const ValueKey('connect-disc-error-settle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motion-recovery-banner')),
      findsOneWidget,
    );
    final recoveryBanner = find.byKey(const ValueKey('motion-recovery-banner'));
    expect(
      tester.getRect(recoveryBanner).top,
      greaterThan(
        tester
            .getRect(
              find.byKey(const ValueKey('home-connection-details-action')),
            )
            .bottom,
      ),
    );
    expect(
      tester.getRect(recoveryBanner).bottom,
      lessThan(
          tester.getRect(find.byKey(const ValueKey('home-warp-tile'))).top),
    );
    expect(tester.getRect(recoveryBanner).bottom, lessThanOrEqualTo(844));
    expect(find.textContaining('POKROV'), findsWidgets);

    await tester.tap(connectAction);
    await tester.pumpAndSettle();
    expect(bootstrapper.calls, 2);
  });

  testWidgets('unexpected runtime errors surface as redacted recovery feedback',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'artifactReady',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.connect':
          throw PlatformException(
            code: 'tls://10.24.0.5:443/vless',
            message: 'SocketException: 10.24.0.5:443 protocol vless',
          );
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();

    expect(calls, contains('runtimeEngine.connect'));
    expect(
        find.byKey(const ValueKey('motion-recovery-banner')), findsOneWidget);
    expect(find.textContaining('10.24.0.5'), findsNothing);
    expect(find.textContaining('443'), findsNothing);
    expect(find.textContaining('vless'), findsNothing);
  });

  for (final host in [HostPlatform.android, HostPlatform.windows]) {
  for (final stageResult in ['success', 'timeout', 'rejected']) {
  testWidgets(
      '${host.name} reconnect refreshes the managed profile even when one is already staged ($stageResult)',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    final stagedProfiles = <String>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
      ),
      managedProfileResolver: (call, _) => ManagedProfilePayload(
        profileName: 'managed-revision-$call',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
    );

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/previous-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          stagedProfiles.add((call.arguments as Map)['profileName'] as String);
          if (stagedProfiles.length == 2 && stageResult == 'timeout') {
            return Completer<Map<String, Object?>>().future;
          }
          if (stagedProfiles.length == 2 && stageResult == 'rejected') {
            throw PlatformException(code: 'stage_failed');
          }
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.connect':
          return <String, Object?>{
            'phase': 'running',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service is running.',
          };
        case 'runtimeEngine.disconnect':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Android runtime service stopped.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: host),
        bootstrapper: bootstrapper,
        runtimeActionTimeout: const Duration(milliseconds: 500),
        windowsTunnelAuthorizer: () async => PokrovWindowsTunnelAuthorization.allowed,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pumpAndSettle();
    await _confirmFirstRouteScopeIfPresent(tester);

    expect(bootstrapper.calls, 1);
    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.snapshot',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );

    await tester.tap(connectAction);
    await tester.pumpAndSettle();
    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(bootstrapper.calls, 2);
    expect(stagedProfiles, ['managed-revision-1', 'managed-revision-2']);
    expect(
      calls.where((call) => call == 'runtimeEngine.stageManagedProfile'),
      hasLength(2),
    );
    expect(
      calls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(stageResult == 'success' ? 2 : 1),
    );
  });

  }
  }

  testWidgets(
      'primary connect action is disabled when live connect is unavailable',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        return <String, Object?>{
          'phase': 'artifactMissing',
          'supportsLiveConnect': false,
          'canInitialize': false,
          'canConnect': false,
          'message': 'Host bridge is not ready.',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'unused',
            configPayload: _materializedRuntimeConfig,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Semantics>(connectAction).properties.enabled,
      isFalse,
    );
  });

  testWidgets(
      'first Android consent converges after delayed native running without lifecycle resume',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var snapshotCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          snapshotCalls += 1;
          if (snapshotCalls >= 12) {
            return <String, Object?>{
              'phase': 'running',
              'artifactDirectory': '/host/runtime',
              'coreBinaryPath': '/host/runtime/pokrov-core.aar',
              'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
              'supportsLiveConnect': true,
              'canInitialize': true,
              'canConnect': true,
              'core_egress_validated': true,
              'message': 'Android runtime service is running.',
            };
          }
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'connection_pending': true,
            'message':
                'Android РїСЂРѕСЃРёС‚ СЂР°Р·СЂРµС€РµРЅРёРµ, С‡С‚РѕР±С‹ POKROV РјРѕРі РїРѕРґРєР»СЋС‡РёС‚СЊ СЌС‚Рѕ СѓСЃС‚СЂРѕР№СЃС‚РІРѕ.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.connect':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'connection_pending': true,
            'message':
                'Android РїСЂРѕСЃРёС‚ СЂР°Р·СЂРµС€РµРЅРёРµ, С‡С‚РѕР±С‹ POKROV РјРѕРі РїРѕРґРєР»СЋС‡РёС‚СЊ СЌС‚Рѕ СѓСЃС‚СЂРѕР№СЃС‚РІРѕ.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pump();
    await _confirmFirstRouteScopeIfPresent(tester);
    for (var attempt = 0; attempt < 12; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 450));
    }
    await tester.pumpAndSettle();

    expect(snapshotCalls, greaterThanOrEqualTo(12));
    expect(find.byKey(const ValueKey('connect-disc-connected-settle')),
        findsOneWidget);
  });

  testWidgets(
      'primary connect action polls the host bridge until runtime is running',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var snapshotCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          snapshotCalls += 1;
          if (snapshotCalls >= 3) {
            return <String, Object?>{
              'phase': 'running',
              'artifactDirectory': '/host/runtime',
              'coreBinaryPath': '/host/runtime/pokrov-core.aar',
              'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
              'supportsLiveConnect': true,
              'canInitialize': true,
              'canConnect': true,
              'message': 'Android runtime service is running.',
            };
          }
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'connection_pending': true,
            'message': 'Android runtime start is still settling.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        case 'runtimeEngine.connect':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'connection_pending': true,
            'message': 'Android runtime start is still settling.',
          };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    await tester.tap(connectAction);
    await tester.pump();
    await _confirmFirstRouteScopeIfPresent(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(snapshotCalls, greaterThanOrEqualTo(3));
    expect(
      find.text(
          'Р’СЃРµ РіРѕС‚РѕРІРѕ. РќР°Р¶РјРёС‚Рµ РіР»Р°РІРЅСѓСЋ РєРЅРѕРїРєСѓ, С‡С‚РѕР±С‹ РїРѕРґРєР»СЋС‡РёС‚СЊСЃСЏ.'),
      findsNothing,
    );
  });

  testWidgets('android shell refreshes runtime snapshot when the app resumes',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var snapshotCalls = 0;

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'runtimeEngine.snapshot') {
        snapshotCalls += 1;
        if (snapshotCalls == 1) {
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/pokrov-core.aar',
            'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': true,
            'message': 'Managed profile staged on the host bridge.',
          };
        }
        return <String, Object?>{
          'phase': 'running',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Android runtime service is running.',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('home-status-switcher')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(snapshotCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('tab changes animate through the shared tab transition wrapper',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tab-transition-motion')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lazy-indexed-stack')), findsOneWidget);

    await _tapNav(tester, 'nav-profile');
    expect(
      find.byKey(
        const ValueKey('profile-compact-account-layer'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    await _tapNav(tester, 'nav-protection');
    expect(
      find.byKey(const ValueKey('primary-connect-action')),
      findsOneWidget,
    );
    // Previously opened tabs stay alive behind the transition wrapper.
    expect(
      find.byKey(
        const ValueKey('profile-compact-account-layer'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('profile and rewards hub expose accent pull-to-refresh',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
        warpPolicy: WarpRuntimePolicy.disabled,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-profile');
    // Android follows native Material pull-to-refresh on clamped scroll.
    final profileIndicator = find.byKey(
      const ValueKey('profile-refresh-indicator'),
      skipOffstage: false,
    );
    expect(profileIndicator, findsOneWidget);
    expect(
      find.byType(RefreshIndicator),
      findsOneWidget,
    );

    final summaryCallsBefore = bootstrapper.bonusSummaryCalls;
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();
    expect(bootstrapper.bonusSummaryCalls, greaterThan(summaryCallsBefore));

    await _openRewardsHubFromProfile(tester);
    expect(
      find.byKey(
        const ValueKey('rewards-refresh-indicator'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('home offers whitelist recovery after control-plane failure',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: true,
      ),
      managedProfileFailure: const BootstrapFailure(
        'Сервис временно недоступен.',
        statusCode: 503,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapPrimaryConnectAndConfirmRouteScope(tester);
    await tester.pumpAndSettle();
    final recovery = find.byKey(const ValueKey('home-whitelist-recovery'));
    expect(recovery, findsOneWidget);
    await tester.tap(recovery);
    await tester.pumpAndSettle();

    expect(find.text('Режим белых списков'), findsWidgets);
    expect(find.text('Автоматически · Через POKROV'), findsOneWidget);
  });

  testWidgets(
      'whitelist mode opens ready for restricted networks without extra toggle',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final experienceStore = _FakeClientExperienceStore();
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: false,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: experienceStore,
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    expect(launcher, findsOneWidget);
    expect(find.text('Восстановить связь'), findsOneWidget);
    expect(find.textContaining('Резервный режим'), findsOneWidget);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    expect(find.text('Режим белых списков'), findsWidgets);
    expect(
      find.byKey(const ValueKey('emergency-manual-limited-network')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('emergency-how-it-works')),
      findsOneWidget,
    );
    expect(find.textContaining('каналов сохранено'), findsOneWidget);
    expect(find.text('Маршрут подключения'), findsOneWidget);
    expect(bootstrapper.manualLimitedNetworkCalls, <bool>[true]);
    expect(experienceStore.state.emergencyManualLimitedNetwork, isTrue);
  });

  testWidgets('emergency page explains trial or paid access denial',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: const AppFirstEmergencyCatalogResult(
        catalog: null,
        reason: 'access_denied',
        eligibilitySource: 'access_denied',
        usingCache: false,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    expect(find.text('Пока недоступно'), findsOneWidget);
    expect(
      find.text(
        'Режим белых списков доступен во время пробного периода и с активной подпиской.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('emergency-connect')), findsNothing);
  });

  testWidgets('emergency page never exposes raw transport failures',
      (tester) async {
    _installReadyRuntimeBridgeMock();
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: const AppFirstEmergencyCatalogResult(
        catalog: null,
        reason: '',
        eligibilitySource: '',
        usingCache: false,
      ),
      catalogFailure: const BootstrapFailure(
        'Not Found: upstream raw body',
        statusCode: 404,
        operation: 'fetchEmergencyCatalog',
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    expect(find.text('Экстренная сеть ещё не включена на сервере.'),
        findsOneWidget);
    expect(find.textContaining('upstream raw body'), findsNothing);
    expect(find.text('Not Found'), findsNothing);
  });

  testWidgets('emergency catalogs fit 4 or 20 narrow rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final fixture in const <(String, int)>[
      ('trial_premium', 4),
      ('paid_unlimited', 20),
    ]) {
      _installReadyRuntimeBridgeMock();
      final bootstrapper = _FakeEmergencyBootstrapper(
        catalogResult: AppFirstEmergencyCatalogResult(
          catalog: _emergencyCatalog(
            itemCount: fixture.$2,
            accessState: fixture.$1,
          ),
          reason: '',
          eligibilitySource: 'server_cached_ru',
          usingCache: false,
        ),
      );
      await tester.pumpWidget(
        PokrovSeedApp(
          appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
          bootstrapper: bootstrapper,
          firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        ),
      );
      await tester.pumpAndSettle();

      await _tapNav(tester, 'nav-locations');
      final launcher = find.byKey(
        const ValueKey('emergency-network-launcher'),
      );
      await tester.ensureVisible(launcher);
      await tester.tap(launcher);
      await tester.pumpAndSettle();

      final diagnosticsTile = find.byKey(
        const ValueKey('emergency-diagnostics'),
      );
      await tester.scrollUntilVisible(
        diagnosticsTile,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(diagnosticsTile);
      await tester.pumpAndSettle();
      expect(find.text('Канал 1'), findsOneWidget);
      final lastReserve = find.text('Канал ${fixture.$2}');
      await tester.scrollUntilVisible(
        lastReserve,
        260,
        scrollable: find.byType(Scrollable).last,
      );
      expect(lastReserve, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('emergency disclosure gates profile resolution and connect',
      (tester) async {
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(calls: runtimeCalls);
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: false,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('emergency-connect')));
    await tester.pumpAndSettle();
    expect(find.text('Как работает режим белых списков'), findsOneWidget);
    expect(bootstrapper.emergencyProfileCalls, 0);

    await tester.tap(
      find.byKey(const ValueKey('emergency-disclosure-accept')),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.emergencyProfileCalls, 1);
    expect(
      bootstrapper.lastEmergencyReserveId,
      'emg_000000000000000000000001',
    );
    expect(
      bootstrapper.lastEmergencyChainMode,
      EmergencyChainMode.reserveForeign,
    );
    expect(runtimeCalls, contains('runtimeEngine.stageManagedProfile'));
    expect(runtimeCalls, contains('runtimeEngine.connect'));

    await _tapNav(tester, 'nav-protection');
    expect(
      find.byKey(const ValueKey('home-whitelist-active')),
      findsOneWidget,
    );
    expect(find.text('Через POKROV'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-location-chip')), findsNothing);
    expect(find.byKey(const ValueKey('home-route-chip')), findsNothing);
    expect(find.byKey(const ValueKey('home-warp-tile')), findsNothing);
  });

  testWidgets('emergency connect rotates to the next reserve on Android',
      (tester) async {
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      failFirstConnect: true,
    );
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emergency-connect')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('emergency-disclosure-accept')),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.emergencyProfileCalls, 2);
    expect(
      bootstrapper.lastEmergencyReserveId,
      'emg_000000000000000000000002',
    );
    expect(
      bootstrapper.lastEmergencyChainMode,
      EmergencyChainMode.reserveForeign,
    );
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(2),
    );
    expect(
      runtimeCalls,
      contains('runtimeEngine.disconnect'),
    );
  });

  testWidgets(
      'emergency connect rotates after the full-chain egress probe fails',
      (tester) async {
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      failAfterConnect: true,
    );
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emergency-connect')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('emergency-disclosure-accept')),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.emergencyProfileCalls, 2);
    expect(
      bootstrapper.lastEmergencyReserveId,
      'emg_000000000000000000000001',
    );
    expect(
      bootstrapper.lastEmergencyChainMode,
      EmergencyChainMode.reserveDirect,
    );
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(2),
    );
    expect(runtimeCalls, contains('runtimeEngine.snapshot'));
    expect(runtimeCalls, contains('runtimeEngine.disconnect'));
  });

  testWidgets('manual whitelist route keeps the selected hop chain',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(408, 876));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(calls: runtimeCalls);
    final experienceStore = _FakeClientExperienceStore();
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        clientExperienceStore: experienceStore,
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    final routeTile = find.byKey(const ValueKey('emergency-route-mode'));
    await tester.ensureVisible(routeTile);
    await tester.tap(routeTile);
    await tester.pumpAndSettle();
    final enhanced = find.byKey(
      const ValueKey('emergency-route-reserve_ru_foreign'),
    );
    final emergencyList = find.byType(ListView).last;
    await tester.drag(emergencyList, const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(enhanced);
    await tester.pumpAndSettle();
    expect(find.text('Усиленная цепочка'), findsWidgets);

    final connect = find.byKey(const ValueKey('emergency-connect'));
    await tester.drag(emergencyList, const Offset(0, 520));
    await tester.pumpAndSettle();
    await tester.tap(connect);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('emergency-disclosure-accept')),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.emergencyProfileCalls, 1);
    expect(
      bootstrapper.lastEmergencyChainMode,
      EmergencyChainMode.reserveRuForeign,
    );
    expect(experienceStore.state.emergencyAutomaticRoute, isFalse);
    expect(
      experienceStore.state.emergencyChainMode,
      EmergencyChainMode.reserveRuForeign.wireValue,
    );
    await _tapNav(tester, 'nav-protection');
    expect(find.text('Усиленная цепочка'), findsOneWidget);
  });

  testWidgets('emergency connect reports when every saved reserve is blocked',
      (tester) async {
    final runtimeCalls = <String>[];
    _installReadyRuntimeBridgeMock(
      calls: runtimeCalls,
      failAllEmergencyConnects: true,
    );
    final bootstrapper = _FakeEmergencyBootstrapper(
      catalogResult: AppFirstEmergencyCatalogResult(
        catalog: _emergencyCatalog(),
        reason: '',
        eligibilitySource: 'server_cached_ru',
        usingCache: true,
      ),
    );
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: bootstrapper,
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
      ),
    );
    await tester.pumpAndSettle();

    await _tapNav(tester, 'nav-locations');
    final launcher = find.byKey(
      const ValueKey('emergency-network-launcher'),
    );
    await tester.ensureVisible(launcher);
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emergency-connect')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('emergency-disclosure-accept')),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.emergencyProfileCalls, 4);
    expect(
      runtimeCalls.where((call) => call == 'runtimeEngine.connect'),
      hasLength(4),
    );
    expect(
      bootstrapper.emergencyProfileRequests
          .map((request) => request.$2)
          .toList(growable: false),
      <EmergencyChainMode>[
        ...List<EmergencyChainMode>.filled(
          4,
          EmergencyChainMode.reserveForeign,
        ),
      ],
    );
    expect(find.text('Не удалось подключиться'), findsOneWidget);
    expect(
      find.text(
        'Ни один сохранённый резерв не доступен в этой сети. Попробуйте другую сеть или обновите список позже.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('connection CTA and live status have one semantic source',
      (tester) async {
    final semantics = tester.ensureSemantics();
    _installReadyRuntimeBridgeMock();

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'semantics-profile',
            configPayload: _materializedRuntimeConfig,
            materializedForRuntime: true,
          ),
        ),
        firstLaunchStore: _FakeFirstLaunchStore(completed: true),
        connectHintStore: const _CompletedConnectHintStore(),
      ),
    );
    await tester.pumpAndSettle();

    var action = tester.getSemantics(find.bySemanticsLabel('Подключить'));
    var status = tester.getSemantics(
      find.bySemanticsLabel(
        'Статус защиты: Не защищено. Открыть подробности',
      ),
    );
    expect(action.label, 'Подключить');
    expect(action.flagsCollection.isButton, isTrue);
    expect(status.label, 'Статус защиты: Не защищено. Открыть подробности');
    expect(status.flagsCollection.isLiveRegion, isTrue);
    expect(status.flagsCollection.isButton, isTrue);

    await _tapPrimaryConnectAndConfirmRouteScope(tester);

    action = tester.getSemantics(find.bySemanticsLabel('Отключить'));
    status = tester.getSemantics(
      find.bySemanticsLabel(
        'Статус защиты: Подключено. Открыть подробности',
      ),
    );
    expect(action.label, 'Отключить');
    expect(status.label, 'Статус защиты: Подключено. Открыть подробности');
    expect(status.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('matches deterministic critical-state goldens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    const variants = <({String name, ThemeMode theme, String state})>[
      (name: 'home-idle-light', theme: ThemeMode.light, state: 'idle'),
      (name: 'route-scope-dark', theme: ThemeMode.dark, state: 'scope'),
      (name: 'home-verified-dark', theme: ThemeMode.dark, state: 'verified'),
      (name: 'home-degraded-light', theme: ThemeMode.light, state: 'degraded'),
    ];
    final goldenDirectory = Platform.isLinux ? 'goldens/linux' : 'goldens';

    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    for (final variant in variants) {
      _installReadyRuntimeBridgeMock(
        reportDegradedAfterConnect: variant.state == 'degraded',
      );
      await tester.pumpWidget(
        PokrovSeedApp(
          appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
          bootstrapper: _FakeBootstrapper(
            ManagedProfilePayload(
              profileName: 'golden-${variant.name}',
              configPayload: _materializedRuntimeConfig,
              materializedForRuntime: true,
            ),
          ),
          firstLaunchStore: _FakeFirstLaunchStore(completed: true),
          themeModeStore: _FixedThemeModeStore(variant.theme),
          connectHintStore: const _CompletedConnectHintStore(),
          clientExperienceStore: _FakeClientExperienceStore(),
        ),
      );
      await tester.pumpAndSettle();

      if (variant.state != 'idle') {
        await tester.tap(
          find.byKey(const ValueKey('primary-connect-action')),
        );
        await tester.pumpAndSettle();
        if (variant.state != 'scope') {
          await _confirmFirstRouteScopeIfPresent(tester);
          await tester.pumpAndSettle();
        }
      }

      expect(tester.takeException(), isNull, reason: variant.name);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('$goldenDirectory/${variant.name}.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  test('builds seed app context for public and readiness-only host lanes', () {
    for (final platform in HostPlatform.values) {
      final appContext = buildSeedAppContext(hostPlatform: platform);

      expect(appContext.hostPlatform, platform);
      expect(appContext.bootstrapContract.hostPlatform, platform);
      expect(
        appContext.scope.publicReleaseTargets,
        containsAll(const [
          ClientPlatform.android,
          ClientPlatform.windows,
        ]),
      );
      expect(
        appContext.scope.readinessOnlyTargets,
        containsAll(const [
          ClientPlatform.ios,
          ClientPlatform.macos,
        ]),
      );
      expect(appContext.runtimeProfile.freeTier.enabled, isFalse);
      expect(appContext.runtimeProfile.trialDays, 5);
      expect(appContext.runtimeProfile.telegramBonusDays, 5);
      expect(appContext.runtimeProfile.defaultCore, RuntimeCore.singBox);
      expect(appContext.runtimeProfile.defaultRouteMode, RouteMode.allExceptRu);
      expect(appContext.supportSnapshot.supportBot, '@pokrov_supportbot');
      expect(appContext.supportSnapshot.feedbackBot, '@pokrov_feedbackbot');
      expect(appContext.supportSnapshot.channelBonusDays, 5);
      expect(appContext.runtimeProfile.freeTier.speedMbps, 0);
      expect(appContext.redeemHint, isEmpty);
      expect(appContext.locations, hasLength(1));
    }
  });
}
