part of pokrov_app_shell;

class _SupportChatScreen extends StatefulWidget {
  const _SupportChatScreen({
    required this.appContext,
    required this.selectedRouteMode,
    required this.statusLabel,
    required this.extraDiagnostics,
    required this.supportTicketService,
    required this.onOpenHandoff,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final String statusLabel;
  final Map<String, Object?> extraDiagnostics;
  final SupportTicketService supportTicketService;
  final void Function(String label, String value) onOpenHandoff;

  @override
  State<_SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<_SupportChatScreen> {
  static const _threadPollInterval = Duration(seconds: 10);

  late final TextEditingController _composer;
  late final FocusNode _composerFocusNode;
  Timer? _threadPollTimer;
  bool _sending = false;
  bool _loadingThread = true;
  bool _refreshingThread = false;
  bool _threadRefreshFailed = false;
  bool _threadClosed = false;
  bool _hasOperatorReply = false;
  int? _ticketId;
  String _threadStatus = 'Помощник POKROV';
  String? _threadError;
  List<_SupportChatMessage> _messages = _supportGreetingMessages();
  bool _attachDiagnosticsToNextMessage = false;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _composerFocusNode = FocusNode(debugLabel: 'support-composer');
    unawaited(_loadInitialThread());
  }

  @override
  void dispose() {
    _threadPollTimer?.cancel();
    _composerFocusNode.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadInitialThread() async {
    setState(() {
      _loadingThread = true;
      _threadError = null;
    });

    try {
      final tickets = await widget.supportTicketService.listTickets(
        hostPlatform: widget.appContext.hostPlatform,
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
        if (!mounted) {
          return;
        }
        setState(() {
          _ticketId = null;
          _threadClosed = false;
          _threadRefreshFailed = false;
          _hasOperatorReply = false;
          _loadingThread = false;
          _messages = _supportGreetingMessages();
          _threadStatus = 'Помощник POKROV';
        });
        _syncThreadPolling();
        return;
      }

      final thread = await widget.supportTicketService.getTicket(
        hostPlatform: widget.appContext.hostPlatform,
        ticketId: selected.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingThread = false;
        _applyThread(thread);
      });
      _syncThreadPolling();
    } on SupportTicketFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingThread = false;
        _threadClosed = false;
        _threadRefreshFailed = false;
        _hasOperatorReply = false;
        _threadError = error.message;
      });
      _syncThreadPolling();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingThread = false;
        _threadError = 'Не удалось загрузить историю поддержки.';
      });
    }
  }

  void _applyThread(SupportTicketThread thread) {
    _ticketId = thread.id;
    _threadClosed = thread.isClosed;
    _threadStatus =
        thread.statusTitle.isEmpty ? thread.status : thread.statusTitle;
    final nextMessages = _messagesFromThread(thread);
    _messages =
        nextMessages.isEmpty ? _supportGreetingMessages() : nextMessages;
    _hasOperatorReply = nextMessages
        .any((message) => message.role == _SupportChatRole.operator);
    _threadRefreshFailed = false;
  }

  void _syncThreadPolling() {
    _threadPollTimer?.cancel();
    _threadPollTimer = null;
    if (!mounted ||
        _ticketId == null ||
        _threadClosed ||
        _loadingThread ||
        _threadError != null) {
      return;
    }
    _threadPollTimer = Timer.periodic(
      _threadPollInterval,
      (_) => unawaited(_refreshActiveThread()),
    );
  }

  Future<void> _refreshActiveThread() async {
    final activeTicketId = _ticketId;
    if (activeTicketId == null ||
        _threadClosed ||
        _loadingThread ||
        _sending ||
        _refreshingThread) {
      return;
    }
    setState(() {
      _refreshingThread = true;
    });
    try {
      final thread = await widget.supportTicketService.getTicket(
        hostPlatform: widget.appContext.hostPlatform,
        ticketId: activeTicketId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _refreshingThread = false;
        _threadError = null;
        _applyThread(thread);
      });
      _syncThreadPolling();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _refreshingThread = false;
        _threadRefreshFailed = true;
      });
    }
  }

  _SupportLifecycleState get _supportLifecycleState {
    if (_loadingThread) {
      return _SupportLifecycleState.loading;
    }
    if (_threadError != null || _threadRefreshFailed) {
      return _SupportLifecycleState.offline;
    }
    if (_refreshingThread) {
      return _SupportLifecycleState.refreshing;
    }
    if (_threadClosed) {
      return _SupportLifecycleState.closed;
    }
    if (_hasOperatorReply) {
      return _SupportLifecycleState.operator;
    }
    if (_ticketId != null) {
      return _SupportLifecycleState.tracking;
    }
    return _SupportLifecycleState.ready;
  }

  void _retrySupportLifecycle() {
    if (_ticketId == null) {
      unawaited(_loadInitialThread());
      return;
    }
    setState(() {
      _threadRefreshFailed = false;
    });
    unawaited(_refreshActiveThread());
  }

  void _applyAssistantSuggestion(PokrovAssistantSuggestion suggestion) {
    setState(() {
      _composer.text = suggestion.prompt;
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending || _loadingThread) {
      return;
    }
    final attachDiagnostics = _attachDiagnosticsToNextMessage;
    final diagnostics =
        attachDiagnostics ? _supportDiagnostics() : const <String, Object?>{};
    setState(() {
      _messages
          .add(_SupportChatMessage(role: _SupportChatRole.user, body: text));
      _composer.clear();
      _sending = true;
    });

    try {
      final activeTicketId = _ticketId;
      if (activeTicketId != null) {
        final thread = await widget.supportTicketService.sendMessage(
          hostPlatform: widget.appContext.hostPlatform,
          ticketId: activeTicketId,
          body: text,
          routeMode: attachDiagnostics ? widget.selectedRouteMode : null,
          statusLabel: attachDiagnostics ? widget.statusLabel : '',
          diagnostics: diagnostics,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _sending = false;
          _attachDiagnosticsToNextMessage = false;
          _applyThread(thread);
        });
        _syncThreadPolling();
        return;
      }

      final receipt = await widget.supportTicketService.createTicket(
        hostPlatform: widget.appContext.hostPlatform,
        routeMode: widget.selectedRouteMode,
        statusLabel: widget.statusLabel,
        subject: 'Обращение из приложения POKROV',
        body: text,
        diagnostics: _supportDiagnostics(),
      );
      _ticketId = receipt.ticketId;
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _attachDiagnosticsToNextMessage = false;
        _messages.add(
          _SupportChatMessage(
            role: _SupportChatRole.assistant,
            label: 'Поддержка',
            body:
                'Обращение #${receipt.ticketId} создано. Ответ появится здесь; Telegram остается запасным каналом.',
          ),
        );
      });
      _syncThreadPolling();
      try {
        final thread = await widget.supportTicketService.getTicket(
          hostPlatform: widget.appContext.hostPlatform,
          ticketId: receipt.ticketId,
        );
        if (!mounted || thread.messages.isEmpty) {
          return;
        }
        setState(() {
          _applyThread(thread);
        });
        _syncThreadPolling();
      } catch (_) {
        // Keep the local confirmation when the immediate refresh is unavailable.
      }
    } on SupportTicketFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _messages.add(
          _SupportChatMessage(
            role: _SupportChatRole.assistant,
            body:
                'Не удалось отправить обращение: ${error.message}. Откройте Telegram сверху или попробуйте еще раз.',
          ),
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _messages.add(
          const _SupportChatMessage(
            role: _SupportChatRole.assistant,
            body:
                'Не удалось отправить обращение. Откройте Telegram сверху или попробуйте еще раз.',
          ),
        );
      });
    }
  }

  Map<String, Object?> _supportDiagnostics() {
    return <String, Object?>{
      'app_version': _pokrovAppVersion,
      'platform': widget.appContext.hostPlatform.name,
      'route_mode': widget.selectedRouteMode.name,
      'connection_status': widget.statusLabel,
      'selected_region': 'POKROV auto',
      ...widget.extraDiagnostics,
    };
  }

  List<_SupportChatMessage> _messagesFromThread(SupportTicketThread thread) {
    final messages = <_SupportChatMessage>[];
    for (final message in thread.messages) {
      final body = message.body.trim();
      if (body.isEmpty) {
        continue;
      }
      final role = _supportRoleFromSender(message.senderRole);
      messages.add(
        _SupportChatMessage(
          role: role,
          label: _supportLabelForRole(role),
          body: body,
        ),
      );
    }
    return messages;
  }

  _SupportChatRole _supportRoleFromSender(String senderRole) {
    final role = senderRole.toLowerCase();
    if (role == 'user') {
      return _SupportChatRole.user;
    }
    if (role == 'admin' || role == 'operator' || role == 'support') {
      return _SupportChatRole.operator;
    }
    return _SupportChatRole.assistant;
  }

  String _supportLabelForRole(_SupportChatRole role) {
    return switch (role) {
      _SupportChatRole.user => '',
      _SupportChatRole.operator => 'Поддержка',
      _SupportChatRole.assistant => 'Помощник POKROV',
    };
  }

  void _showDiagnosticsPreview() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _SeedPalette.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            key: const ValueKey('support-diagnostics-preview'),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Диагностика',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _KeyValueLine(
                  label: 'Устройство',
                  value: widget.appContext.hostPlatform.label,
                ),
                _KeyValueLine(
                  label: 'Режим',
                  value: widget.selectedRouteMode.label,
                ),
                _KeyValueLine(
                  label: 'Статус',
                  value: widget.statusLabel,
                ),
                _KeyValueLine(
                  label: 'Версия',
                  value: _pokrovAppVersion,
                ),
                const SizedBox(height: 10),
                Text(
                  'Мы прикрепим только безопасную сводку: устройство, режим, статус и версию.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const ValueKey('support-diagnostics-close'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Готово'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('support-diagnostics-attach-next'),
                      onPressed: () {
                        setState(() {
                          _attachDiagnosticsToNextMessage = true;
                        });
                        Navigator.of(context).maybePop();
                      },
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text('Прикрепить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      key: const ValueKey('support-chat-shortcuts'),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _FocusSupportComposerIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _SendSupportMessageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSupportComposerIntent:
              CallbackAction<_FocusSupportComposerIntent>(
            onInvoke: (_) {
              _composerFocusNode.requestFocus();
              return null;
            },
          ),
          _SendSupportMessageIntent: CallbackAction<_SendSupportMessageIntent>(
            onInvoke: (_) {
              if (!_sending && !_loadingThread) {
                unawaited(_sendMessage());
              }
              return null;
            },
          ),
        },
        child: Focus(
          key: const ValueKey('support-chat-focus-root'),
          autofocus: true,
          child: Scaffold(
            key: const ValueKey('support-chat-screen'),
            backgroundColor: _SeedPalette.canvas,
            appBar: AppBar(
              title: const Text('Чат поддержки'),
              actions: [
                IconButton(
                  key: const ValueKey('support-chat-telegram-fallback'),
                  tooltip: widget.appContext.supportSnapshot.supportBot,
                  onPressed: () => widget.onOpenHandoff(
                    'support',
                    widget.appContext.supportSnapshot.supportBot,
                  ),
                  icon: const Icon(Icons.send_outlined),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        child: _SupportChatHeader(
                          status: _loadingThread
                              ? 'Загружаем'
                              : _sending
                                  ? 'Отправляем'
                                  : _refreshingThread
                                      ? 'Обновляем чат'
                                      : _threadStatus,
                          details:
                              '${widget.appContext.hostPlatform.label} · ${widget.selectedRouteMode.label} · ${widget.statusLabel}',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: _SupportLifecycleHint(
                          state: _supportLifecycleState,
                          onRetry: _retrySupportLifecycle,
                        ),
                      ),
                      if (_threadError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: _SupportChatNotice(
                            body: _threadError!,
                            onRetry: () => unawaited(_loadInitialThread()),
                          ),
                        ),
                      Expanded(
                        child: _loadingThread
                            ? const _SupportChatSkeleton()
                            : ListView.builder(
                                key:
                                    const ValueKey('support-chat-message-list'),
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  return _SupportChatBubble(
                                    message: _messages[index],
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_loadingThread)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SupportAssistantSuggestions(
                                  suggestions: PokrovAssistantContract
                                      .defaultSupportSuggestions,
                                  onSelected: _applyAssistantSuggestion,
                                ),
                              ),
                            if (_attachDiagnosticsToNextMessage)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SupportDiagnosticsQueuedPill(
                                  onClear: () {
                                    setState(() {
                                      _attachDiagnosticsToNextMessage = false;
                                    });
                                  },
                                ),
                              ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: _SeedPalette.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _SeedPalette.line),
                                boxShadow: [
                                  BoxShadow(
                                    color: _SeedPalette.ink
                                        .withValues(alpha: 0.05),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    IconButton(
                                      key: const ValueKey(
                                        'support-attach-diagnostics',
                                      ),
                                      tooltip: 'Диагностика',
                                      icon:
                                          const Icon(Icons.attach_file_rounded),
                                      onPressed: _showDiagnosticsPreview,
                                    ),
                                    Expanded(
                                      child: TextField(
                                        key: const ValueKey(
                                          'support-chat-composer',
                                        ),
                                        controller: _composer,
                                        focusNode: _composerFocusNode,
                                        minLines: 1,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                          hintText: 'Напишите сообщение',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) =>
                                            unawaited(_sendMessage()),
                                      ),
                                    ),
                                    IconButton(
                                      key: const ValueKey('support-chat-send'),
                                      tooltip: 'Отправить',
                                      icon: _sending
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.send_rounded),
                                      onPressed: (_sending || _loadingThread)
                                          ? null
                                          : () => unawaited(_sendMessage()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportChatSkeleton extends StatelessWidget {
  const _SupportChatSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('support-chat-skeleton'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      children: const [
        PokrovSkeletonLine(width: 210, height: 12),
        SizedBox(height: 14),
        PokrovSkeletonLine(height: 72, radius: 16, opacity: 0.08),
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: PokrovSkeletonLine(width: 240, height: 64, radius: 16),
        ),
        SizedBox(height: 10),
        PokrovSkeletonLine(width: 280, height: 74, radius: 16, opacity: 0.08),
      ],
    );
  }
}

class _SupportDiagnosticsQueuedPill extends StatelessWidget {
  const _SupportDiagnosticsQueuedPill({
    required this.onClear,
  });

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('support-diagnostics-queued'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _SeedPalette.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _SeedPalette.accent.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: _SeedPalette.accent,
            ),
            const SizedBox(width: 6),
            Text(
              'Диагностика будет приложена',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _SeedPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('support-diagnostics-clear'),
              tooltip: 'Не прикладывать',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              constraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 26,
              ),
              padding: EdgeInsets.zero,
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                color: _SeedPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportAssistantSuggestions extends StatelessWidget {
  const _SupportAssistantSuggestions({
    required this.suggestions,
    required this.onSelected,
  });

  final List<PokrovAssistantSuggestion> suggestions;
  final ValueChanged<PokrovAssistantSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        key: const ValueKey('support-assistant-suggestions'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final suggestion in suggestions) ...[
              ActionChip(
                key: ValueKey(suggestion.key),
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(suggestion.title),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: _SeedPalette.line),
                backgroundColor: _SeedPalette.surface,
                onPressed: () => onSelected(suggestion),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SupportChatRole {
  user,
  assistant,
  operator,
}

class _SupportChatMessage {
  const _SupportChatMessage({
    required this.role,
    required this.body,
    this.label = '',
  });

  final _SupportChatRole role;
  final String body;
  final String label;
}

List<_SupportChatMessage> _supportGreetingMessages() {
  return <_SupportChatMessage>[
    _SupportChatMessage(
      role: _SupportChatRole.assistant,
      label: 'Помощник POKROV',
      body:
          'Напишите, что случилось. POKROV приложит только сведения о приложении и подключении, а ответ появится здесь.',
    ),
  ];
}

enum _SupportLifecycleState {
  loading,
  ready,
  tracking,
  refreshing,
  operator,
  closed,
  offline,
}

class _SupportLifecycleHint extends StatelessWidget {
  const _SupportLifecycleHint({
    required this.state,
    required this.onRetry,
  });

  final _SupportLifecycleState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = switch (state) {
      _SupportLifecycleState.loading => (
          key: 'loading',
          icon: Icons.sync_rounded,
          label: 'Загружаем чат',
          detail: 'История обращений появится здесь.',
          accent: _SeedPalette.muted,
          retry: false,
        ),
      _SupportLifecycleState.ready => (
          key: 'ready',
          icon: Icons.smart_toy_outlined,
          label: 'Помощник POKROV на связи',
          detail: 'Если вопрос не решится, к диалогу подключится оператор.',
          accent: _SeedPalette.muted,
          retry: false,
        ),
      _SupportLifecycleState.tracking => (
          key: 'tracking',
          icon: Icons.mark_chat_unread_outlined,
          label: 'Ответ появится здесь',
          detail: 'POKROV проверяет обращение. Telegram остается запасным.',
          accent: _SeedPalette.accent,
          retry: false,
        ),
      _SupportLifecycleState.refreshing => (
          key: 'refreshing',
          icon: Icons.sync_rounded,
          label: 'Обновляем чат',
          detail: 'Проверяем ответы, не открывая Telegram.',
          accent: _SeedPalette.accent,
          retry: false,
        ),
      _SupportLifecycleState.operator => (
          key: 'operator',
          icon: Icons.support_agent_rounded,
          label: 'Поддержка ответила',
          detail: 'Продолжайте диалог здесь или через Telegram.',
          accent: _SeedPalette.accent,
          retry: false,
        ),
      _SupportLifecycleState.closed => (
          key: 'closed',
          icon: Icons.check_circle_outline_rounded,
          label: 'Обращение закрыто',
          detail: 'Можно написать новое сообщение, если вопрос вернулся.',
          accent: _SeedPalette.success,
          retry: false,
        ),
      _SupportLifecycleState.offline => (
          key: 'offline',
          icon: Icons.cloud_off_outlined,
          label: 'Чат временно не обновился',
          detail:
              'Сообщения не потеряны. Можно повторить или открыть Telegram.',
          accent: _SeedPalette.warning,
          retry: true,
        ),
    };

    return Container(
      key: ValueKey('support-thread-lifecycle-${data.key}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 18, color: data.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          if (data.retry) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('support-thread-refresh-action'),
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportChatHeader extends StatelessWidget {
  const _SupportChatHeader({
    required this.status,
    required this.details,
  });

  final String status;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SeedPalette.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SeedPalette.accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _SeedPalette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: _SeedPalette.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _SeedPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _SeedPalette.muted,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportChatNotice extends StatelessWidget {
  const _SupportChatNotice({
    required this.body,
    required this.onRetry,
  });

  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _SeedPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SeedPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _SeedPalette.muted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _SeedPalette.muted,
                      height: 1.25,
                    ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportChatBubble extends StatelessWidget {
  const _SupportChatBubble({
    required this.message,
  });

  final _SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _SupportChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? _SeedPalette.accent : _SeedPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: _SeedPalette.line),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser && message.label.isNotEmpty) ...[
              Text(
                message.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _SeedPalette.muted,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? Colors.white : _SeedPalette.ink,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _consumerProtectionStatusLabel(
  RuntimeSnapshot? snapshot, {
  bool busy = false,
}) {
  if (busy) {
    return 'Подключаемся';
  }
  if (snapshot == null) {
    return 'Проверяем статус';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy ? 'Включено' : 'Нужно внимание';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Недоступно';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Можно подключаться';
  }
  return 'Готово';
}

String? _motionRecoveryNotice(
  RuntimeSnapshot? snapshot, {
  required String? headline,
  required bool busy,
}) {
  if (busy) {
    return null;
  }
  final text = (headline ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final normalized = text.toLowerCase();
  final looksRecoverable = normalized.contains('не смог') ||
      normalized.contains('не удалось') ||
      normalized.contains('ошиб') ||
      normalized.contains('отказ') ||
      normalized.contains('failed') ||
      normalized.contains('denied') ||
      normalized.contains('error') ||
      normalized.contains('недоступ');
  if (looksRecoverable) {
    return text;
  }
  if (snapshot != null &&
      snapshot.phase != RuntimePhase.running &&
      normalized.contains('подготов')) {
    return text;
  }
  if (snapshot != null && snapshot.phase != RuntimePhase.running) {
    return text;
  }
  return null;
}

String _consumerProtectionStatusSummary(
  RuntimeSnapshot? snapshot, {
  required String? headline,
  required HostPlatform hostPlatform,
}) {
  if ((headline ?? '').trim().isNotEmpty) {
    return headline!.trim();
  }
  if (snapshot == null) {
    return 'Проверяем, готово ли устройство ${hostPlatform.label}.';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy
        ? 'POKROV работает на этом устройстве.'
        : 'POKROV включен, но заметил состояние, которое стоит проверить.';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Устройство еще завершает подготовку перед подключением.';
  }
  if ((snapshot.stagedConfigPath ?? '').isNotEmpty) {
    return 'Все готово. Нажмите главную кнопку, чтобы подключиться.';
  }
  return 'POKROV готовит подключение в фоне, чтобы на первом экране осталась одна понятная кнопка.';
}
