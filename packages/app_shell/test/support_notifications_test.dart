import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('disk inbox belongs only to the matching session owner', (tester) async {
    final client = _BoundInboxClient()..owner = 'account-A'..offline = false;
    final experience = _MemoryExperience();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    Future<void> startApp() async {
      await tester.pumpWidget(PokrovSeedApp(
        appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
        bootstrapper: client,
        firstLaunchStore: _CompletedFirstLaunch(),
        clientExperienceStore: experience,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    await startApp();
    expect(experience.saved.notificationCacheOwner, 'account-A');
    expect(experience.saved.cachedNotifications?.unreadCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    experience.discardWrites = true;
    client.offline = true;
    await startApp();
    expect(find.byTooltip('Уведомления · 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Уведомления · 1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Поддержка ответила'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    client.owner = 'account-B';
    await startApp();
    expect(find.byTooltip('Уведомления · 1'), findsNothing);
    await tester.tap(find.byTooltip('Уведомления'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Поддержка ответила'), findsNothing);
    expect(find.text('Не удалось загрузить уведомления.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    experience.saved = experience.saved.copyWith(notificationCacheOwner: '');
    client.owner = 'account-A';
    await startApp();
    expect(find.byTooltip('Уведомления · 1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late bonus summary from the previous account is ignored', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final oldSummary = Completer<AppFirstBonusSummary>();
    final client = _InboxClient()..pendingBonus = oldSummary;
    final links = StreamController<Uri>.broadcast();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: client,
      supportTicketService: client,
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: _MemoryExperience(),
      acquisitionUriStream: links.stream,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(client.bonusCalls, greaterThan(0));

    links.add(Uri.parse('pokrov://pair?code=ABCD-9XYZ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(client.accountChanged, isTrue);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Профиль').last);
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
    expect(find.textContaining('2 реф.'), findsOneWidget);
    oldSummary.complete(_bonusSummary(99));
    await tester.pump();
    expect(find.textContaining('2 реф.'), findsOneWidget);
    expect(find.textContaining('99 реф.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await links.close();
  });

  testWidgets('account change closes the previous account inbox', (tester) async {
    final client = _InboxClient()..inbox = _inbox(1);
    final links = StreamController<Uri>.broadcast();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: client,
      supportTicketService: client,
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: _MemoryExperience(),
      acquisitionUriStream: links.stream,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Уведомления · 1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Поддержка ответила'), findsOneWidget);

    links.add(Uri.parse('pokrov://pair?code=ABCD-9XYZ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(client.accountChanged, isTrue);
    expect(find.byKey(const ValueKey('profile-notifications-sheet')), findsNothing);
    expect(find.text('Поддержка ответила'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await links.close();
  });

  testWidgets('account change clears cached inbox and ignores a late old reply', (tester) async {
    final client = _InboxClient()..inbox = _inbox(1);
    final experience = _MemoryExperience();
    final links = StreamController<Uri>.broadcast();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: client,
      supportTicketService: client,
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: experience,
      acquisitionUriStream: links.stream,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Уведомления · 1'), findsOneWidget);

    final oldInbox = Completer<ClientNotificationInbox>();
    client.pending = oldInbox;
    await tester.pump(const Duration(seconds: 60));
    links.add(Uri.parse('pokrov://pair?code=ABCD-9XYZ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('profile-redeem-submit')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(client.accountChanged, isTrue);
    expect(find.byTooltip('Уведомления · 1'), findsNothing);
    expect(experience.saved.cachedNotifications, isNull);

    client.pending = null;
    oldInbox.complete(_inbox(1));
    await tester.pump();
    await tester.tap(find.byTooltip('Уведомления'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Поддержка ответила'), findsNothing);
    expect(find.text('Не удалось загрузить уведомления.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await links.close();
  });

  testWidgets('Broadcast appears in the existing inbox on app open and is marked read', (tester) async {
    final client = _InboxClient()
      ..inbox = ClientNotificationInbox.fromJson({
        'unreadCount': 1,
        'items': [
          {
            'id': 'broadcast-app-campaign',
            'kind': 'message',
            'title': 'Сообщение от POKROV',
            'body': 'Новая информация для вашего аккаунта.',
            'createdAt': '2026-10-29T12:00:00Z',
            'ctaLabel': '',
            'ctaHref': null,
            'read': false,
          },
        ],
      });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: client,
      supportTicketService: client,
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: _MemoryExperience(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Уведомления · 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Уведомления · 1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Сообщение от POKROV'), findsOneWidget);
    expect(find.text('Новая информация для вашего аккаунта.'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-notification-cta-broadcast-app-campaign')), findsNothing);
    expect(client.readBatches, [['broadcast-app-campaign']]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home inbox refreshes once per minute and stops on pause or session loss', (tester) async {
    final client = _InboxClient();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(PokrovSeedApp(
      appContext: buildSeedAppContext(hostPlatform: HostPlatform.android),
      bootstrapper: client,
      supportTicketService: client,
      firstLaunchStore: _CompletedFirstLaunch(),
      clientExperienceStore: _MemoryExperience(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final initialCalls = client.inboxCalls;
    expect(initialCalls, greaterThan(0));
    final subscriptionCalls = client.subscriptionCalls;

    client.inbox = _inbox(1);
    await tester.pump(const Duration(seconds: 60));
    expect(client.inboxCalls, initialCalls + 1);
    expect(client.subscriptionCalls, subscriptionCalls);
    expect(find.byTooltip('Уведомления · 1'), findsOneWidget);

    final opening = Completer<ClientNotificationInbox>();
    client.pending = opening;
    final beforeOpen = client.inboxCalls;
    // A foreground timer has already started reading a newly arrived reply.
    await tester.pump(const Duration(seconds: 60));
    expect(client.inboxCalls, beforeOpen + 1);
    await tester.tap(find.byTooltip('Уведомления · 1'));
    await tester.tap(find.byTooltip('Уведомления · 1'));
    expect(client.inboxCalls, beforeOpen + 1);
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-notifications-sheet')), findsNothing);
    client.pending = null;
    client.inbox = _inbox(2);
    opening.complete(client.inbox);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('profile-notifications-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-notification-cta-support.reply.1')), findsNothing);
    expect(client.readBatches, [['support.reply.2']]);
    await tester.tap(find.byKey(const ValueKey('profile-notification-cta-support.reply.2')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Operator answer from notification'), findsOneWidget);
    expect(client.requestedTicketIds, [21]);
    expect(find.byKey(const ValueKey('profile-notifications-sheet'), skipOffstage: false), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Уведомления'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-notifications-sheet'), skipOffstage: false), findsNothing);

    final pending = Completer<ClientNotificationInbox>();
    client.pending = pending;
    await tester.pump(const Duration(seconds: 60));
    final inFlightCalls = client.inboxCalls;
    await tester.pump(const Duration(minutes: 3));
    expect(client.inboxCalls, inFlightCalls);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    client.pending = null;
    pending.complete(_inbox(2));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(client.inboxCalls, inFlightCalls);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final resumedCalls = client.inboxCalls;
    expect(resumedCalls, inFlightCalls + 1);

    client.sessionValid = false;
    await tester.pump(const Duration(seconds: 60));
    expect(client.inboxCalls, resumedCalls + 1);
    await tester.pump(const Duration(minutes: 2));
    expect(client.inboxCalls, resumedCalls + 1);

    client.sessionValid = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final beforeDispose = client.inboxCalls;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(client.inboxCalls, beforeDispose);
  });
}

ClientNotificationInbox _inbox(int unread) => ClientNotificationInbox.fromJson({
  'unreadCount': unread,
  'items': [
    {
      'id': 'support.reply.$unread',
      'kind': 'support',
      'title': 'Поддержка ответила',
      'body': 'Новый ответ в обращении.',
      'createdAt': '2026-10-14T12:00:00Z',
      'ctaLabel': 'Открыть чат',
      'ctaHref': 'https://app.pokrov.space/support/thread/?id=21',
      'read': false,
    },
  ],
});

class _InboxClient implements ManagedProfileBootstrapper, AppFirstClientDataService, AppFirstAccountActionService, AppFirstBonusActionService, SupportTicketService {
  int inboxCalls = 0;
  int subscriptionCalls = 0;
  int bonusCalls = 0;
  bool sessionValid = true;
  bool accountChanged = false;
  ClientNotificationInbox inbox = const ClientNotificationInbox(
    items: [], nextCursor: '', unreadCount: 0,
  );
  Completer<ClientNotificationInbox>? pending;
  Completer<AppFirstBonusSummary>? pendingBonus;
  final readBatches = <List<String>>[];
  final requestedTicketIds = <int>[];

  @override
  Future<AppFirstBonusSummary> fetchBonusSummary({required HostPlatform hostPlatform}) async {
    bonusCalls++;
    if (!accountChanged && pendingBonus != null) return pendingBonus!.future;
    return _bonusSummary(accountChanged ? 2 : 1);
  }

  @override
  Future<bool> markClientNotificationsRead({required HostPlatform hostPlatform, required List<String> ids}) async {
    readBatches.add(ids);
    return true;
  }

  @override
  Future<SupportTicketThread> getTicket({required HostPlatform hostPlatform, required int ticketId}) async {
    requestedTicketIds.add(ticketId);
    return SupportTicketThread(
    id: ticketId, status: 'closed', statusTitle: 'Закрыто', subject: '', createdAt: '', updatedAt: '', closedAt: '', lastMessagePreview: '',
    messages: [SupportTicketMessage(id: 1, ticketId: ticketId, senderRole: 'admin', body: 'Operator answer from notification',
      mediaType: '', mediaFileId: '', mediaPayload: '', createdAt: '')],
    );
  }

  @override
  Future<ClientNotificationInbox> fetchClientNotifications({
    required HostPlatform hostPlatform, String after = '',
  }) async {
    inboxCalls++;
    if (accountChanged) throw StateError('offline');
    if (!sessionValid) throw const BootstrapFailure('Session ended', statusCode: 401);
    if (pending != null) return pending!.future;
    return inbox;
  }

  @override
  Future<DevicePairingClaimResult> claimDevicePairingCode({required HostPlatform hostPlatform, required String code}) async {
    accountChanged = true;
    return const DevicePairingClaimResult(ok: true, accountId: 'other', installId: 'fixture');
  }

  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({
    required HostPlatform hostPlatform,
    Duration? requestTimeout,
    Future<void>? cancelled,
  }) async {
    subscriptionCalls++;
    if (!sessionValid) throw const BootstrapFailure('Session ended', statusCode: 401);
    return ClientSubscriptionInfo.fromJson({'lane': 'paid', 'daysLeft': 10});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AppFirstBonusSummary _bonusSummary(int referrals) => AppFirstBonusSummary(
  referralCount: referrals, referralCode: '', referralBonusDays: 0,
  streakMonths: 0, lastWheelSpin: '', channelBonusPremiumDays: 0,
  channelBonusClaimedAt: '', openingBonusPremiumDays: 0, openingBonusClaimed: false,
  channelUsername: '', tierKey: '', tierPercent: 0, paidReferrals: 0,
  nextTierKey: '', nextTierAt: null,
);

class _CompletedFirstLaunch implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}

class _MemoryExperience implements PokrovClientExperienceStore {
  PokrovClientExperienceState saved = const PokrovClientExperienceState.empty();
  bool discardWrites = false;
  @override
  Future<PokrovClientExperienceState> read() async => saved;
  @override
  Future<void> write(PokrovClientExperienceState state) async {
    if (!discardWrites) saved = state;
  }
}

class _BoundInboxClient extends AppFirstRuntimeBootstrapper {
  _BoundInboxClient() : super(
    apiBaseUrl: 'http://127.0.0.1:1', maxRequestAttempts: 1,
    supportDirectoryResolver: () async => throw StateError('synthetic fixture'),
    sessionSecretStore: MemoryAppFirstSessionSecretStore(),
  );
  String? owner;
  bool offline = true;

  @override
  Future<String?> notificationCacheOwner({required HostPlatform hostPlatform}) async => owner;
  @override
  Future<ClientNotificationInbox> fetchClientNotifications({required HostPlatform hostPlatform, String after = ''}) async {
    if (offline) throw StateError('offline');
    return _inbox(1);
  }
  @override
  Future<ClientSubscriptionInfo> fetchClientSubscription({
    required HostPlatform hostPlatform, Duration? requestTimeout, Future<void>? cancelled,
  }) async => ClientSubscriptionInfo.fromJson({'lane': 'paid'});
  @override
  Future<AppFirstBonusSummary> fetchBonusSummary({required HostPlatform hostPlatform}) async => _bonusSummary(1);
}
