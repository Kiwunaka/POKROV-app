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
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final String statusLabel;
  final Map<String, Object?> extraDiagnostics;
  final SupportTicketService supportTicketService;

  /// Knowledge-base question -> answer lane for the AI assistant sheet.
  /// `null` hides the entry point (no client data service available).
  final Future<ClientSupportAssistantReply> Function(String message)?
      askAssistant;
  final void Function(String label, String value) onOpenHandoff;

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
  String _threadStatus = 'Помощник POKROV';
  String? _threadError;
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

  void _applyIssueChip(String prompt) {
    setState(() {
      _composer.text = prompt;
      _composer.selection = TextSelection.collapsed(offset: prompt.length);
    });
    _composerFocusNode.requestFocus();
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
      _scrollToLatestMessage();
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
      _scrollToLatestMessage();
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
      'app_version': _pokrovAppVersion,
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
        );
      },
    );
    if (!mounted || !escalated) {
      return;
    }
    _composerFocusNode.requestFocus();
  }

  void _showDiagnosticsPreview() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      builder: (context) {
        final p = PokrovPalette.of(context);
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
                  'Что отправим',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  value: widget.selectedRouteMode.label,
                ),
                _KeyValueLine(
                  label: 'Статус VPN',
                  value: widget.statusLabel,
                ),
                _KeyValueLine(
                  label: 'Версия',
                  value: _pokrovAppVersion,
                ),
                _KeyValueLine(
                  label: 'WARP',
                  value: _safeWarpSummary(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Прикрепим только краткую безопасную сводку: устройство, версию приложения, статус VPN, режим и WARP.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
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
                      child: const Text('Отмена'),
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
                      label: const Text('Прикрепить к сообщению'),
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
            appBar: AppBar(
              title: const Text('Поддержка'),
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
                              'Выберите тему или напишите, что не получается.',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: _SupportLifecycleHint(
                          state: _supportLifecycleState,
                          onRetry: _retrySupportLifecycle,
                        ),
                      ),
                      if (!_loadingThread && widget.askAssistant != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: _SupportAssistantEntry(
                            onTap: () => unawaited(_openAssistantSheet()),
                          ),
                        ),
                      if (!_loadingThread)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: _SupportIssueChips(
                            onSelected: _applyIssueChip,
                          ),
                        ),
                      if (!_loadingThread)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              key: const ValueKey(
                                'support-diagnostics-action',
                              ),
                              onPressed: _showDiagnosticsPreview,
                              icon: const Icon(
                                Icons.health_and_safety_outlined,
                              ),
                              label: const Text('Диагностика'),
                            ),
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
                                controller: _messageListController,
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
  const _SupportDiagnosticsQueuedPill({
    required this.onClear,
  });

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
          border: Border.all(
            color: p.accent.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: p.accent,
            ),
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
              constraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 26,
              ),
              padding: EdgeInsets.zero,
              onPressed: onClear,
              icon: Icon(
                Icons.close_rounded,
                color: p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportIssueChips extends StatelessWidget {
  const _SupportIssueChips({
    required this.onSelected,
  });

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    const issues = <({IconData icon, String label, String prompt})>[
      (
        icon: Icons.wifi_off_rounded,
        label: 'Не подключается',
        prompt: 'Не подключается. Помогите, пожалуйста, проверить доступ.',
      ),
      (
        icon: Icons.speed_rounded,
        label: 'Медленно',
        prompt: 'Стало медленно. Хочу понять, что можно проверить.',
      ),
      (
        icon: Icons.credit_card_rounded,
        label: 'Оплата',
        prompt: 'Нужна помощь с оплатой или продлением доступа.',
      ),
      (
        icon: Icons.card_giftcard_rounded,
        label: 'Бонусы',
        prompt: 'Нужна помощь с бонусами POKROV.',
      ),
      (
        icon: Icons.more_horiz_rounded,
        label: 'Другое',
        prompt: 'Нужна помощь по другому вопросу.',
      ),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        key: const ValueKey('support-issue-chips'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final issue in issues) ...[
              ActionChip(
                key: ValueKey('support-issue-${issue.label}'),
                avatar: Icon(issue.icon, size: 16),
                label: Text(issue.label),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: p.line),
                backgroundColor: p.surface,
                onPressed: () => onSelected(issue.prompt),
              ),
              const SizedBox(width: 8),
            ],
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
    final p = PokrovPalette.of(context);
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
                side: BorderSide(color: p.line),
                backgroundColor: p.surface,
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
    final p = PokrovPalette.of(context);
    final data = switch (state) {
      _SupportLifecycleState.loading => (
          key: 'loading',
          icon: Icons.sync_rounded,
          label: 'Загружаем чат',
          detail: 'История обращений появится здесь.',
          accent: p.muted,
          retry: false,
        ),
      _SupportLifecycleState.ready => (
          key: 'ready',
          icon: Icons.smart_toy_outlined,
          label: 'Помощник POKROV на связи',
          detail: 'Если вопрос не решится, к диалогу подключится оператор.',
          accent: p.muted,
          retry: false,
        ),
      _SupportLifecycleState.tracking => (
          key: 'tracking',
          icon: Icons.mark_chat_unread_outlined,
          label: 'Ответ появится здесь',
          detail: 'POKROV проверяет обращение. Telegram остается запасным.',
          accent: p.accent,
          retry: false,
        ),
      _SupportLifecycleState.refreshing => (
          key: 'refreshing',
          icon: Icons.sync_rounded,
          label: 'Обновляем чат',
          detail: 'Проверяем ответы, не открывая Telegram.',
          accent: p.accent,
          retry: false,
        ),
      _SupportLifecycleState.operator => (
          key: 'operator',
          icon: Icons.support_agent_rounded,
          label: 'Поддержка ответила',
          detail: 'Продолжайте диалог здесь или через Telegram.',
          accent: p.accent,
          retry: false,
        ),
      _SupportLifecycleState.closed => (
          key: 'closed',
          icon: Icons.check_circle_outline_rounded,
          label: 'Обращение закрыто',
          detail: 'Можно написать новое сообщение, если вопрос вернулся.',
          accent: p.success,
          retry: false,
        ),
      _SupportLifecycleState.offline => (
          key: 'offline',
          icon: Icons.cloud_off_outlined,
          label: 'Чат временно не обновился',
          detail:
              'Сообщения не потеряны. Можно повторить или открыть Telegram.',
          accent: p.warning,
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
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
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
    final p = PokrovPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: p.accent,
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
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.muted,
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
    final p = PokrovPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: p.muted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: p.muted,
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
                  color: isAutomation
                      ? p.accent.withValues(alpha: 0.14)
                      : p.line,
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

/// Entry point into the AI mini chat: a calm mint row above the ticket flow.
class _SupportAssistantEntry extends StatelessWidget {
  const _SupportAssistantEntry({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return PokrovSettingsRowPressSurface(
      onTap: onTap,
      child: Container(
        key: const ValueKey('support-ai-entry'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.accent.withValues(alpha: 0.16)),
        ),
        child: Row(
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
                    'Спросить ИИ-помощника',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Мгновенные ответы по базе знаний',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: p.muted,
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
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
  });

  final Future<ClientSupportAssistantReply> Function(String message)
      askAssistant;
  final VoidCallback onEscalate;

  @override
  State<_AssistantChatSheet> createState() => _AssistantChatSheetState();
}

class _AssistantChatSheetState extends State<_AssistantChatSheet> {
  static const _noAnswerFallback =
      'Не нашёл ответа. Напишите в поддержку — ответит человек.';

  late final TextEditingController _composer;
  late final FocusNode _composerFocusNode;
  late final ScrollController _listController;
  final List<PokrovAssistantMessage> _messages = <PokrovAssistantMessage>[
    PokrovAssistantMessage.assistant(
      id: 'assistant-greeting',
      body: 'Задайте вопрос про подключение, доступ или бонусы — '
          'отвечу по базе знаний POKROV.',
    ),
  ];
  bool _thinking = false;
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

  void _applySuggestion(PokrovAssistantSuggestion suggestion) {
    setState(() {
      _composer.text = suggestion.prompt;
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
    });
    _composerFocusNode.requestFocus();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _thinking) {
      return;
    }
    PokrovHaptics.tap();
    _messageSeq += 1;
    setState(() {
      _messages.add(
        PokrovAssistantMessage(
          id: 'user-$_messageSeq',
          role: PokrovAssistantRole.user,
          body: text,
        ),
      );
      _thinking = true;
    });
    _composer.clear();
    _scrollToLatest();

    var answer = _noAnswerFallback;
    try {
      final reply = await widget.askAssistant(text);
      final body = reply.reply.trim();
      if (body.isNotEmpty) {
        answer = body;
      }
    } catch (_) {
      // Keep the honest no-answer fallback; the human escape row stays below.
    }
    if (!mounted) {
      return;
    }
    _messageSeq += 1;
    setState(() {
      _thinking = false;
      _messages.add(
        PokrovAssistantMessage.assistant(
          id: 'assistant-$_messageSeq',
          body: answer,
        ),
      );
    });
    _scrollToLatest();
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final showSuggestions = _messages.length <= 1 && !_thinking;
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
                            'Отвечает автоматика по базе знаний POKROV',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: p.muted,
                                  height: 1.25,
                                ),
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
                        _AssistantSheetBubble(message: message),
                      if (_thinking) const _AssistantTypingBubble(),
                    ],
                  ),
                ),
                if (showSuggestions) ...[
                  const SizedBox(height: 2),
                  SingleChildScrollView(
                    key: const ValueKey('assistant-sheet-suggestions'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final suggestion in PokrovAssistantContract
                            .defaultSupportSuggestions) ...[
                          ActionChip(
                            key: ValueKey(
                              'assistant-sheet-${suggestion.key}',
                            ),
                            avatar: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                            ),
                            label: Text(suggestion.title),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: p.line),
                            backgroundColor: p.surface,
                            onPressed: () => _applySuggestion(suggestion),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
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
                          onPressed: _thinking ? null : () => unawaited(_send()),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const ValueKey('assistant-sheet-escalate'),
                    onPressed: () {
                      PokrovHaptics.tap();
                      widget.onEscalate();
                    },
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Нужен человек? Создать обращение'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantSheetBubble extends StatelessWidget {
  const _AssistantSheetBubble({
    required this.message,
  });

  final PokrovAssistantMessage message;

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
            ],
            Text(
              message.safeBody,
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

/// Quiet "typing" indicator: three low-alpha accent dots animated with
/// opacity only. The loop runs through [PokrovLoopingMotion] (finite pass in
/// tests) and collapses to static dots under reduced motion.
class _AssistantTypingBubble extends StatefulWidget {
  const _AssistantTypingBubble();

  @override
  State<_AssistantTypingBubble> createState() => _AssistantTypingBubbleState();
}

class _AssistantTypingBubbleState extends State<_AssistantTypingBubble>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1200);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = _MotionScope.of(context).disableAnimations;
    if (disableAnimations || !PokrovLoopingMotion.enabled) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOpacity(int index) {
    if (!_controller.isAnimating) {
      return 0.4;
    }
    final phase = (_controller.value - index * 0.18) % 1.0;
    final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
    return 0.25 + wave * 0.55;
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('assistant-typing-indicator'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.accent.withValues(alpha: 0.14)),
        ),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i += 1) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Opacity(
                      opacity: _dotOpacity(i),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.accent,
                        ),
                        child: const SizedBox.square(dimension: 6),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
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
