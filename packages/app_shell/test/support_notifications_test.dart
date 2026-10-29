import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
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

class _InboxClient implements ManagedProfileBootstrapper, AppFirstClientDataService, SupportTicketService {
  int inboxCalls = 0;
  int subscriptionCalls = 0;
  bool sessionValid = true;
  ClientNotificationInbox inbox = const ClientNotificationInbox(
    items: [], nextCursor: '', unreadCount: 0,
  );
  Completer<ClientNotificationInbox>? pending;
  final readBatches = <List<String>>[];
  final requestedTicketIds = <int>[];

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
    if (!sessionValid) throw const BootstrapFailure('Session ended', statusCode: 401);
    if (pending != null) return pending!.future;
    return inbox;
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

class _CompletedFirstLaunch implements PokrovFirstLaunchStore {
  @override
  Future<bool> isCompleted() async => true;
  @override
  Future<void> markCompleted() async {}
}

class _MemoryExperience implements PokrovClientExperienceStore {
  @override
  Future<PokrovClientExperienceState> read() async => const PokrovClientExperienceState.empty();
  @override
  Future<void> write(PokrovClientExperienceState state) async {}
}
