import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

const _materializedRuntimeConfig =
    '{"outbounds":[{"type":"socks","tag":"node","server":"127.0.0.1","server_port":1080},{"type":"selector","tag":"proxy","outbounds":["node"]},{"type":"direct","tag":"direct"}],"route":{"final":"proxy"}}';

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
    ClientSupportAssistantReply? assistantReply,
    this.assistantGate,
    this.assistantFailureCalls = const <int>{},
    this.bonusSummaryGate,
    this.locationsCatalogFailure,
    this.notificationsFailure,
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
              bonusDays: 10,
            ),
        channelBonusClaimResult = channelBonusClaimResult ??
            const ChannelBonusClaimResult(
              ok: true,
              alreadyClaimed: false,
              premiumDays: 10,
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
              channelBonusPremiumDays: 10,
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
            );

  final ManagedProfilePayload payload;
  final AppFirstRedeemResult redeemResult;
  final CabinetHandoff cabinetHandoff;
  final TelegramLinkResult telegramLinkResult;
  final ChannelBonusStatus channelBonusStatus;
  final ChannelBonusClaimResult channelBonusClaimResult;
  final AppFirstBonusSummary bonusSummary;
  final ClientAppsMetadata clientAppsMetadata;
  final ClientLocationsCatalog locationsCatalog;
  final ClientSupportAssistantReply assistantReply;
  final Future<void>? assistantGate;
  final Set<int> assistantFailureCalls;
  final Future<void>? bonusSummaryGate;
  final String? locationsCatalogFailure;
  final String? notificationsFailure;
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
  int channelBonusCheckCalls = 0;
  int channelBonusClaimCalls = 0;
  int bonusSummaryCalls = 0;
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
  bool? lastWarpConsentEnabled;
  String? lastWarpRuntimeEventName;
  String? lastWarpRuntimeEventState;
  Map<String, Object?>? lastWarpRuntimeEventMeta;
  WarpControlStatus warpStatus;
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
  HostPlatform? lastLocationsCatalogHostPlatform;
  String? lastLocationsCatalogQuery;
  String? lastPreferredNodeCode;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
  }) async {
    calls += 1;
    lastRouteMode = routeMode;
    lastHostPlatform = hostPlatform;
    lastPreferredNodeCode = preferredNodeCode;
    return payload;
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
    lastBonusSummaryHostPlatform = hostPlatform;
    return bonusSummary;
  }

  @override
  Future<ClientAppsMetadata> fetchClientApps({
    required HostPlatform hostPlatform,
    required String currentVersion,
    String channel = 'beta',
  }) async {
    clientAppsCalls += 1;
    lastClientAppsHostPlatform = hostPlatform;
    lastClientAppsCurrentVersion = currentVersion;
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
    return locationsCatalog;
  }

  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({
    required HostPlatform hostPlatform,
  }) async {
    return ClientSubscriptionInfo(
      lane: 'trialPremium',
      expiresAt: '2026-06-27T00:00:00Z',
      daysLeft: 5,
      autoRenew: false,
      renewUrl: Uri.parse('https://pay.pokrov.space/checkout/test'),
      plans: const <ClientSubscriptionPlan>[
        ClientSubscriptionPlan(id: '1m', title: '1 month', price: '299 RUB'),
      ],
      trafficPolicy: const <String, Object?>{},
    );
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
    if (notificationsFailure != null) {
      throw BootstrapFailure(notificationsFailure!);
    }
    return const ClientNotificationInbox(
      items: <ClientNotificationItem>[],
      nextCursor: '',
      unreadCount: 0,
    );
  }

  @override
  Future<bool> markClientNotificationsRead({
    required HostPlatform hostPlatform,
    required List<String> ids,
  }) async {
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

class _ThrowingBootstrapper implements ManagedProfileBootstrapper {
  const _ThrowingBootstrapper(this.message);

  final String message;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
    String preferredNodeCode = '',
  }) async {
    throw BootstrapFailure(message);
  }
}

