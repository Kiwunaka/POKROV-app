import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/features/support/support_conversation_controller.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  testWidgets('closed notice conversation receives a later operator reply', (tester) async {
    final service = _TicketService(_thread(id: 21, closed: true));
    final controller = SupportConversationController(
      service: service,
      hostPlatform: HostPlatform.windows,
      initialTicketId: 21,
      jitterSource: () => 0,
    );
    addTearDown(controller.dispose);

    await controller.loadInitialThread();

    expect(service.requestedIds, [21]);
    expect(service.listCalls, 0);
    expect(controller.ticketId, 21);
    expect(controller.lifecycle, SupportConversationLifecycle.closed);
    expect(controller.messages.single.body, 'Initial message');

    service.thread = _thread(id: 21, reply: true);
    await tester.pump(const Duration(seconds: 8));
    expect(controller.messages.last.body, 'Operator answer');
    expect(controller.lifecycle, SupportConversationLifecycle.operator);
    expect(service.requestedIds, [21, 21]);
    controller.setForeground(false);
  });

  testWidgets('polled operator reply updates the chat and scroll callback once', (tester) async {
    final service = _TicketService(_thread());
    var messageChanges = 0;
    final controller = SupportConversationController(
      service: service,
      hostPlatform: HostPlatform.android,
      onMessagesChanged: () => messageChanges++,
      jitterSource: () => 0,
    );
    addTearDown(controller.dispose);
    await controller.loadInitialThread();
    expect(messageChanges, 1);

    service.thread = _thread(reply: true);
    await tester.pump(const Duration(seconds: 8));
    expect(controller.messages.last.body, 'Operator answer');
    expect(controller.messages.last.role, SupportChatRole.operator);
    expect(messageChanges, 2);

    await tester.pump(const Duration(seconds: 8));
    expect(messageChanges, 2);
    controller.setForeground(false);
  });

  testWidgets('late poll cannot replace the newer send response', (tester) async {
    final service = _TicketService(_thread());
    final controller = SupportConversationController(
      service: service,
      hostPlatform: HostPlatform.windows,
      jitterSource: () => 0,
    );
    addTearDown(controller.dispose);
    await controller.loadInitialThread();
    final stalePoll = Completer<SupportTicketThread>();
    service.pendingRead = stalePoll;
    await tester.pump(const Duration(seconds: 8));
    expect(service.requestedIds, [20, 20]);

    service.thread = _thread(reply: true, followUp: true);
    await controller.send(
      text: 'Thanks, checking now',
      routeMode: RouteMode.allExceptRu,
      attachDiagnostics: false,
      statusLabel: '',
      diagnostics: const {},
    );
    expect(controller.messages.map((message) => message.body),
        ['Initial message', 'Operator answer', 'Thanks, checking now']);
    stalePoll.complete(_thread());
    await tester.pump();
    expect(controller.messages.map((message) => message.body),
        ['Initial message', 'Operator answer', 'Thanks, checking now']);
    expect(controller.lifecycle, SupportConversationLifecycle.operator);
    service.pendingRead = null;
    await tester.pump(const Duration(seconds: 8));
    expect(service.requestedIds, [20, 20, 20]);
    controller.setForeground(false);
  });
}

SupportTicketThread _thread({int id = 20, bool closed = false, bool reply = false, bool followUp = false}) {
  SupportTicketMessage message(int messageId, String role, String body) =>
      SupportTicketMessage(
        id: messageId,
        ticketId: id,
        senderRole: role,
        body: body,
        mediaType: '',
        mediaFileId: '',
        mediaPayload: '',
        createdAt: '2026-10-14T10:00:00Z',
      );
  return SupportTicketThread(
    id: id,
    status: closed ? 'closed' : 'open',
    statusTitle: '',
    subject: '',
    createdAt: '2026-10-14T10:00:00Z',
    updatedAt: '2026-10-14T10:00:00Z',
    closedAt: '',
    lastMessagePreview: '',
    messages: [
      message(1, 'user', 'Initial message'),
      if (reply) message(2, 'admin', 'Operator answer'),
      if (followUp) message(3, 'user', 'Thanks, checking now'),
    ],
  );
}

class _TicketService implements SupportTicketService {
  _TicketService(this.thread);

  SupportTicketThread thread;
  final requestedIds = <int>[];
  int listCalls = 0;
  Completer<SupportTicketThread>? pendingRead;

  @override
  Future<SupportTicketThread> getTicket({
    required HostPlatform hostPlatform,
    required int ticketId,
  }) async {
    requestedIds.add(ticketId);
    final pending = pendingRead;
    if (pending != null) return pending.future;
    return thread;
  }

  @override
  Future<SupportTicketThread> sendMessage({
    required HostPlatform hostPlatform,
    required int ticketId,
    required String body,
    RouteMode? routeMode,
    String statusLabel = '',
    Map<String, Object?> diagnostics = const {},
  }) async => thread;

  @override
  Future<List<SupportTicketThread>> listTickets({
    required HostPlatform hostPlatform,
    int limit = 5,
  }) async {
    listCalls++;
    return [thread];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
