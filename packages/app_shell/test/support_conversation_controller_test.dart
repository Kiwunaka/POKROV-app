import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/features/support/support_conversation_controller.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  test('support notice opens its exact closed ticket instead of the latest', () async {
    final service = _TicketService(_thread(id: 21, closed: true));
    final controller = SupportConversationController(
      service: service,
      hostPlatform: HostPlatform.windows,
      initialTicketId: 21,
    );
    addTearDown(controller.dispose);

    await controller.loadInitialThread();

    expect(service.requestedIds, [21]);
    expect(service.listCalls, 0);
    expect(controller.ticketId, 21);
    expect(controller.lifecycle, SupportConversationLifecycle.closed);
    expect(controller.messages.single.body, 'Initial message');
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
}

SupportTicketThread _thread({int id = 20, bool closed = false, bool reply = false}) {
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
    ],
  );
}

class _TicketService implements SupportTicketService {
  _TicketService(this.thread);

  SupportTicketThread thread;
  final requestedIds = <int>[];
  int listCalls = 0;

  @override
  Future<SupportTicketThread> getTicket({
    required HostPlatform hostPlatform,
    required int ticketId,
  }) async {
    requestedIds.add(ticketId);
    return thread;
  }

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