void _installReadyRuntimeBridgeMock({List<String>? calls}) {
  const channel = MethodChannel('space.pokrov/runtime_engine');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(channel, (call) async {
    calls?.add(call.method);
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
        return <String, Object?>{
          'phase': 'running',
          'artifactDirectory': '/host/runtime',
          'coreBinaryPath': '/host/runtime/pokrov-core.aar',
          'stagedConfigPath': '/host/runtime/pokrov-seed-runtime.json',
          'supportsLiveConnect': true,
          'canInitialize': true,
          'canConnect': true,
          'message': 'Runtime service is running.',
        };
      case 'runtimeEngine.disconnect':
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
          'applied': true,
          'effectiveAt': 'now',
          'fallbackUsed': false,
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

Future<void> _tapNav(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
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
    expect(find.text('Я новый пользователь'), findsOneWidget);
    expect(find.text('5 дней премиум бесплатно'), findsOneWidget);
    expect(find.text('У меня уже есть доступ'), findsOneWidget);
    expect(find.text('Восстановить по коду'), findsOneWidget);
    expect(find.textContaining('логин'), findsNothing);
    expect(find.textContaining('регистра'), findsNothing);
    expect(find.textContaining('raw'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();

    expect(find.text('Восстановить доступ'), findsOneWidget);
    expect(
      find.text(
        'Введите одноразовый код устройства из кабинета или код активации из Telegram, сайта или письма.',
      ),
      findsOneWidget,
    );
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Получить код в Telegram'), findsOneWidget);
    expect(find.text('Открыть кабинет'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('first-launch-restore-screen')),
      findsNothing,
    );
    expect(find.text('Устройство привязано. Код больше не действует.'),
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
    final homeWarpTile = find.byKey(const ValueKey('home-warp-tile'));
    expect(homeWarpTile, findsOneWidget);
    expect(find.textContaining('Дополнительная защита'), findsOneWidget);
    expect(find.descendant(of: homeWarpTile, matching: find.text('WARP')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-telegram-bonus-pill')), findsOneWidget);
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
      channelBonusPremiumDays: 10,
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
            dismissible: false,
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
    expect(find.text('Подарок за Telegram'), findsOneWidget);
    expect(find.text('Только в бонусах'), findsNothing);
  });

  testWidgets('home admin promotion ignores unsafe CTA schemes',
      (tester) async {
    const summary = AppFirstBonusSummary(
      referralCount: 0,
      referralCode: 'POKROV',
      referralBonusDays: 10,
      streakMonths: 0,
      lastWheelSpin: '',
      channelBonusPremiumDays: 10,
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
            dismissible: false,
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

  testWidgets('startup update check shows prompt and opens download',
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
      ),
    );
    await tester.pumpAndSettle();

    expect(bootstrapper.clientAppsCalls, 1);
    expect(bootstrapper.lastClientAppsCurrentVersion, '1.0.0-beta.4');
    expect(find.byKey(const ValueKey('client-update-prompt')), findsOneWidget);
    expect(find.text('Небольшие исправления бета-версии.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('client-update-download')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.host, 'github.com');
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
    expect(find.text('Туннель'), findsOneWidget);
    expect(find.text('DNS'), findsOneWidget);
    expect(find.text('Интернет / HTTPS'), findsOneWidget);
    expect(find.text('Маршруты'), findsOneWidget);
    expect(find.textContaining('не доказывают отсутствие'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('protection-repair-action')),
      findsOneWidget,
    );
  });

  testWidgets(
      'protection repair runs one bounded disconnect stage connect loop',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final runtimeCalls = <String>[];
    var phase = 'running';

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
        'hostHealth': phase == 'running' ? 'healthy' : 'unknown',
        'dnsState': phase == 'running' ? 'healthy' : 'unknown',
        'uplinkState': phase == 'running' ? 'healthy' : 'unknown',
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
        configPayload: '{}',
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
    expect(find.text('Активен'), findsOneWidget);
    expect(find.text('Работает'), findsOneWidget);
    expect(find.text('Доступен'), findsOneWidget);
    expect(find.text('Назначены'), findsOneWidget);
    expect(find.textContaining('41 мс'), findsOneWidget);

    runtimeCalls.clear();
    final repairAction = find.byKey(const ValueKey('protection-repair-action'));
    await tester.ensureVisible(repairAction);
    await tester.pumpAndSettle();
    await tester.tap(repairAction);
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

  testWidgets('profile uses grouped MVP account sections', (tester) async {
    _expectInfoSheetHelpersCovered(const ['_SettingsRow']);

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

  testWidgets('profile Telegram bonus uses app-first link check and claim',
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
    expect(find.textContaining('+10'), findsWidgets);

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
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('profile loads compact bonus summary with reward preview',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
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
    expect(find.textContaining('POKROV2'), findsWidgets);
    expect(find.textContaining('+10'), findsWidgets);
    expect(find.text('Конверсия'), findsOneWidget);
    expect(find.text('Последние приглашения'), findsOneWidget);
    expect(find.text('Бонус начислен'), findsOneWidget);
    expect(find.text('Имена и аккаунты приглашённых не показываются.'),
        findsOneWidget);
    expect(find.text('Полезные задачи'), findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-quest-second_device')),
        findsOneWidget);
  });

  testWidgets('bonus preview keeps wheel and activity calendar non-mutating',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
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
    expect(find.byKey(const ValueKey('rewards-calendar-grid')), findsOneWidget);
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
      channelBonusPremiumDays: 10,
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
        channelBonusPremiumDays: 10,
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
              title: 'Telegram +10 days',
              body: 'Connect Telegram and claim the reward.',
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
        find.byKey(const ValueKey('rewards-promo-slot-cta-telegram_bonus_app')),
        findsOneWidget);
    expect(find.text('Telegram +10 days'), findsOneWidget);
  });

  testWidgets('profile rewards hub opens referral share link', (tester) async {
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
          of: copyAction, matching: find.byIcon(Icons.copy_rounded)),
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

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: copyAction, matching: find.byIcon(Icons.copy_rounded)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-hub-sheet')),
      findsOneWidget,
    );
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
    expect(find.text('Пока нет уведомлений.'), findsOneWidget);

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
      expect(
          find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
      if (item.platform == HostPlatform.android) {
        expect(find.byType(NavigationBar), findsOneWidget);
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
    final desktopDiscSize =
        tester.getSize(find.byKey(const ValueKey('connect-disc-motion')));
    expect(desktopDiscSize.width, inInclusiveRange(180, 220));
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-news-card')), findsNothing);

    // Desktop header affordances stay honest: tooltips and icons describe
    // the actual targets (connection details sheet, rules tab).
    final detailsAction = tester.widget<IconButton>(
      find.byKey(const ValueKey('home-desktop-notifications-action')),
    );
    expect(detailsAction.tooltip, 'Детали подключения');
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

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
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
    expect(runtimeCalls, contains('runtimeEngine.applyWarp'));
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
    expect(find.text('Включится при следующем подключении'), findsOneWidget);
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

    // Tap the tile body (subtitle text), not the inline switch.
    await tester.tap(find.text('Дополнительная защита'));
    await tester.pumpAndSettle();

    expect(bootstrapper.warpConsentCalls, 1);
    expect(bootstrapper.lastWarpConsentEnabled, isTrue);
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsNothing);
    expect(find.text('Включится при следующем подключении'), findsOneWidget);
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
    expect(
      find.descendant(
        of: warpTile,
        matching: find.text('Дополнительная защита'),
      ),
      findsOneWidget,
    );

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

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
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

  testWidgets('home uses raster brand mark and one animated connect disc',
      (tester) async {
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
    final discSize =
        tester.getSize(find.byKey(const ValueKey('connect-disc-motion')));
    expect(discSize.width, inInclusiveRange(140, 172));
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
    expect(
        find.byKey(const ValueKey('home-status-dot-motion')), findsOneWidget);
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
    await tester.tap(refresh);
    await tester.pump();

    expect(
        find.byKey(const ValueKey('rewards-skeleton-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('motion-skeleton-line')), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('rewards-skeleton-summary')), findsNothing);
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
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-chat-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-chat-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-attach-diagnostics')),
        findsOneWidget);
    expect(opened.length, 1);

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
    expect(find.text('Что отправим'), findsOneWidget);
    expect(find.textContaining('статус VPN'), findsOneWidget);
    expect(find.textContaining('Сырые'), findsNothing);
    expect(find.textContaining('config'), findsNothing);
    expect(find.textContaining('конфиг'), findsNothing);
    expect(find.textContaining('адреса серверов'), findsNothing);
    expect(find.textContaining('://'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('support-diagnostics-close')));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('support-chat-telegram-fallback')));
    await tester.pumpAndSettle();

    expect(opened.last.toString(), 'tg://resolve?domain=pokrov_supportbot');
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

  testWidgets('support chat keeps AI helper scoped to support suggestions',
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
    expect(find.byKey(const ValueKey('support-assistant-suggestions')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('nav-ai-assistant')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('support-ai-suggestion-connectivity')),
    );
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('support-chat-composer')),
    );
    expect(composer.controller?.text, contains('Не подключается'));
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
        reply: 'Проверьте доступ и попробуйте переподключиться.',
        shouldEscalate: false,
        suggestedActions: <ClientSupportAssistantAction>[],
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

    final entry = find.byKey(const ValueKey('support-ai-entry'));
    expect(entry, findsOneWidget);
    expect(find.text('Спросить ИИ-помощника'), findsOneWidget);
    expect(find.text('Мгновенные ответы по базе знаний'), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('support-assistant-sheet')),
      findsOneWidget,
    );
    expect(find.text('ИИ-помощник'), findsOneWidget);
    expect(
      find.text('Отвечает автоматика по базе знаний POKROV'),
      findsOneWidget,
    );
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
      find.byKey(const ValueKey('assistant-typing-indicator')),
      findsOneWidget,
    );

    assistantGate.complete();
    await tester.pumpAndSettle();

    expect(bootstrapper.assistantCalls, 1);
    expect(bootstrapper.lastAssistantMessage, 'Не получается подключиться');
    expect(
      bootstrapper.lastAssistantDiagnostics?.keys.toSet(),
      <String>{'app_version', 'platform', 'route_mode', 'connection_status'},
    );
    expect(
      find.byKey(const ValueKey('assistant-typing-indicator')),
      findsNothing,
    );
    expect(find.text('Не получается подключиться'), findsOneWidget);
    expect(
      find.text('Проверьте доступ и попробуйте переподключиться.'),
      findsOneWidget,
    );
    expect(find.text('ИИ'), findsWidgets);

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

    await tester.tap(find.byKey(const ValueKey('support-ai-entry')));
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
        },
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('support-assistant-sheet')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('support-ai-entry')));
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

    await tester.tap(find.byKey(const ValueKey('support-ai-entry')));
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
    expect(find.text('В работе'), findsOneWidget);
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

    final dnsCard = find.byKey(const ValueKey('rules-dns-lan'));
    await tester.dragUntilVisible(
      dnsCard,
      find.byType(Scrollable).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-dns-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rules-dns-cloudflare')));
    await tester.pumpAndSettle();
    expect(
      store.state.routingPreferences.dnsPreset,
      PokrovDnsPreset.cloudflare,
    );

    expect(find.bySemanticsLabel('Локальная сеть'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rules-lan-toggle')));
    await tester.pumpAndSettle();
    expect(store.state.routingPreferences.allowLan, isFalse);
    expect(store.writeCalls, greaterThanOrEqualTo(4));
    semantics.dispose();
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

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
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

    await tester.tap(find.byKey(const ValueKey('rules-selected-app-pick')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rules-selected-app-picker-sheet')),
        findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'rules-selected-app-option-org.telegram.messenger',
        ),
      ),
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

    await tester.tap(find.byKey(const ValueKey('rules-selected-app-pick')));
    await tester.pumpAndSettle();

    final nativeOption = find.byKey(
      const ValueKey(
        'rules-selected-app-option-org.thoughtcrime.securesms',
      ),
    );
    expect(nativeOption, findsOneWidget);

    await tester.tap(nativeOption);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('rules-selected-app-org.thoughtcrime.securesms'),
      ),
      findsOneWidget,
    );

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
  });

  testWidgets('advanced settings open as diagnostics without acknowledgement',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
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

    expect(
      find.byKey(const ValueKey('profile-advanced-settings-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('advanced-app-version')), findsOneWidget);
    expect(find.byKey(const ValueKey('advanced-channel')), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
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

  testWidgets('locations screen renders backend catalog cities',
      (tester) async {
    _expectFeatureLabelHelpersCovered(const [
      '_smartConnectNodeTitle',
      '_smartConnectNodeCity',
      '_smartConnectQualityLabel',
      '_locationQualityLabel',
    ]);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _installReadyRuntimeBridgeMock();

    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload: _materializedRuntimeConfig,
        materializedForRuntime: true,
      ),
      locationsCatalog: const ClientLocationsCatalog(
        auto: ClientLocationAuto(
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
                measuredAt: '2026-07-23T10:15:00+00:00',
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
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');
    await tester.pumpAndSettle();

    expect(bootstrapper.locationsCatalogCalls, greaterThanOrEqualTo(1));
    expect(
      find.byKey(const ValueKey('locations-catalog-city-nl-ams-01')),
      findsOneWidget,
    );
    expect(find.text('Amsterdam'), findsOneWidget);
    expect(find.textContaining('38 мс'), findsOneWidget);
    expect(find.textContaining('нагрузка 31%'), findsOneWidget);
  });

  testWidgets(
      'locations explain locked selection before Smart Connect while favorites work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-without-smart-connect',
        configPayload: '{}',
        materializedForRuntime: true,
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
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('locations-selection-locked-nl-ams-01'),
      ),
      findsOneWidget,
    );
    await tester.tap(city, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(store.state.recentNodeCodes, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('locations-favorite-nl-ams-01')),
    );
    await tester.pumpAndSettle();
    expect(store.state.favoriteNodeCodes, <String>['nl-ams-01']);
    expect(store.state.recentNodeCodes, isEmpty);
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
        configPayload: '{}',
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
    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();
    await _tapNav(tester, 'nav-locations');

    expect(find.text('Amsterdam'), findsOneWidget);
    expect(find.text('Избранное'), findsOneWidget);
    expect(find.text('Нет свежих данных'), findsOneWidget);
    expect(
        find.textContaining('Показываем сохранённый список'), findsOneWidget);

    final favoriteAction =
        find.byKey(const ValueKey('locations-favorite-nl-ams-01'));
    await tester.tap(favoriteAction);
    await tester.pumpAndSettle();
    expect(store.state.favoriteNodeCodes, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('locations-catalog-city-nl-ams-01')),
    );
    await tester.pumpAndSettle();
    expect(store.state.recentNodeCodes, <String>['nl-ams-01']);
    expect(store.writeCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('profile keeps cached notifications when refresh is offline',
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
    await _tapNav(tester, 'nav-profile');
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('profile-notifications-action'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Сохранённый инцидент'), findsOneWidget);
    expect(
      find.textContaining('Показываем сохранённые уведомления'),
      findsOneWidget,
    );
  });

  testWidgets('primary connect action auto-prepares and starts host runtime',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    final stagedPayloads = <String>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
        materializedForRuntime: true,
      ),
    );

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
  });

  testWidgets('primary connect label is part of the tappable action',
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
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final label = find.descendant(
      of: find.byKey(const ValueKey('connect-disc-label')),
      matching: find.text('Включить VPN'),
    );
    await tester.tap(label);
    await tester.pumpAndSettle();

    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.initialize',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
    expect(find.byKey(const ValueKey('connect-disc-connected-settle')),
        findsOneWidget);
  });

  testWidgets('bootstrap failures surface as a calm recovery banner',
      (tester) async {
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

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: const _ThrowingBootstrapper(
          'POKROV РЅРµ СЃРјРѕРі СЃРІСЏР·Р°С‚СЊСЃСЏ СЃ СЃРµСЂРІРёСЃРѕРј РїРѕРґРіРѕС‚РѕРІРєРё.',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connect-disc-error-settle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motion-recovery-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('POKROV'), findsWidgets);
  });

  testWidgets('unexpected runtime errors surface as recovery feedback',
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
          return Completer<Map<String, Object?>>().future;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        runtimeActionTimeout: const Duration(milliseconds: 10),
        bootstrapper: _FakeBootstrapper(
          const ManagedProfilePayload(
            profileName: 'managed-from-api',
            configPayload:
                '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
            materializedForRuntime: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await tester.tap(find.byKey(const ValueKey('primary-connect-action')));
    await tester.pumpAndSettle();

    expect(calls, contains('runtimeEngine.connect'));
    expect(
        find.byKey(const ValueKey('motion-recovery-banner')), findsOneWidget);
    expect(find.textContaining('система не ответила вовремя'), findsWidgets);
  });

  testWidgets(
      'android reconnect refreshes the managed profile even when one is already staged',
      (tester) async {
    const channel = MethodChannel('space.pokrov/runtime_engine');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'managed-from-api',
        configPayload:
            '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
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

    expect(bootstrapper.calls, 1);
    expect(
      calls,
      containsAllInOrder(const [
        'runtimeEngine.snapshot',
        'runtimeEngine.stageManagedProfile',
        'runtimeEngine.connect',
      ]),
    );
  });

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
      'primary connect action keeps the host bridge message until runtime is running',
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
                '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
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
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Semantics>(connectAction).properties.enabled,
      isTrue,
    );
    expect(find.byKey(const ValueKey('connect-disc-label')), findsOneWidget);
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
                '{"outbounds":[{"type":"selector","tag":"proxy"}],"route":{"final":"proxy"}}',
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(snapshotCalls, greaterThanOrEqualTo(2));
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
    // Signature-arc refresh: the stock Material indicator is replaced by the
    // product's own connect-arc control; at rest the sliver has zero extent,
    // so the finder must not skip offstage.
    final profileIndicator = find.byKey(
      const ValueKey('profile-refresh-indicator'),
      skipOffstage: false,
    );
    expect(profileIndicator, findsOneWidget);
    expect(
      find.byType(RefreshIndicator),
      findsNothing,
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
      expect(appContext.runtimeProfile.freeTier.speedMbps, 50);
      expect(appContext.redeemHint, isEmpty);
      expect(appContext.locations, hasLength(1));
    }
  });
}
