import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pokrov_core_domain/core_domain.dart';

import '../../../app_first_runtime_bootstrap.dart';
import 'support_polling.dart';

/// Owns the ticket conversation, read/send lifecycle and polling eligibility.
/// The view retains composer, scrolling, dialogs and diagnostic consent.
class SupportConversationController extends ChangeNotifier {
  SupportConversationController({
    required SupportTicketService service,
    required HostPlatform hostPlatform,
    bool foreground = true,
    VoidCallback? onMessagesChanged,
    void Function(String)? onMessageAccepted,
    SupportPollingTimerFactory? timerFactory,
    SupportPollingJitterSource? jitterSource,
    SupportPollingClock? clock,
  })  : _service = service,
        _hostPlatform = hostPlatform,
        _supportPollingForeground = foreground,
        _onMessagesChanged = onMessagesChanged,
        _onMessageAccepted = onMessageAccepted {
    _threadPolling = SupportPollingCoordinator(
      onPoll: () => _refreshActiveThread(pollingOwned: true),
      timerFactory: timerFactory,
      jitterSource: jitterSource,
      clock: clock,
    );
  }

  final SupportTicketService _service;
  final HostPlatform _hostPlatform;
  final VoidCallback? _onMessagesChanged;
  final void Function(String)? _onMessageAccepted;
  late final SupportPollingCoordinator _threadPolling;
  bool _active = true;
  bool _supportPollingForeground;
  bool _sending = false;
  bool _loadingThread = true;
  bool _refreshingThread = false;
  bool _threadRefreshFailed = false;
  bool _threadClosed = false;
  bool _hasOperatorReply = false;
  int? _ticketId;
  String _threadVersion = '';
  String? _threadError;
  String? _sendError;
  List<SupportChatMessage> _messages = _supportGreetingMessages();

  bool get sending => _sending;
  bool get loadingThread => _loadingThread;
  int? get ticketId => _ticketId;
  String? get sendError => _sendError;
  List<SupportChatMessage> get messages => List.unmodifiable(_messages);

  void setForeground(bool foreground) {
    _supportPollingForeground = foreground;
    _syncThreadPolling();
  }

  void _change(VoidCallback update) {
    update();
    notifyListeners();
  }

  @override
  void dispose() {
    _active = false;
    _threadPolling.dispose();
    super.dispose();
  }

  Future<void> loadInitialThread() async {
    _change(() {
      _loadingThread = true;
      _threadError = null;
    });

    try {
      final tickets = await _service.listTickets(
        hostPlatform: _hostPlatform,
        limit: 5,
      );
      SupportTicketThread? selected;
      for (final ticket in tickets) {
        if (!ticket.isClosed) {
          selected = ticket;
          break;
        }
      }
      selected ??= tickets.isEmpty ? null : tickets.first;

      if (selected == null) {
        if (!_active) {
          return;
        }
        _change(() {
          _ticketId = null;
          _threadClosed = false;
          _threadRefreshFailed = false;
          _hasOperatorReply = false;
          _loadingThread = false;
          _messages = _supportGreetingMessages();
        });
        _syncThreadPolling();
        return;
      }

      final thread = await _service.getTicket(
        hostPlatform: _hostPlatform,
        ticketId: selected.id,
      );
      if (!_active) {
        return;
      }
      _change(() {
        _loadingThread = false;
        _applyThread(thread);
      });
      _syncThreadPolling();
    } on SupportTicketFailure catch (error) {
      if (!_active) {
        return;
      }
      _change(() {
        _loadingThread = false;
        _threadClosed = false;
        _threadRefreshFailed = false;
        _hasOperatorReply = false;
        _threadError = error.message;
      });
      _syncThreadPolling();
    } catch (_) {
      if (!_active) {
        return;
      }
      _change(() {
        _loadingThread = false;
        _threadError = 'Не удалось загрузить историю поддержки.';
      });
    }
  }

  bool _applyThread(SupportTicketThread thread) {
    final nextVersion = _supportThreadVersion(thread);
    final changed = _threadVersion.isNotEmpty && _threadVersion != nextVersion;
    _threadVersion = nextVersion;
    _ticketId = thread.id;
    _threadClosed = thread.isClosed;
    final nextMessages = _messagesFromThread(thread);
    _messages =
        nextMessages.isEmpty ? _supportGreetingMessages() : nextMessages;
    _hasOperatorReply = nextMessages.any(
      (message) => message.role == SupportChatRole.operator,
    );
    _threadRefreshFailed = false;
    return changed;
  }

