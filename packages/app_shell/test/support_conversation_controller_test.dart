import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_first_runtime_bootstrap.dart';
import 'package:pokrov_app_shell/src/features/support/support_conversation_controller.dart';
import 'package:pokrov_core_domain/core_domain.dart';

void main() {
  test('loads the first open ticket and reuses it for a follow-up', () async {
    final service = _Tickets()
      ..listed = [_thread(1, closed: true), _thread(2), _thread(3)]
      ..current = _thread(2, body: '  Reply  ', role: 'support');
    final accepted = <String>[];
    final controller = _controller(service, accepted: accepted);
    addTearDown(controller.dispose);

    await controller.loadInitialThread();
    expect(service.readIds, [2]);
    expect(controller.ticketId, 2);
    expect(controller.lifecycle, SupportConversationLifecycle.operator);
    expect(controller.messages.single.body, 'Reply');
    expect(controller.messages.single.role, SupportChatRole.operator);

    service.current = _thread(2, body: 'Follow-up', role: 'user');
    await _send(controller, '  Follow-up  ');
    expect(service.sentIds, [2]);
    expect(service.createCalls, 0);
    expect(service.lastRouteMode, isNull);
    expect(service.lastStatus, isEmpty);
    expect(service.lastDiagnostics, isEmpty);
    expect(accepted, ['Follow-up']);
    expect(controller.messages.single.body, 'Follow-up');
  });

  test('failed send retains retry and removes only its pending bubble',
      () async {
    final service = _Tickets()..listed = [_thread(7)];
    final accepted = <String>[];
    final controller = _controller(service, accepted: accepted);
    addTearDown(controller.dispose);
    await controller.loadInitialThread();
    final before = controller.messages.toList();
    final response = Completer<SupportTicketThread>();
    service.sendResponse = response.future;

    final flight = _send(controller, 'Draft');
    await _send(controller, 'Duplicate');
    expect(controller.sending, isTrue);
    expect(service.sentIds, [7]);
    expect(controller.messages.last.body, 'Draft');
    response.completeError(StateError('synthetic offline'));
    await flight;
    expect(controller.messages, before);
    expect(controller.sendError, isNotNull);
    expect(accepted, isEmpty);

    service.sendResponse = null;
    service.current = _thread(7, body: 'Draft', role: 'user');
    await _send(controller, 'Draft');
    expect(controller.sendError, isNull);
    expect(controller.messages.where((message) => message.body == 'Draft'),
        hasLength(1));
    expect(accepted, ['Draft']);
  });

  test('ticket acknowledgement survives unavailable immediate readback',
      () async {
    final service = _Tickets();
    final accepted = <String>[];
    final controller = _controller(service, accepted: accepted);
    addTearDown(controller.dispose);
    await controller.loadInitialThread();
    service.readFailure = true;

    await _send(controller, 'New case', attach: true);
    expect(service.createCalls, 1);
    expect(service.lastDiagnostics, {'app_version': 'test'});
    expect(service.lastStatus, 'test-status');
    expect(accepted, ['New case']);
    expect(controller.ticketId, 7);
    expect(controller.sendError, isNull);
    expect(controller.messages.last.body, contains('#7'));

    service.readFailure = false;
    service.current = _thread(7, body: 'Next', role: 'user');
    await _send(controller, 'Next');
    expect(service.sentIds, [7]);
    expect(service.createCalls, 1);

    final error = await controller.submitFeedback(
      routeMode: RouteMode.fullTunnel,
      statusLabel: '',
      subject: 'Synthetic feedback',
      body: 'Feedback',
      diagnostics: const {},
    );
    expect(error, isNull);
    expect(service.createCalls, 2);
    expect(controller.messages.last.body, contains('отзыв #7'));
    expect(service.lastDiagnostics, isEmpty);
  });

  test('poll failures back off and explicit retry restores the active cadence',
      () async {
    final service = _Tickets()..listed = [_thread(7)];
    final timers = <_Timer>[];
    final controller = SupportConversationController(
      service: service,
      hostPlatform: HostPlatform.windows,
      foreground: false,
      timerFactory: (delay, callback) {
        final timer = _Timer(delay, callback);
        timers.add(timer);
        return timer;
      },
      jitterSource: () => 0,
    );
    addTearDown(controller.dispose);
    await controller.loadInitialThread();
    expect(timers, isEmpty);
    service.readFailure = true;
    controller.setForeground(true);
    await _settle();
    expect(controller.lifecycle, SupportConversationLifecycle.offline);
    expect(timers.where((timer) => timer.isActive), hasLength(1));
    expect(timers.last.delay, const Duration(seconds: 16));
    timers.last.fire();
    await _settle();
    expect(service.readIds, [7, 7, 7]);
    expect(timers.where((timer) => timer.isActive), hasLength(1));
    expect(timers.last.delay, const Duration(seconds: 32));

    service.readFailure = false;
    service.current = _thread(7, body: 'Operator update', role: 'operator');
    controller.retry();
    await _settle();
    expect(controller.lifecycle, SupportConversationLifecycle.operator);
    expect(timers.last.delay, const Duration(seconds: 8));
    controller.setForeground(false);
    final reads = service.readIds.length;
    for (final timer in timers) {
      timer.fire();
    }
    await _settle();
    expect(service.readIds.length, reads);
  });

  test('closing the controller ignores a late send response', () async {
    final service = _Tickets()..listed = [_thread(7)];
    final accepted = <String>[];
    final controller = _controller(service, accepted: accepted);
    await controller.loadInitialThread();
    final response = Completer<SupportTicketThread>();
    service.sendResponse = response.future;
    final flight = _send(controller, 'Pending');
    controller.dispose();
    response.complete(_thread(7, body: 'Pending', role: 'user'));
    await flight;
    expect(accepted, isEmpty);
  });
}

