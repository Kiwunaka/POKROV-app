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
            );

  final ManagedProfilePayload payload;
  final AppFirstRedeemResult redeemResult = const AppFirstRedeemResult(
    ok: true,
    kind: 'access_key',
    codePreview: '...2026',
    result: <String, dynamic>{},
  );
  final CabinetHandoff cabinetHandoff;
  final TelegramLinkResult telegramLinkResult;
  final ChannelBonusStatus channelBonusStatus;
  final ChannelBonusClaimResult channelBonusClaimResult;
  int calls = 0;
  int redeemCalls = 0;
  int cabinetCalls = 0;
  int telegramLinkCalls = 0;
  int channelBonusCheckCalls = 0;
  int channelBonusClaimCalls = 0;
  RouteMode? lastRouteMode;
  HostPlatform? lastHostPlatform;
  String? lastRedeemCode;
  HostPlatform? lastRedeemHostPlatform;
  String? lastCabinetTargetPath;
  HostPlatform? lastCabinetHostPlatform;
  HostPlatform? lastTelegramLinkHostPlatform;
  HostPlatform? lastChannelBonusCheckHostPlatform;
  HostPlatform? lastChannelBonusClaimHostPlatform;

  @override
  Future<ManagedProfilePayload> resolveManagedProfile({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
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
}

class _FakeSupportTicketService implements SupportTicketService {
  _FakeSupportTicketService(
    this.receipt, {
    List<SupportTicketThread> tickets = const <SupportTicketThread>[],
    SupportTicketThread? loadedThread,
    SupportTicketThread? sentThread,
  })  : tickets = List<SupportTicketThread>.from(tickets),
        loadedThread = loadedThread ?? (tickets.isEmpty ? null : tickets.first),
        sentThread = sentThread ??
            (loadedThread ??
                (tickets.isEmpty
                    ? _supportThread(id: receipt.ticketId)
                    : tickets.first));

  final SupportTicketReceipt receipt;
  final List<SupportTicketThread> tickets;
  final SupportTicketThread? loadedThread;
  final SupportTicketThread sentThread;
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
  }) async {
    sendCalls += 1;
    lastHostPlatform = hostPlatform;
    lastTicketId = ticketId;
    lastReplyBody = body;
    return sentThread;
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
  }) async {
    throw BootstrapFailure(message);
  }
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

  test('public route choices stage selected apps until enforcement proof', () {
    for (final hostPlatform in <HostPlatform>[
      HostPlatform.android,
      HostPlatform.windows,
    ]) {
      expect(hostPlatform.supportsSelectedAppsMode, isTrue);
      final context = buildSeedAppContext(hostPlatform: hostPlatform);

      expect(
        context.runtimeProfile.supportedRouteModes,
        containsAll(const [RouteMode.allExceptRu, RouteMode.fullTunnel]),
      );
      expect(
        context.runtimeProfile.supportedRouteModes,
        isNot(contains(RouteMode.selectedApps)),
      );
    }
  });

  testWidgets('renders premium shell v2 with compact first screen',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('motion-policy')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-boot-reveal')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-warp-tile')), findsOneWidget);
    expect(find.text('Авто'), findsOneWidget);
    expect(find.text('Все, кроме РФ'), findsWidgets);

    expect(find.text('Ваш основной регион'), findsNothing);
    expect(find.text('Новости и уведомления'), findsNothing);
    expect(find.text('Что остается простым'), findsNothing);
    expect(find.text('Статус подключения'), findsNothing);
    expect(find.text('Усиленный режим'), findsNothing);
    expect(find.text('Telegram-бонус'), findsNothing);
    expect(find.text('Email и кабинет'), findsNothing);

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();
    expect(find.text('Вы раньше пользовались POKROV?'), findsNothing);
    expect(find.text('Ввести код'), findsWidgets);
    expect(find.text('Telegram-бонус'), findsNothing);
    expect(find.text('Email и кабинет'), findsNothing);
    expect(find.byKey(const ValueKey('profile-section-sync')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-section-app')), findsOneWidget);
    expect(find.text('Бонусы'), findsNothing);
    final support = find.byKey(const ValueKey('profile-section-support'));
    await tester.dragUntilVisible(
      support,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(support, findsOneWidget);
    final advanced = find.text('Расширенные');
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

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-compact-account-layer')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-redeem-code-field')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('profile-section-support')), findsOneWidget);
    expect(find.text('Бонусы'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Да, открыть'), findsNothing);
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

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();
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
    expect(find.textContaining('...2026'), findsWidgets);
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

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();
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

  testWidgets('bonus MVP keeps wheel and activity calendar hidden',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();

    expect(find.text('Рулетка'), findsNothing);
    expect(find.text('Календарь активности'), findsNothing);
    expect(
        find.byKey(const ValueKey('profile-bonus-wheel-action')), findsNothing);
    expect(find.byKey(const ValueKey('profile-activity-calendar-action')),
        findsNothing);
  });

  testWidgets('windows shell collapses sidebar and shows honest WARP tile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.windows),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-icon-rail')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('desktop-sidebar-expanded')), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-location-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-route-chip')), findsOneWidget);

    expect(find.text('Ваш основной регион'), findsNothing);
    expect(find.text('Новости и уведомления'), findsNothing);
    expect(find.text('Усиленный режим'), findsNothing);
    final warpTile = find.byKey(const ValueKey('home-warp-tile'));
    expect(warpTile, findsOneWidget);
    expect(find.textContaining('WARP'), findsOneWidget);

    await tester.tap(warpTile);
    await tester.pumpAndSettle();

    expect(find.text('Расширенная приватность'), findsWidgets);
    expect(find.textContaining('не активен'), findsOneWidget);
    expect(find.textContaining('Включить WARP'), findsNothing);
    expect(find.byType(Switch), findsNothing);
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

    expect(find.byKey(const ValueKey('pokrov-brand-mark')), findsWidgets);
    expect(find.byKey(const ValueKey('connect-disc-motion')), findsOneWidget);
    expect(find.byKey(const ValueKey('connect-disc-label')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-status-switcher')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-chip-motion')), findsWidgets);
    expect(
        find.byKey(const ValueKey('primary-connect-action')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Подключить'),
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

    await tester.tap(find.text('Локации').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('locations-skeleton-list')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('motion-skeleton-line')), findsWidgets);

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();

    final checkout = find.text('Оплата');
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

    final support = find.text('Написать');
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
      'Не подключается',
    );
    await tester.tap(find.byKey(const ValueKey('support-chat-send')));
    await tester.pumpAndSettle();

    expect(supportTicketService.calls, 1);
    expect(supportTicketService.lastHostPlatform, HostPlatform.windows);
    expect(supportTicketService.lastBody, 'Не подключается');
    expect(supportTicketService.lastSubject, 'Обращение из приложения POKROV');
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
    expect(find.text('Still broken'), findsOneWidget);
  });

  testWidgets('rules stage selected-apps status and hide beta prose',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Правила').last);
    await tester.pumpAndSettle();

    final modeHelp = find.text('Как выбрать');
    await tester.dragUntilVisible(
      modeHelp,
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(modeHelp, findsOneWidget);
    expect(find.text('Выбранные приложения'), findsNothing);

    final selectedAppsStatus = find.text('Приложения');
    await tester.dragUntilVisible(
      selectedAppsStatus,
      find.byType(Scrollable).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(selectedAppsStatus, findsOneWidget);
    expect(find.text('Выбор готовится.'), findsOneWidget);
    expect(find.text('Выбранные приложения в beta'), findsNothing);
    expect(find.text('Что значит каждый режим'), findsNothing);
  });

  testWidgets('advanced settings require acknowledgement before opening',
      (tester) async {
    await tester.pumpWidget(
      PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аккаунт').last);
    await tester.pumpAndSettle();

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
      find.textContaining('Только для восстановления и поддержки'),
      findsOneWidget,
    );
    expect(find.text('Да, открыть'), findsOneWidget);
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

    expect(find.textContaining('Нужно внимание'), findsWidgets);
    expect(find.textContaining('POKROV включен, но заметил'), findsWidgets);
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

    expect(find.textContaining('Нужно внимание'), findsWidgets);
    expect(find.textContaining('POKROV включен, но заметил'), findsWidgets);
    expect(find.textContaining('Последняя ошибка'), findsNothing);
    expect(
      find.text('POKROV включен.'),
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

    await tester.tap(find.text('Локации').last);
    await tester.pumpAndSettle();

    expect(find.text('Автоматический выбор'), findsOneWidget);
    expect(find.text('Появится после подготовки'), findsOneWidget);
    expect(find.textContaining('Полный доступ использует'), findsNothing);
    await tester.tap(find.text('Как выбирается'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('POKROV выбирает доступный узел'), findsOneWidget);
    expect(
      find.textContaining('Технические детали остаются в диагностике'),
      findsWidgets,
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
          'POKROV не смог связаться с сервисом подготовки.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.tap(connectAction);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('motion-recovery-banner')),
      findsOneWidget,
    );
    expect(
      find.text('POKROV не смог связаться с сервисом подготовки.'),
      findsWidgets,
    );
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

    final connectAction = find.byKey(const ValueKey('primary-connect-action'));
    await tester.dragUntilVisible(
      connectAction,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пока недоступно'), findsOneWidget);
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
                'Android просит разрешение, чтобы POKROV мог подключить это устройство.',
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
                'Android просит разрешение, чтобы POKROV мог подключить это устройство.',
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
      find.text('Отключить'),
      findsWidgets,
    );
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
      find.text('Все готово. Нажмите главную кнопку, чтобы подключиться.'),
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

    expect(find.textContaining('Готово к подключению'), findsWidgets);
    expect(
      find.text('Все готово. Нажмите главную кнопку, чтобы подключиться.'),
      findsOneWidget,
    );

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
    expect(
      find.text('Все готово. Нажмите главную кнопку, чтобы подключиться.'),
      findsNothing,
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
