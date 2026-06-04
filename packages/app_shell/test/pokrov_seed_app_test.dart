import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';
import 'package:pokrov_runtime_engine/runtime_engine.dart';

class _FakeBootstrapper
    implements
        ManagedProfileBootstrapper,
        AppFirstAccountActionService,
        AppFirstBonusActionService {
  _FakeBootstrapper(
    this.payload, {
    CabinetHandoff? cabinetHandoff,
    TelegramLinkResult? telegramLinkResult,
    ChannelBonusStatus? channelBonusStatus,
    ChannelBonusClaimResult? channelBonusClaimResult,
    AppFirstBonusSummary? bonusSummary,
    AppFirstRedeemResult? redeemResult,
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
            );

  final ManagedProfilePayload payload;
  final AppFirstRedeemResult redeemResult;
  final CabinetHandoff cabinetHandoff;
  final TelegramLinkResult telegramLinkResult;
  final ChannelBonusStatus channelBonusStatus;
  final ChannelBonusClaimResult channelBonusClaimResult;
  final AppFirstBonusSummary bonusSummary;
  int calls = 0;
  int redeemCalls = 0;
  int cabinetCalls = 0;
  int telegramLinkCalls = 0;
  int channelBonusCheckCalls = 0;
  int channelBonusClaimCalls = 0;
  int bonusSummaryCalls = 0;
  int wheelSpinCalls = 0;
  int calendarCheckInCalls = 0;
  RouteMode? lastRouteMode;
  HostPlatform? lastHostPlatform;
  String? lastRedeemCode;
  HostPlatform? lastRedeemHostPlatform;
  String? lastCabinetTargetPath;
  HostPlatform? lastCabinetHostPlatform;
  HostPlatform? lastTelegramLinkHostPlatform;
  HostPlatform? lastChannelBonusCheckHostPlatform;
  HostPlatform? lastChannelBonusClaimHostPlatform;
  HostPlatform? lastBonusSummaryHostPlatform;
  HostPlatform? lastWheelSpinHostPlatform;
  HostPlatform? lastCalendarCheckInHostPlatform;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    List<String> selectedApps = const <String>[],
  }) async {
    calls += 1;
    lastRouteMode = routeMode;
    lastHostPlatform = hostPlatform;
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
    bonusSummaryCalls += 1;
    lastBonusSummaryHostPlatform = hostPlatform;
    return bonusSummary;
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
}

class _FakeSupportTicketService implements SupportTicketService {
  _FakeSupportTicketService(
    this.receipt, {
    List<SupportTicketThread> tickets = const <SupportTicketThread>[],
    SupportTicketThread? loadedThread,
    List<SupportTicketThread> loadedThreads = const <SupportTicketThread>[],
    SupportTicketThread? sentThread,
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
  }) async {
    throw BootstrapFailure(message);
  }
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