  void _syncThreadPolling() {
    _threadPolling.configure(
      eligible: _active &&
          _ticketId != null &&
          !_threadClosed &&
          !_loadingThread &&
          !_sending &&
          !_refreshingThread &&
          _threadError == null,
      foreground: _supportPollingForeground,
    );
  }

  Future<SupportPollingResult> _refreshActiveThread({
    bool pollingOwned = false,
  }) async {
    final activeTicketId = _ticketId;
    if (activeTicketId == null ||
        _threadClosed ||
        _loadingThread ||
        _sending ||
        _refreshingThread) {
      return SupportPollingResult.unchanged;
    }
    _change(() {
      _refreshingThread = true;
    });
    _syncThreadPolling();
    try {
      final thread = await _service.getTicket(
        hostPlatform: _hostPlatform,
        ticketId: activeTicketId,
      );
      if (!_active) {
        return SupportPollingResult.failed;
      }
      var changed = false;
      _change(() {
        _refreshingThread = false;
        _threadError = null;
        changed = _applyThread(thread);
      });
      _syncThreadPolling();
      final result = changed
          ? SupportPollingResult.changed
          : SupportPollingResult.unchanged;
      if (!pollingOwned) {
        _threadPolling.recordExternalResult(result: result);
      }
      return result;
    } catch (_) {
      if (!_active) {
        return SupportPollingResult.failed;
      }
      _change(() {
        _refreshingThread = false;
        _threadRefreshFailed = true;
      });
      _syncThreadPolling();
      if (!pollingOwned) {
        _threadPolling.recordExternalResult(
          result: SupportPollingResult.failed,
        );
      }
      return SupportPollingResult.failed;
    }
  }

  SupportConversationLifecycle get lifecycle {
    if (_loadingThread) {
      return SupportConversationLifecycle.loading;
    }
    if (_threadError != null || _threadRefreshFailed) {
      return SupportConversationLifecycle.offline;
    }
    if (_refreshingThread) {
      return SupportConversationLifecycle.refreshing;
    }
    if (_threadClosed) {
      return SupportConversationLifecycle.closed;
    }
    if (_hasOperatorReply) {
      return SupportConversationLifecycle.operator;
    }
    if (_ticketId != null) {
      return SupportConversationLifecycle.tracking;
    }
    return SupportConversationLifecycle.ready;
  }

  void retry() {
    if (_ticketId == null) {
      unawaited(loadInitialThread());
      return;
    }
    _change(() {
      _threadRefreshFailed = false;
    });
    unawaited(_refreshActiveThread());
  }

  Future<void> send({
    required String text,
    required RouteMode routeMode,
    required bool attachDiagnostics,
    required String statusLabel,
    required Map<String, Object?> diagnostics,
  }) async {
    text = text.trim();
    if (text.isEmpty || _sending || _loadingThread) {
      return;
    }
    final pendingMessage = SupportChatMessage(
      role: SupportChatRole.user,
      body: text,
    );
    _change(() {
      _sendError = null;
      _messages.add(pendingMessage);
      _sending = true;
    });
    _syncThreadPolling();
    _onMessagesChanged?.call();

    try {
      final activeTicketId = _ticketId;
      if (activeTicketId != null) {
        final thread = await _service.sendMessage(
          hostPlatform: _hostPlatform,
          ticketId: activeTicketId,
          body: text,
          routeMode: attachDiagnostics ? routeMode : null,
          statusLabel: attachDiagnostics ? statusLabel : '',
          diagnostics: diagnostics,
        );
        if (!_active) {
          return;
        }
        _onMessageAccepted?.call(text);
        _change(() {
          _sending = false;
          _threadError = null;
          _applyThread(thread);
        });
        _onMessagesChanged?.call();
        _syncThreadPolling();
        return;
      }

      final receipt = await _service.createTicket(
        hostPlatform: _hostPlatform,
        routeMode: routeMode,
        statusLabel: attachDiagnostics ? statusLabel : '',
        subject: 'Обращение из приложения POKROV',
        body: text,
        diagnostics: diagnostics,
      );
      _ticketId = receipt.ticketId;
      if (!_active) {
        return;
      }
      _onMessageAccepted?.call(text);
      _change(() {
        _sending = false;
        _threadError = null;
        _threadRefreshFailed = false;
        _messages.add(
          SupportChatMessage(
            role: SupportChatRole.assistant,
            label: 'Поддержка',
            body:
                'Обращение #${receipt.ticketId} создано. Ответ появится прямо в этом чате.',
          ),
        );
      });
      _onMessagesChanged?.call();
      _syncThreadPolling();
      try {
        final thread = await _service.getTicket(
          hostPlatform: _hostPlatform,
          ticketId: receipt.ticketId,
        );
        if (!_active || thread.messages.isEmpty) {
          return;
        }
        _change(() {
          _applyThread(thread);
        });
        _onMessagesChanged?.call();
        _syncThreadPolling();
      } catch (_) {
        // Keep the local confirmation when the immediate refresh is unavailable.
      }
    } catch (_) {
      if (!_active) {
        return;
      }
      _change(() {
        _sending = false;
        _messages.remove(pendingMessage);
        _sendError = 'Сообщение не отправлено. Проверьте интернет и повторите.';
      });
      _syncThreadPolling();
    }
  }