SupportConversationController _controller(_Tickets service,
        {required List<String> accepted}) =>
    SupportConversationController(
      service: service,
      hostPlatform: HostPlatform.windows,
      foreground: false,
      onMessageAccepted: accepted.add,
    );

Future<void> _send(SupportConversationController controller, String text,
        {bool attach = false}) =>
    controller.send(
      text: text,
      routeMode: RouteMode.fullTunnel,
      attachDiagnostics: attach,
      statusLabel: 'test-status',
      diagnostics: attach ? const {'app_version': 'test'} : const {},
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

SupportTicketThread _thread(int id,
        {bool closed = false, String body = '', String role = 'assistant'}) =>
    SupportTicketThread(
      id: id,
      status: closed ? 'closed' : 'open',
      statusTitle: '',
      subject: 'Synthetic case',
      createdAt: '',
      updatedAt: '',
      closedAt: '',
      lastMessagePreview: body,
      messages: body.isEmpty
          ? const []
          : [
              SupportTicketMessage(
                id: 1,
                ticketId: id,
                senderRole: role,
                body: body,
                mediaType: 'text',
                mediaFileId: '',
                mediaPayload: '',
                createdAt: '',
              ),
            ],
    );

class _Tickets implements SupportTicketService {
  List<SupportTicketThread> listed = [];
  SupportTicketThread current = _thread(7);
  final readIds = <int>[];
  final sentIds = <int>[];
  int createCalls = 0;
  bool readFailure = false;
  Future<SupportTicketThread>? sendResponse;
  RouteMode? lastRouteMode;
  String lastStatus = '';
  Map<String, Object?> lastDiagnostics = {};

  @override
  Future<List<SupportTicketThread>> listTickets(
          {required HostPlatform hostPlatform, int limit = 5}) async =>
      listed;

  @override
  Future<SupportTicketThread> getTicket(
      {required HostPlatform hostPlatform, required int ticketId}) async {
    readIds.add(ticketId);
    if (readFailure) throw StateError('synthetic offline');
    return current;
  }

  @override
  Future<SupportTicketReceipt> createTicket({
    required HostPlatform hostPlatform,
    required RouteMode routeMode,
    required String statusLabel,
    required String body,
    String subject = '',
    Map<String, Object?> diagnostics = const {},
  }) async {
    createCalls++;
    lastRouteMode = routeMode;
    lastStatus = statusLabel;
    lastDiagnostics = diagnostics;
    return const SupportTicketReceipt(
        ticketId: 7, statusTitle: '', messageCount: 1);
  }

  @override
  Future<SupportTicketThread> sendMessage({
    required HostPlatform hostPlatform,
    required int ticketId,
    required String body,
    RouteMode? routeMode,
    String statusLabel = '',
    Map<String, Object?> diagnostics = const {},
  }) async {
    sentIds.add(ticketId);
    lastRouteMode = routeMode;
    lastStatus = statusLabel;
    lastDiagnostics = diagnostics;
    final response = sendResponse;
    if (response != null) return await response;
    return current;
  }
}

class _Timer implements Timer {
  _Timer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool _active = true;
  @override
  bool get isActive => _active;
  @override
  int get tick => _active ? 0 : 1;
  @override
  void cancel() => _active = false;
  void fire() {
    if (_active) {
      _active = false;
      callback();
    }
  }
}
