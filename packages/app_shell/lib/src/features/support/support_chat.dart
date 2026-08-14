part of pokrov_app_shell;

class _SupportChatScreen extends StatefulWidget {
  const _SupportChatScreen({
    required this.appContext,
    required this.selectedRouteMode,
    required this.statusLabel,
    required this.extraDiagnostics,
    required this.supportTicketService,
    required this.askAssistant,
    required this.onOpenHandoff,
    required this.promoSlot,
    required this.onPromoEvent,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final String statusLabel;
  final Map<String, Object?> extraDiagnostics;
  final SupportTicketService supportTicketService;

  /// Knowledge-base question -> answer lane for the AI assistant sheet.
  /// `null` hides the entry point (no client data service available).
  final Future<ClientSupportAssistantReply> Function(
    String message,
    String? assistantSessionId,
  )? askAssistant;
  final void Function(String label, String value) onOpenHandoff;
  final AppFirstPromoSlot? promoSlot;
  final void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent;

  @override
  State<_SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<_SupportChatScreen> {
  static const _threadPollInterval = Duration(seconds: 10);

  late final TextEditingController _composer;
  late final FocusNode _composerFocusNode;
  late final ScrollController _messageListController;
  Timer? _threadPollTimer;
  bool _sending = false;
  bool _loadingThread = true;
  bool _refreshingThread = false;
  bool _threadRefreshFailed = false;
  bool _threadClosed = false;
  bool _hasOperatorReply = false;
  int? _ticketId;
  String? _threadError;
  String? _sendError;
  List<_SupportChatMessage> _messages = _supportGreetingMessages();
  bool _attachDiagnosticsToNextMessage = false;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _composerFocusNode = FocusNode(debugLabel: 'support-composer');
    _messageListController = ScrollController(
      debugLabel: 'support-message-list',
    );
    unawaited(_loadInitialThread());
  }

  @override
  void dispose() {
    _threadPollTimer?.cancel();
    _composerFocusNode.dispose();
    _messageListController.dispose();
    _composer.dispose();
    super.dispose();
  }

  /// Keeps the freshly appended message visible: after the frame with the
  /// new bubble is laid out, the list settles to its end. Respects reduced
  /// motion by jumping instead of animating.
  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageListController.hasClients) {
        return;
      }
      final target = _messageListController.position.maxScrollExtent;
      if (PokrovMotionScope.of(context).disableAnimations) {
        _messageListController.jumpTo(target);
        return;
      }
      unawaited(
        _messageListController.animateTo(
          target,
          duration: _MotionTokens.standard,
          curve: _MotionTokens.ease,
        ),
      );
    });
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
    final nextMessages = _messagesFromThread(thread);
    _messages =
        nextMessages.isEmpty ? _supportGreetingMessages() : nextMessages;
    _hasOperatorReply = nextMessages.any(
      (message) => message.role == _SupportChatRole.operator,
    );
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

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending || _loadingThread) {
      return;
    }
    final pendingMessage = _SupportChatMessage(
      role: _SupportChatRole.user,
      body: text,
    );
    final attachDiagnostics = _attachDiagnosticsToNextMessage;
    final diagnostics =
        attachDiagnostics ? _supportDiagnostics() : const <String, Object?>{};
    setState(() {
      _sendError = null;
      _messages.add(pendingMessage);
      _sending = true;
    });
    _scrollToLatestMessage();

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
        _clearComposerAfterSend(text);
        setState(() {
          _sending = false;
          _threadError = null;
          _attachDiagnosticsToNextMessage = false;
          _applyThread(thread);
        });
        _scrollToLatestMessage();
        _syncThreadPolling();
        return;
      }

      final receipt = await widget.supportTicketService.createTicket(
        hostPlatform: widget.appContext.hostPlatform,
        routeMode: widget.selectedRouteMode,
        statusLabel: attachDiagnostics ? widget.statusLabel : '',
        subject: 'Обращение из приложения POKROV',
        body: text,
        diagnostics: diagnostics,
      );
      _ticketId = receipt.ticketId;
      if (!mounted) {
        return;
      }
      _clearComposerAfterSend(text);
      setState(() {
        _sending = false;
        _threadError = null;
        _threadRefreshFailed = false;
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
      _scrollToLatestMessage();
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
        _scrollToLatestMessage();
        _syncThreadPolling();
      } catch (_) {
        // Keep the local confirmation when the immediate refresh is unavailable.
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _messages.remove(pendingMessage);
        _sendError = 'Сообщение не отправлено. Проверьте интернет и повторите.';
      });
    }
  }

  /// The draft is cleared only after the backend accepted the message, so a
  /// failed send never loses the typed text. If the user already typed a new
  /// draft while the send was in flight, that draft is preserved too.
  void _clearComposerAfterSend(String sentText) {
    if (_composer.text.trim() == sentText) {
      _composer.clear();
    }
  }

  Map<String, Object?> _supportDiagnostics() {
    return <String, Object?>{
      'app_version': pokrovClientVersion,
      'platform': widget.appContext.hostPlatform.name,
      'route_mode': widget.selectedRouteMode.name,
      'connection_status': widget.statusLabel,
      'warp_status': _safeWarpSummary(),
    };
  }

  String _safeWarpSummary() {
    final consented = widget.extraDiagnostics['enhanced_protection_consent'];
    final available = widget.extraDiagnostics['enhanced_protection_available'];
    final state = (widget.extraDiagnostics['enhanced_protection_state'] ?? '')
        .toString()
        .trim();
    if (consented == true) {
      return 'Включен';
    }
    if (available == true) {
      return 'Можно включить';
    }
    if (state.isNotEmpty && state != 'hidden') {
      return 'Проверяется';
    }
    return 'Не включен';
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

  /// Opens the AI mini chat sheet. When the user picks the human escape row
  /// inside, the sheet closes and focus lands on the existing ticket
  /// composer so escalation stays one motion away.
  Future<void> _openAssistantSheet() async {
    final askAssistant = widget.askAssistant;
    if (askAssistant == null) {
      return;
    }
    PokrovHaptics.tap();
    var escalated = false;
    var diagnosticsRequested = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      builder: (sheetContext) {
        return _AssistantChatSheet(
          askAssistant: askAssistant,
          onEscalate: () {
            escalated = true;
            Navigator.of(sheetContext).maybePop();
          },
          onAttachDiagnostics: () {
            diagnosticsRequested = true;
            Navigator.of(sheetContext).maybePop();
          },
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (diagnosticsRequested) {
      _showDiagnosticsPreview();
    } else if (escalated) {
      _composerFocusNode.requestFocus();
    }
  }

  void _showDiagnosticsPreview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      builder: (context) {
        final p = PokrovPalette.of(context);
        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: Padding(
                  key: const ValueKey('support-diagnostics-preview'),
                  padding: EdgeInsets.fromLTRB(
                    22,
                    4,
                    22,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Что отправим',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _KeyValueLine(
                                label: 'Устройство',
                                value: widget.appContext.hostPlatform.label,
                              ),
                              _KeyValueLine(
                                label: 'Режим',
                                value: _routeModeShortLabel(
                                  widget.selectedRouteMode,
                                ),
                              ),
                              _KeyValueLine(
                                label: 'Статус VPN',
                                value: widget.statusLabel,
                              ),
                              _KeyValueLine(
                                label: 'Версия',
                                value: pokrovClientVersion,
                              ),
                              _KeyValueLine(
                                label: 'WARP',
                                value: _safeWarpSummary(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Прикрепим только краткую безопасную сводку: устройство, версию приложения, статус VPN, режим и WARP.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: p.muted, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            key: const ValueKey('support-diagnostics-close'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Отмена'),
                          ),
                          FilledButton.icon(
                            key: const ValueKey(
                              'support-diagnostics-attach-next',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () {
                              setState(() {
                                _attachDiagnosticsToNextMessage = true;
                              });
                              Navigator.of(context).maybePop();
                            },
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              size: 18,
                            ),
                            label: const Text('Прикрепить к сообщению'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
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
            backgroundColor: p.canvas,
            appBar: AppBar(title: const Text('Поддержка')),
            body: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          key: const ValueKey('support-chat-message-list'),
                          controller: _messageListController,
                          padding: EdgeInsets.zero,
                          children: [
                            if (widget.promoSlot != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 8, 18, 12),
                                child: _HomeAdminPromoCard(
                                  slot: widget.promoSlot!,
                                  keyPrefix: 'support-promo',
                                  onOpenHandoff: widget.onOpenHandoff,
                                  onPromoEvent: widget.onPromoEvent,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                              child: _SupportLifecycleHint(
                                state: _supportLifecycleState,
                                onRetry: _retrySupportLifecycle,
                              ),
                            ),
                            if (widget.askAssistant != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                child: _SupportAiFirstCard(
                                  onTap: () => unawaited(_openAssistantSheet()),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const ValueKey(
                                    'support-feedback-bot-action',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    alignment: Alignment.centerLeft,
                                  ),
                                  onPressed: () => widget.onOpenHandoff(
                                    'support',
                                    widget
                                        .appContext.supportSnapshot.supportBot,
                                  ),
                                  icon:
                                      const Icon(Icons.send_rounded, size: 19),
                                  label: const Text(
                                    'Feedback-бот в Telegram',
                                  ),
                                ),
                              ),
                            ),
                            if (_loadingThread)
                              const SizedBox(
                                height: 230,
                                child: _SupportChatSkeleton(),
                              )
                            else
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                child: Column(
                                  children: [
                                    for (final message in _messages)
                                      _SupportChatBubble(message: message),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_sendError case final sendError?)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SupportRetryNotice(
                                  key: const ValueKey(
                                    'support-send-failure-notice',
                                  ),
                                  message: sendError,
                                  retryKey: const ValueKey(
                                    'support-send-retry',
                                  ),
                                  onRetry: _sending
                                      ? null
                                      : () => unawaited(_sendMessage()),
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
                                color: p.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: p.line),
                                boxShadow: [
                                  BoxShadow(
                                    color: p.ink.withValues(alpha: 0.05),
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
                                      icon: const Icon(
                                        Icons.attach_file_rounded,
                                      ),
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
                                          hintText: 'Сообщение человеку',
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

class _SupportAiFirstCard extends StatelessWidget {
  const _SupportAiFirstCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Semantics(
      button: true,
      label: 'Сначала спросить ИИ-помощника',
      child: PokrovSettingsRowPressSurface(
        key: const ValueKey('support-ai-first-card'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: p.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сначала спросить ИИ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Проверит WARP, локацию, маршруты и системные разрешения. Если не поможет — человек.',
                      key: const ValueKey('support-ai-first-description'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.muted,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: p.accent),
            ],
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
    return PokrovSkeletonPulse(
      child: ListView(
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
      ),
    );
  }
}

class _SupportDiagnosticsQueuedPill extends StatelessWidget {
  const _SupportDiagnosticsQueuedPill({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('support-diagnostics-queued'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.accent.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: p.accent),
            const SizedBox(width: 6),
            Text(
              'Диагностика будет приложена',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('support-diagnostics-clear'),
              tooltip: 'Не прикладывать',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: EdgeInsets.zero,
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SupportChatRole { user, assistant, operator }

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
  const _SupportLifecycleHint({required this.state, required this.onRetry});

  final _SupportLifecycleState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final data = switch (state) {
      _SupportLifecycleState.loading => (
          key: 'loading',
          icon: Icons.sync_rounded,
          label: 'Загружаем переписку',
          accent: p.muted,
          retry: false,
        ),
      _SupportLifecycleState.ready => (
          key: 'ready',
          icon: Icons.smart_toy_outlined,
          label: 'Чат с человеком · ответим здесь',
          accent: p.muted,
          retry: false,
        ),
      _SupportLifecycleState.tracking => (
          key: 'tracking',
          icon: Icons.mark_chat_unread_outlined,
          label: 'Открыто · человек ответит здесь',
          accent: p.accent,
          retry: false,
        ),
      _SupportLifecycleState.refreshing => (
          key: 'refreshing',
          icon: Icons.sync_rounded,
          label: 'Проверяем новые ответы',
          accent: p.accent,
          retry: false,
        ),
      _SupportLifecycleState.operator => (
          key: 'operator',
          icon: Icons.support_agent_rounded,
          label: 'Поддержка ответила',
          accent: p.accent,
          retry: false,
        ),
      _SupportLifecycleState.closed => (
          key: 'closed',
          icon: Icons.check_circle_outline_rounded,
          label: 'Обращение закрыто',
          accent: p.success,
          retry: false,
        ),
      _SupportLifecycleState.offline => (
          key: 'offline',
          icon: Icons.cloud_off_outlined,
          label: 'Чат временно не обновился',
          accent: p.warning,
          retry: true,
        ),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: ValueKey('support-thread-lifecycle-${data.key}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: data.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: data.accent.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 16, color: data.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (data.retry) ...[
              const SizedBox(width: 6),
              TextButton(
                key: const ValueKey('support-thread-refresh-action'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupportRetryNotice extends StatelessWidget {
  const _SupportRetryNotice({
    super.key,
    required this.message,
    required this.retryKey,
    required this.onRetry,
  });

  final String message;
  final Key retryKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: p.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: p.muted, height: 1.25),
                ),
              ),
              TextButton(
                key: retryKey,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportChatBubble extends StatelessWidget {
  const _SupportChatBubble({required this.message});

  final _SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final isUser = message.role == _SupportChatRole.user;
    // Automation bubbles share one visual language with the AI sheet: the
    // mint tone plus the small sparkle badge keep it honest that no human
    // wrote this text. Operator replies stay on the neutral surface.
    final isAutomation = message.role == _SupportChatRole.assistant &&
        message.label == 'Помощник POKROV';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? p.accent
              : isAutomation
                  ? p.accentSoft
                  : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: isUser
              ? null
              : Border.all(
                  color:
                      isAutomation ? p.accent.withValues(alpha: 0.14) : p.line,
                ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser && message.label.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAutomation) ...[
                    const _PokrovAiBadge(),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    message.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: p.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser
                        ? Theme.of(context).colorScheme.onPrimary
                        : p.ink,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small sparkle badge that marks machine-written replies. One shared widget
/// keeps the ticket chat and the AI sheet visually honest in the same way.
class _PokrovAiBadge extends StatelessWidget {
  const _PokrovAiBadge();

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 11, color: p.accent),
          const SizedBox(width: 4),
          Text(
            'ИИ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: p.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

/// Honest AI mini chat over the POKROV knowledge base. The header names the
/// automation, the escape row to a human stays pinned below the composer,
/// and a missing answer is admitted instead of improvised.
class _AssistantChatSheet extends StatefulWidget {
  const _AssistantChatSheet({
    required this.askAssistant,
    required this.onEscalate,
    required this.onAttachDiagnostics,
  });

  final Future<ClientSupportAssistantReply> Function(
    String message,
    String? assistantSessionId,
  ) askAssistant;
  final VoidCallback onEscalate;
  final VoidCallback onAttachDiagnostics;

  @override
  State<_AssistantChatSheet> createState() => _AssistantChatSheetState();
}

class _AssistantChatSheetState extends State<_AssistantChatSheet> {
  static const _noAnswerFallback =
      'Не нашёл ответа. Напишите в поддержку — ответит человек.';

  late final TextEditingController _composer;
  late final FocusNode _composerFocusNode;
  late final ScrollController _listController;
  final List<PokrovAssistantMessage> _messages = <PokrovAssistantMessage>[];
  String? _assistantSessionId;
  String? _failedQuestion;
  bool _thinking = false;
  bool _shouldEscalate = false;
  int _messageSeq = 0;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _composerFocusNode = FocusNode(debugLabel: 'assistant-sheet-composer');
    _listController = ScrollController(
      debugLabel: 'assistant-sheet-message-list',
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    _composerFocusNode.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) {
        return;
      }
      _listController.jumpTo(_listController.position.maxScrollExtent);
    });
  }

  Future<void> _send({String? retryQuestion}) async {
    final isRetry = retryQuestion != null;
    final text = (retryQuestion ?? _composer.text).trim();
    if (text.isEmpty || _thinking) {
      return;
    }
    PokrovHaptics.tap();
    setState(() {
      _failedQuestion = null;
      if (!isRetry) {
        _messageSeq += 1;
        _messages.add(
          PokrovAssistantMessage(
            id: 'user-$_messageSeq',
            role: PokrovAssistantRole.user,
            body: text,
          ),
        );
      }
      _thinking = true;
    });
    if (!isRetry) {
      _composer.clear();
    }
    _scrollToLatest();

    var answer = _noAnswerFallback;
    var answerLabel = ClientSupportAssistantSource.localFallback.consumerLabel;
    final attemptedAssistantSessionId = _assistantSessionId;
    String? returnedAssistantSessionId;
    var shouldEscalate = false;
    var actions = const <PokrovAssistantSafeAction>[];
    try {
      final reply = await widget.askAssistant(
        text,
        attemptedAssistantSessionId,
      );
      returnedAssistantSessionId = reply.assistantSessionId;
      answerLabel = reply.source.consumerLabel;
      shouldEscalate = reply.shouldEscalate;
      actions = _supportAssistantActions(reply.suggestedActions);
      final body = reply.reply.trim();
      if (body.isNotEmpty) {
        answer = body;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (attemptedAssistantSessionId != null) {
          _assistantSessionId = null;
        }
        _thinking = false;
        _failedQuestion = text;
      });
      _scrollToLatest();
      return;
    }
    if (!mounted) {
      return;
    }
    _messageSeq += 1;
    setState(() {
      if (returnedAssistantSessionId != null) {
        _assistantSessionId = returnedAssistantSessionId;
      }
      _thinking = false;
      _shouldEscalate = shouldEscalate;
      _messages.add(
        PokrovAssistantMessage.assistant(
          id: 'assistant-$_messageSeq',
          body: answer,
          sourceLabel: answerLabel,
          actions: actions,
        ),
      );
    });
    _scrollToLatest();
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - bottomInset;
    final maxHeight =
        availableHeight > 320 ? availableHeight * 0.85 : availableHeight;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            key: const ValueKey('support-assistant-sheet'),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ИИ-помощник',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'WARP, локации, маршруты и системные разрешения',
                            maxLines: 2,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: p.muted, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    key: const ValueKey('assistant-sheet-message-list'),
                    controller: _listController,
                    shrinkWrap: true,
                    children: [
                      for (final message in _messages)
                        _AssistantSheetBubble(
                          message: message,
                          onAction: _activateAction,
                        ),
                      if (_thinking) const _AssistantThinkingStatus(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_failedQuestion case final failedQuestion?) ...[
                  _SupportRetryNotice(
                    key: const ValueKey(
                      'assistant-request-failure-notice',
                    ),
                    message:
                        'Ответ не загрузился. Проверьте интернет и повторите.',
                    retryKey: const ValueKey('assistant-request-retry'),
                    onRetry: _thinking
                        ? null
                        : () => unawaited(
                              _send(retryQuestion: failedQuestion),
                            ),
                  ),
                  const SizedBox(height: 8),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: p.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('assistant-sheet-composer'),
                            controller: _composer,
                            focusNode: _composerFocusNode,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              hintText: 'Напишите вопрос',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => unawaited(_send()),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('assistant-sheet-send'),
                          tooltip: 'Отправить',
                          onPressed:
                              _thinking ? null : () => unawaited(_send()),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (_shouldEscalate)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('assistant-sheet-escalate'),
                      onPressed: _openHumanSupport,
                      icon: const Icon(Icons.support_agent_rounded, size: 18),
                      label: const Text('Передать в поддержку'),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('assistant-sheet-escalate'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: p.muted,
                      ),
                      onPressed: _openHumanSupport,
                      icon: const Icon(Icons.support_agent_outlined, size: 18),
                      label: const Text('Нужен человек'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openHumanSupport() {
    PokrovHaptics.tap();
    widget.onEscalate();
  }

  void _activateAction(PokrovAssistantSafeAction action) {
    PokrovHaptics.tap();
    switch (action.effect) {
      case PokrovAssistantSafeActionEffect.attachDiagnostics:
        widget.onAttachDiagnostics();
        return;
      case PokrovAssistantSafeActionEffect.openHandoff:
        widget.onEscalate();
        return;
      case PokrovAssistantSafeActionEffect.none:
      case PokrovAssistantSafeActionEffect.navigate:
        final prompt = switch (action.key) {
          'retry_connect' => 'Как безопасно переподключить POKROV?',
          'open_subscription' => 'Как проверить доступ и подписку?',
          _ => '',
        };
        if (prompt.isNotEmpty && !_thinking) {
          _composer.text = prompt;
          unawaited(_send());
        }
        return;
    }
  }
}

class _AssistantSheetBubble extends StatelessWidget {
  const _AssistantSheetBubble({
    required this.message,
    required this.onAction,
  });

  final PokrovAssistantMessage message;
  final ValueChanged<PokrovAssistantSafeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final isUser = message.role == PokrovAssistantRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? p.accent : p.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: isUser
              ? null
              : Border.all(color: p.accent.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const _PokrovAiBadge(),
              const SizedBox(height: 6),
              if (message.sourceLabel case final sourceLabel?) ...[
                Text(
                  sourceLabel,
                  key: const ValueKey('assistant-response-source-label'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
              ],
            ],
            if (isUser)
              Text(
                message.safeBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      height: 1.3,
                    ),
              )
            else
              _AssistantAnswerBody(
                key: ValueKey('assistant-answer-${message.id}'),
                body: message.safeBody,
              ),
            if (!isUser && message.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AssistantActionChips(
                actions: message.actions,
                onAction: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssistantActionChips extends StatelessWidget {
  const _AssistantActionChips({
    required this.actions,
    required this.onAction,
  });

  final List<PokrovAssistantSafeAction> actions;
  final ValueChanged<PokrovAssistantSafeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final visibleActions = actions
        .where(
          (action) =>
              action.effect != PokrovAssistantSafeActionEffect.openHandoff,
        )
        .toList(growable: false);
    if (visibleActions.isEmpty) {
      return const SizedBox.shrink();
    }
    final p = PokrovPalette.of(context);
    return Wrap(
      key: const ValueKey('assistant-response-actions'),
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final action in visibleActions)
          ActionChip(
            key: ValueKey('assistant-action-${action.key}'),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: p.accent.withValues(alpha: 0.18)),
            backgroundColor: p.surface,
            avatar: Icon(
              action.effect == PokrovAssistantSafeActionEffect.attachDiagnostics
                  ? Icons.attach_file_rounded
                  : Icons.arrow_forward_rounded,
              size: 16,
              color: p.accent,
            ),
            label: Text(action.label),
            onPressed: () => onAction(action),
          ),
      ],
    );
  }
}

List<PokrovAssistantSafeAction> _supportAssistantActions(
  List<ClientSupportAssistantAction> suggestedActions,
) {
  final actions = <PokrovAssistantSafeAction>[];
  final seen = <String>{};
  for (final suggestedAction in suggestedActions) {
    final key = suggestedAction.key.trim().toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    final action = switch (key) {
      'retry_connect' => const PokrovAssistantSafeAction(
          key: 'retry_connect',
          label: 'Как переподключить',
          effect: PokrovAssistantSafeActionEffect.none,
        ),
      'send_diagnostics' => const PokrovAssistantSafeAction(
          key: 'send_diagnostics',
          label: 'Приложить диагностику',
          effect: PokrovAssistantSafeActionEffect.attachDiagnostics,
        ),
      'open_subscription' => const PokrovAssistantSafeAction(
          key: 'open_subscription',
          label: 'Проверить доступ',
          effect: PokrovAssistantSafeActionEffect.none,
        ),
      'create_ticket' => const PokrovAssistantSafeAction(
          key: 'create_ticket',
          label: 'Написать человеку',
          effect: PokrovAssistantSafeActionEffect.openHandoff,
        ),
      _ => null,
    };
    if (action != null) {
      actions.add(action);
    }
  }
  return List<PokrovAssistantSafeAction>.unmodifiable(actions);
}

class _AssistantAnswerBody extends StatefulWidget {
  const _AssistantAnswerBody({super.key, required this.body});

  final String body;

  @override
  State<_AssistantAnswerBody> createState() => _AssistantAnswerBodyState();
}

class _AssistantAnswerBodyState extends State<_AssistantAnswerBody> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final sections = _assistantAnswerSections(widget.body);
    if (!sections.isStructured) {
      return Text(
        widget.body,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: p.ink,
              height: 1.3,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sections.summary case final summary?) ...[
          Text(
            'Коротко',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: p.accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            summary.primary,
            key: const ValueKey('assistant-answer-summary'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: p.ink,
                  height: 1.3,
                ),
          ),
        ],
        if (sections.action case final action?) ...[
          if (sections.summary != null) const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: p.accent),
              const SizedBox(width: 7),
              Text(
                'Что сделать',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            action.primary,
            key: const ValueKey('assistant-answer-action'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: p.ink,
                  height: 1.3,
                ),
          ),
        ],
        if (sections.hasDetails) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            key: const ValueKey('assistant-answer-details-toggle'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              setState(() => _detailsExpanded = !_detailsExpanded);
            },
            icon: Icon(
              _detailsExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
            ),
            label: Text(
              _detailsExpanded ? 'Скрыть подробности' : 'Подробности',
            ),
          ),
          if (_detailsExpanded) ...[
            if (sections.summary?.details case final details?) ...[
              Text(
                details,
                key: const ValueKey('assistant-answer-summary-details'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: p.ink,
                      height: 1.3,
                    ),
              ),
            ],
            if (sections.action?.details case final details?) ...[
              if (sections.summary?.details != null) const SizedBox(height: 8),
              Text(
                details,
                key: const ValueKey('assistant-answer-action-details'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: p.ink,
                      height: 1.3,
                    ),
              ),
            ],
          ],
        ],
        for (final extra in sections.extra) ...[
          const SizedBox(height: 10),
          Text(
            extra,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: p.ink,
                  height: 1.3,
                ),
          ),
        ],
      ],
    );
  }
}

class _AssistantAnswerSections {
  const _AssistantAnswerSections({
    required this.summary,
    required this.action,
    required this.extra,
  });

  final _AssistantSentencePair? summary;
  final _AssistantSentencePair? action;
  final List<String> extra;

  bool get isStructured => summary != null || action != null;
  bool get hasDetails => summary?.details != null || action?.details != null;
}

class _AssistantSentencePair {
  const _AssistantSentencePair({required this.primary, this.details});

  final String primary;
  final String? details;
}

_AssistantAnswerSections _assistantAnswerSections(String body) {
  String? summary;
  String? action;
  final extra = <String>[];
  var sawEscalation = false;
  final paragraphs = body
      .trim()
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty);

  for (final paragraph in paragraphs) {
    final short = _assistantSectionBody(paragraph, 'Коротко');
    if (short != null) {
      summary = short;
      continue;
    }
    final next = _assistantSectionBody(paragraph, 'Что сделать');
    if (next != null) {
      action = next;
      continue;
    }
    if (_assistantSectionBody(paragraph, 'Если не поможет') != null) {
      sawEscalation = true;
      continue;
    }
    extra.add(paragraph);
  }

  if (summary == null && action == null && sawEscalation) {
    return _AssistantAnswerSections(
      summary: null,
      action: null,
      extra: <String>[body],
    );
  }
  return _AssistantAnswerSections(
    summary: summary == null ? null : _assistantSentencePair(summary),
    action: action == null ? null : _assistantSentencePair(action),
    extra: List<String>.unmodifiable(extra),
  );
}

_AssistantSentencePair _assistantSentencePair(String value) {
  final trimmed = value.trim();
  if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
    return _AssistantSentencePair(primary: trimmed);
  }
  final match =
      RegExp(r'^(.+?[.!?])(?:\s+|$)(.+)$', dotAll: true).firstMatch(trimmed);
  if (match == null) {
    return _AssistantSentencePair(primary: trimmed);
  }
  final details = match.group(2)?.trim();
  return _AssistantSentencePair(
    primary: match.group(1)!.trim(),
    details: details == null || details.isEmpty ? null : details,
  );
}

String? _assistantSectionBody(String paragraph, String label) {
  final plain = paragraph.replaceAll('**', '').trim();
  if (!plain.toLowerCase().startsWith(label.toLowerCase())) {
    return null;
  }
  var value = plain.substring(label.length).trimLeft();
  if (value.startsWith(':')) {
    value = value.substring(1).trimLeft();
  }
  return value.trim();
}

/// States the real automated operation without impersonating a person typing.
class _AssistantThinkingStatus extends StatelessWidget {
  const _AssistantThinkingStatus();

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Semantics(
      liveRegion: true,
      label: 'ИИ-помощник готовит ответ',
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: const ValueKey('assistant-thinking-status'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.accent.withValues(alpha: 0.14)),
            ),
            child: Text(
              'ИИ-помощник готовит ответ…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: p.ink,
                    height: 1.3,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

String _consumerProtectionStatusLabel(
  RuntimeSnapshot? snapshot, {
  bool busy = false,
  bool disconnecting = false,
}) {
  // One status dialect across the app:
  // «Подключаемся…» / «Подключено» / «Отключаем…» / «Не защищено».
  if (busy) {
    return disconnecting ? 'Отключаем…' : 'Подключаемся…';
  }
  if (snapshot == null) {
    return 'Проверяем статус';
  }
  if (snapshot.phase == RuntimePhase.running) {
    return snapshot.isCleanlyHealthy ? 'Подключено' : 'Нужно внимание';
  }
  if (snapshot.phase == RuntimePhase.artifactMissing) {
    return 'Недоступно';
  }
  return 'Не защищено';
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
  if (text.startsWith('WARP ')) {
    // WARP status is shown as a calm info notice, never as a recovery banner.
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