  List<SupportChatMessage> _messagesFromThread(SupportTicketThread thread) {
    final messages = <SupportChatMessage>[];
    for (final message in thread.messages) {
      final body = message.body.trim();
      if (body.isEmpty) {
        continue;
      }
      final role = _supportRoleFromSender(message.senderRole);
      messages.add(
        SupportChatMessage(
          role: role,
          label: _supportLabelForRole(role),
          body: body,
        ),
      );
    }
    return messages;
  }

  String _supportThreadVersion(SupportTicketThread thread) {
    final buffer = StringBuffer();

    void writeField(Object value) {
      final text = value.toString();
      buffer
        ..write(text.length)
        ..write(':')
        ..write(text);
    }

    writeField(thread.id);
    writeField(thread.status);
    writeField(thread.statusTitle);
    writeField(thread.updatedAt);
    writeField(thread.closedAt);
    writeField(thread.lastMessagePreview);
    for (final message in thread.messages) {
      writeField(message.id);
      writeField(message.senderRole);
      writeField(message.body);
      writeField(message.mediaType);
      writeField(message.createdAt);
    }
    return buffer.toString();
  }

  SupportChatRole _supportRoleFromSender(String senderRole) {
    final role = senderRole.toLowerCase();
    if (role == 'user') {
      return SupportChatRole.user;
    }
    if (role == 'admin' || role == 'operator' || role == 'support') {
      return SupportChatRole.operator;
    }
    return SupportChatRole.assistant;
  }

  String _supportLabelForRole(SupportChatRole role) {
    return switch (role) {
      SupportChatRole.user => '',
      SupportChatRole.operator => 'Поддержка',
      SupportChatRole.assistant => 'Помощник POKROV',
    };
  }

  Future<String?> submitFeedback({
    required RouteMode routeMode,
    required String statusLabel,
    required String subject,
    required String body,
    required Map<String, Object?> diagnostics,
  }) async {
    if (_sending) {
      return 'Дождитесь отправки текущего сообщения.';
    }
    try {
      final receipt = await _service.createTicket(
        hostPlatform: _hostPlatform,
        routeMode: routeMode,
        statusLabel: statusLabel,
        subject: subject,
        body: body,
        diagnostics: diagnostics,
      );
      if (!_active) {
        return null;
      }
      _change(() {
        _ticketId = receipt.ticketId;
        _threadClosed = false;
        _threadRefreshFailed = false;
        _threadError = null;
        _messages.add(
          SupportChatMessage(
            role: SupportChatRole.assistant,
            label: 'Поддержка',
            body:
                'Спасибо — отзыв #${receipt.ticketId} отправлен. Ответ, если он понадобится, появится в этом чате.',
          ),
        );
      });
      _onMessagesChanged?.call();
      _syncThreadPolling();
      return null;
    } catch (_) {
      return 'Не удалось отправить отзыв. Проверьте интернет и повторите.';
    }
  }
}

enum SupportChatRole { user, assistant, operator }

class SupportChatMessage {
  const SupportChatMessage({
    required this.role,
    required this.body,
    this.label = '',
  });

  final SupportChatRole role;
  final String body;
  final String label;
}

List<SupportChatMessage> _supportGreetingMessages() {
  return <SupportChatMessage>[
    SupportChatMessage(
      role: SupportChatRole.assistant,
      label: 'Помощник POKROV',
      body:
          'Напишите, что случилось. POKROV приложит только сведения о приложении и подключении, а ответ появится здесь.',
    ),
  ];
}

enum SupportConversationLifecycle {
  loading,
  ready,
  tracking,
  refreshing,
  operator,
  closed,
  offline,
}