  testWidgets('first launch asks whether the user is new or returning',
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
      findsNothing,
    );

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
        configPayload: '{}',
        materializedForRuntime: true,
      ),
    );
    final launched = <Uri>[];

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
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
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('first-launch-restore-code-field')),
      'POKROV-ACCESS-2026',
    );
    await tester.tap(find.byKey(const ValueKey('first-launch-restore-redeem')));
    await tester.pumpAndSettle();

    expect(bootstrapper.redeemCalls, 1);
    expect(bootstrapper.lastRedeemCode, 'POKROV-ACCESS-2026');
    expect(bootstrapper.lastRedeemHostPlatform, HostPlatform.windows);
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

  testWidgets('returning first launch rejects raw subscription links locally',
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
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('first-launch-returning-user')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-launch-manual-key-warning')),
      findsOneWidget,
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
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
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
    final advanced = find.byKey(const ValueKey('profile-section-advanced'));
    await tester.dragUntilVisible(
      advanced,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(advanced, findsOneWidget);
  });

  testWidgets('profile uses grouped MVP account sections', (tester) async {
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

    final advanced = find.byKey(const ValueKey('profile-section-advanced'));
    await tester.dragUntilVisible(
      advanced,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(advanced, findsOneWidget);
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
    expect(find.byKey(const ValueKey('profile-redeem-code-field')),
        findsOneWidget);
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
        configPayload: '{}',
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile-redeem-code-field')),
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
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
        configPayload: '{}',
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile-redeem-code-field')),
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
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

  testWidgets('profile cabinet opens through short-lived handoff',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
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
    await tester.tap(find.byKey(const ValueKey('profile-open-cabinet-action')));
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
        configPayload: '{}',
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
        find.byKey(const ValueKey('profile-telegram-check-action'));
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
        configPayload: '{}',
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
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-bonus-summary-telegram')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-bonus-summary-referral')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-bonus-summary-promo')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-bonus-history-item-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-bonus-history-item-1')),
        findsOneWidget);
    expect(find.text('Промокод активирован'), findsOneWidget);
    expect(find.text('Telegram-бонус получен'), findsOneWidget);
    expect(find.textContaining('POKROV2'), findsWidgets);
    expect(find.textContaining('+10'), findsWidgets);
    expect(find.byKey(const ValueKey('profile-bonus-wheel-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-activity-calendar-action')),
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

    expect(find.text('Р СѓР»РµС‚РєР°'), findsNothing);
    expect(find.text('РљР°Р»РµРЅРґР°СЂСЊ Р°РєС‚РёРІРЅРѕСЃС‚Рё'), findsNothing);
    expect(find.byKey(const ValueKey('profile-bonus-wheel-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-activity-calendar-action')),
        findsOneWidget);
  });

  testWidgets('profile opens rewards hub with wheel and calendar preview',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
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
        findsOneWidget);
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
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('rewards-promo-slot-empty')), findsOneWidget);
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
        configPayload: '{}',
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
    await tester.tap(find.byKey(const ValueKey('rewards-wheel-spin-action')));
    await tester.pumpAndSettle();

    expect(bootstrapper.wheelSpinCalls, 1);
    expect(bootstrapper.lastWheelSpinHostPlatform, HostPlatform.android);

    await tester
        .tap(find.byKey(const ValueKey('profile-activity-calendar-action')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('rewards-calendar-checkin-action')));
    await tester.pumpAndSettle();

    expect(bootstrapper.calendarCheckInCalls, 1);
    expect(bootstrapper.lastCalendarCheckInHostPlatform, HostPlatform.android);
  });

  testWidgets('profile rewards hub shows first-party promo slots',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
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
        configPayload: '{}',
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

  testWidgets('profile opens subscription and email recovery sheets',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
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

  testWidgets('profile exposes compact account details and tactile rows',
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

    final accountDetails =
        find.byKey(const ValueKey('profile-account-details-action'));
    expect(accountDetails, findsOneWidget);
    await tester.dragUntilVisible(
      accountDetails,
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(accountDetails);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-account-details-sheet')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-account-details-cabinet')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-account-details-downloads')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-account-details-email')),
        findsOneWidget);
  });

  testWidgets('disabled rewards render muted states instead of CTAs',
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

    final wheelMuted = find.byKey(const ValueKey('rewards-wheel-muted-state'));
    final calendarMuted =
        find.byKey(const ValueKey('rewards-calendar-muted-state'));
    expect(wheelMuted, findsOneWidget);
    expect(calendarMuted, findsOneWidget);
    expect(
      find.descendant(of: wheelMuted, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: calendarMuted, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('rewards-wheel-spin-action')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('rewards-calendar-checkin-action')),
        findsOneWidget);
  });

  testWidgets('P4 responsive width matrix keeps the app shell stable',
      (tester) async {
    final cases = <({double width, HostPlatform platform, String shellKey})>[
      (width: 360, platform: HostPlatform.android, shellKey: 'mobile-shell'),
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

  testWidgets('windows shell collapses sidebar and shows honest WARP tile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
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
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);

    expect(find.text('Р’Р°С€ РѕСЃРЅРѕРІРЅРѕР№ СЂРµРіРёРѕРЅ'), findsNothing);
    expect(find.text('РќРѕРІРѕСЃС‚Рё Рё СѓРІРµРґРѕРјР»РµРЅРёСЏ'), findsNothing);
    expect(find.text('РЈСЃРёР»РµРЅРЅС‹Р№ СЂРµР¶РёРј'), findsNothing);
    final warpTile = find.byKey(const ValueKey('home-warp-tile'));
    expect(warpTile, findsOneWidget);
    expect(find.textContaining('WARP'), findsOneWidget);

    await tester.tap(warpTile);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('WARP'), findsWidgets);
    expect(find.textContaining('Р’РєР»СЋС‡РёС‚СЊ WARP'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('ready WARP tile asks for explicit consent before activation',
      (tester) async {
    final bootstrapper = _FakeBootstrapper(
      const ManagedProfilePayload(
        profileName: 'test-profile',
        configPayload: '{}',
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
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
        bootstrapper: bootstrapper,
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(
        find.byKey(const ValueKey('home-warp-state-disabled')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-warp-tile')));
    await tester.pumpAndSettle();

    expect(bootstrapper.calls, 1);
    expect(find.byKey(const ValueKey('home-warp-sheet')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-warp-consent-switch')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-warp-enable-action')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-warp-enable-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-warp-sheet')), findsNothing);
    expect(
        find.byKey(const ValueKey('home-warp-state-enabled')), findsOneWidget);
  });

  testWidgets(
      'narrow windows shell uses a hamburger drawer instead of fixed sidebar',
      (tester) async {
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
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    expect(find.byKey(const ValueKey('pokrov-brand-mark')), findsWidgets);
    expect(find.byKey(const ValueKey('connect-disc-motion')), findsOneWidget);
    expect(find.byKey(const ValueKey('connect-disc-label')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-switcher')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-chip-motion')), findsWidgets);
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
      findsOneWidget,
    );
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
    expect(supportTicketService.lastDiagnostics?['platform'], 'windows');
    expect(find.textContaining('#777'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-attach-diagnostics')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-diagnostics-preview')),
        findsOneWidget);
    expect(find.textContaining(appContext.hostPlatform.label), findsWidgets);
    expect(find.textContaining('config'), findsNothing);
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

    final selectedAppsStatus =
        find.byKey(const ValueKey('rules-section-selected-apps'));
    await tester.dragUntilVisible(
      selectedAppsStatus,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(selectedAppsStatus, findsOneWidget);
    expect(find.byKey(const ValueKey('rules-catalog-version')), findsOneWidget);
    expect(find.textContaining('2026-04-13'), findsWidgets);

    final banksPreset = find.byKey(const ValueKey('rules-preset-ru-banks'));
    final gosuslugiPreset =
        find.byKey(const ValueKey('rules-preset-gosuslugi'));
    final messengerPreset =
        find.byKey(const ValueKey('rules-preset-messengers'));

    expect(banksPreset, findsOneWidget);
    expect(gosuslugiPreset, findsOneWidget);
    expect(messengerPreset, findsOneWidget);
    expect(
      find.descendant(of: banksPreset, matching: find.text('Активно')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gosuslugiPreset, matching: find.text('Активно')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: messengerPreset, matching: find.text('Готовится')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedAppsStatus,
        matching: find.byKey(const ValueKey('rules-selected-app-input')),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('geoip'), findsNothing);
    expect(find.textContaining('.srs'), findsNothing);
    expect(find.textContaining('CIDR'), findsNothing);
    expect(find.textContaining('rule_set'), findsNothing);
    expect(find.text('Р’С‹Р±СЂР°РЅРЅС‹Рµ РїСЂРёР»РѕР¶РµРЅРёСЏ РІ beta'),
        findsNothing);
    expect(
        find.text('Р§С‚Рѕ Р·РЅР°С‡РёС‚ РєР°Р¶РґС‹Р№ СЂРµР¶РёРј'), findsNothing);
  });

  testWidgets('rules lets user add a custom selected app identifier',
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

    await tester.enterText(
      find.byKey(const ValueKey('rules-selected-app-input')),
      'com.example.special',
    );
    await tester.tap(find.byKey(const ValueKey('rules-selected-app-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rules-selected-app-com.example.special')),
        findsOneWidget);
    expect(find.text('com.example.special'), findsOneWidget);

    await _tapNav(tester, 'nav-protection');
    await tester.pumpAndSettle();

    final routeChip = find.byKey(const ValueKey('home-route-chip'));
    expect(routeChip, findsOneWidget);
    expect(
      find.descendant(
        of: routeChip,
        matching: find.text(RouteMode.selectedApps.label),
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
        matching: find.text(RouteMode.selectedApps.label),
      ),
      findsOneWidget,
    );
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
  });

  testWidgets('advanced settings require acknowledgement before opening',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
    await _completeFirstLaunchIfPresent(tester);

    await _tapNav(tester, 'nav-profile');

    final advanced = find.byKey(const ValueKey('profile-section-advanced'));
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
    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).enabled,
        isFalse);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).enabled,
        isTrue);
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
      ),
    );

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'artifactReady',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Host bridge ready.',
          };
        case 'runtimeEngine.initialize':
          return <String, Object?>{
            'phase': 'initialized',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
      find.byKey(const ValueKey('motion-recovery-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('POKROV'), findsWidgets);
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
      ),
    );

    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'runtimeEngine.snapshot':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            configPayload: '{}',
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
              'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
              'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
            'supportsLiveConnect': true,
            'canInitialize': true,
            'canConnect': false,
            'message': 'Runtime bootstrap completed on the host bridge.',
          };
        case 'runtimeEngine.stageManagedProfile':
          return <String, Object?>{
            'phase': 'configStaged',
            'artifactDirectory': '/host/runtime',
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
            'coreBinaryPath': '/host/runtime/libcore.aar',
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
          'coreBinaryPath': '/host/runtime/libcore.aar',
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
