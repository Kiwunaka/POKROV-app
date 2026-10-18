part of pokrov_app_shell;

class _SupportChatScreen extends StatefulWidget {
  const _SupportChatScreen({
    required this.appContext,
    required this.selectedRouteMode,
    required this.statusLabel,
    required this.runtimeSnapshot,
    required this.extraDiagnostics,
    required this.supportTicketService,
    required this.observability,
    required this.askAssistant,
    required this.onOpenHandoff,
    required this.promoSlot,
    required this.onPromoEvent,
    this.initialTicketId,
    this.diagnosticsReport,
  });

  final SeedAppContext appContext;
  final RouteMode selectedRouteMode;
  final String statusLabel;
  final RuntimeSnapshot? runtimeSnapshot;
  final Map<String, Object?> extraDiagnostics;
  final SupportTicketService supportTicketService;
  final int? initialTicketId;
  final PokrovDiagnosticsReport? diagnosticsReport;
  final PokrovClientObservability? observability;

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

class _SupportChatScreenState extends State<_SupportChatScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _composer;
  late final FocusNode _composerFocusNode;
  late final ScrollController _messageListController;
  late final SupportConversationController _conversation;
  bool _attachDiagnosticsToNextMessage = false;
  bool _sendingBundle = false;
  late bool _humanMode = widget.initialTicketId != null || widget.askAssistant == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _conversation = SupportConversationController(
      service: widget.supportTicketService,
      hostPlatform: widget.appContext.hostPlatform,
      initialTicketId: widget.initialTicketId,
      foreground:
          lifecycleState == null || lifecycleState == AppLifecycleState.resumed,
      onMessagesChanged: _scrollToLatestMessage,
      onMessageAccepted: (text) {
        _clearComposerAfterSend(text);
        _attachDiagnosticsToNextMessage = false;
      },
    )..addListener(_onConversationChanged);
    _composer = TextEditingController();
    _composerFocusNode = FocusNode(debugLabel: 'support-composer');
    _messageListController = ScrollController(
      debugLabel: 'support-message-list',
    );
    unawaited(_conversation.loadInitialThread());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conversation.dispose();
    _composerFocusNode.dispose();
    _messageListController.dispose();
    _composer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _conversation.setForeground(state == AppLifecycleState.resumed);
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

  void _onConversationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendMessage() => _conversation.send(
        text: _composer.text,
        routeMode: widget.selectedRouteMode,
        attachDiagnostics: _attachDiagnosticsToNextMessage,
        statusLabel: widget.statusLabel,
        diagnostics: _attachDiagnosticsToNextMessage
            ? _supportDiagnostics()
            : const <String, Object?>{},
      );

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
      'build_number': pokrovClientBuildNumber,
      ...?widget.diagnosticsReport?.supportDiagnosticFields(),
      'platform': widget.appContext.hostPlatform.name,
      'route_mode': widget.selectedRouteMode.name,
      'connection_status': widget.statusLabel,
      'warp_status': _safeWarpSummary(),
    };
  }

  PreparedSupportBundle _prepareSupportBundlePreview() {
    return preparePokrovClientSupportBundle(
      hostPlatform: widget.appContext.hostPlatform,
      routeMode: widget.selectedRouteMode,
      snapshot: widget.runtimeSnapshot,
      warpState: _supportBundleWarpState(),
      now: DateTime.now().toUtc(),
      appVersion: pokrovClientVersion,
      buildNumber: pokrovClientBuildNumber,
      releaseChannel: pokrovClientReleaseChannel,
      candidateLabel: pokrovClientCandidateLabel,
    );
  }

  String _supportBundleWarpState() {
    if (widget.extraDiagnostics['enhanced_protection_consent'] == true) {
      final state = widget.extraDiagnostics['enhanced_protection_state'];
      return state == 'fallback' ? 'fallback' : 'enabled';
    }
    if (widget.extraDiagnostics['enhanced_protection_available'] == true) {
      return 'disabled';
    }
    return 'unavailable';
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

  Future<void> _openFeedbackForm() async {
    PokrovHaptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: _pokrovSheetAnimationStyle(context),
      builder: (context) => _SupportFeedbackSheet(
        onSubmit: _submitFeedback,
      ),
    );
  }

  Future<String?> _submitFeedback(_SupportFeedbackDraft draft) =>
      _conversation.submitFeedback(
        routeMode: widget.selectedRouteMode,
        statusLabel: draft.attachDiagnostics ? widget.statusLabel : '',
        subject: 'Обратная связь POKROV — ${draft.category.subject}',
        body: draft.message,
        diagnostics: draft.attachDiagnostics
            ? _supportDiagnostics()
            : const <String, Object?>{},
      );

  void _showDiagnosticsPreview() {
    late final PreparedSupportBundle prepared;
    try {
      prepared = _prepareSupportBundlePreview();
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось безопасно подготовить предпросмотр.'),
        ),
      );
      return;
    }
    final preview = prepared.preview;
    final supportCode = pokrovSupportDiagnosticCode(
      prepared: prepared,
      hostPlatform: widget.appContext.hostPlatform,
      routeMode: widget.selectedRouteMode,
      snapshot: widget.runtimeSnapshot,
      appVersion: pokrovClientVersion,
      buildNumber: pokrovClientBuildNumber,
      generatedAt: DateTime.now().toUtc(),
    );
    final ticketService = widget.supportTicketService;
    final SupportBundleTransferService? bundleService =
        ticketService is SupportBundleTransferService
            ? ticketService as SupportBundleTransferService
            : null;
    final encryptedDeliveryAvailable =
        bundleService?.supportBundleEncryptionConfigured ?? false;
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
                      const Text('Диагностика', style: ui.PokrovText.heading),
                      Flexible(
                        child: SingleChildScrollView(
                          child: ExpansionTile(
                            title: const Text('Технические детали'),
                            children: [Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Предпросмотр диагностики',
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
                                label: 'Код поддержки',
                                value: '••••-••••',
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  OutlinedButton.icon(
                                    key: const ValueKey(
                                      'support-diagnostics-copy-code',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: supportCode,
                                        ),
                                      );
                                      showPokrovSnack(
                                        context,
                                        'Код поддержки скопирован.',
                                        tone: PokrovSnackTone.success,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Скопировать код'),
                                  ),
                                  Text(
                                    'Его можно передать поддержке без загрузки файла.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: p.muted),
                                  ),
                                ],
                              ),
                              const _KeyValueLine(
                                label: 'Профиль',
                                value: 'Краткий',
                              ),
                              _KeyValueLine(
                                label: 'Категории',
                                value: preview.categories
                                    .map(_diagnosticCategoryLabel)
                                    .join(', '),
                              ),
                              _KeyValueLine(
                                label: 'Размер',
                                value: '${preview.totalPlaintextBytes} байт',
                              ),
                              _KeyValueLine(
                                label: 'Удалено полей',
                                value: '${preview.removedFieldCount}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Файлы пакета',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              for (final file in preview.files)
                                _KeyValueLine(
                                  label: file.path,
                                  value: '${file.size} байт',
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Не включены: система, события и сбои. Это дополнительные категории других профилей.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: p.muted, height: 1.3),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Краткая сводка для сообщения',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
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
                                encryptedDeliveryAvailable
                                    ? 'Пакет будет зашифрован на проверенный подписанный ключ поддержки. При обрыве сети сохранится только зашифрованный файл для безопасного повтора.'
                                    : 'Зашифрованный пакет выше не отправляется без отдельного шифрования на подписанный ключ поддержки. Код диагностики и показанная краткая сводка остаются доступны без загрузки.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: p.muted, height: 1.3),
                              ),
                            ],
                          )],
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
                            label: const Text('Добавить краткую сводку'),
                          ),
                          if (encryptedDeliveryAvailable)
                            FilledButton.icon(
                              key: const ValueKey(
                                'support-diagnostics-send-encrypted',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: _sendingBundle
                                  ? null
                                  : () {
                                      Navigator.of(context).maybePop();
                                      unawaited(
                                        _sendEncryptedSupportBundle(
                                          prepared,
                                          bundleService!,
                                        ),
                                      );
                                    },
                              icon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Отправить зашифрованно'),
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

  Future<void> _sendEncryptedSupportBundle(
    PreparedSupportBundle prepared,
    SupportBundleTransferService service,
  ) async {
    if (_sendingBundle) {
      return;
    }
    setState(() {
      _sendingBundle = true;
    });
    widget.observability?.recordSupportBundleStarted();
    try {
      final result = await service.deliverSupportBundle(
        hostPlatform: widget.appContext.hostPlatform,
        prepared: prepared,
        caseSummary:
            'Версия $pokrovClientVersion; ${widget.appContext.hostPlatform.name}; режим ${widget.selectedRouteMode.name}; диагностика приложения.',
        ticketId: _conversation.ticketId,
      );
      widget.observability?.recordSupportBundleFinished(prepared: prepared);
      if (!mounted) {
        return;
      }
      final message = result.state == SupportBundleDeliveryState.queued
          ? 'Зашифрованная диагностика поставлена в очередь поддержки.'
          : 'Сеть недоступна. Зашифрованный пакет сохранен на устройстве для повтора.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on SupportBundleTransferFailure catch (error) {
      widget.observability?.recordSupportBundleFinished(
        prepared: prepared,
        errorCode: _supportBundleOperationalErrorCode(error),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } on Object catch (error) {
      widget.observability?.recordSupportBundleFinished(
        prepared: prepared,
        errorCode: _supportBundleOperationalErrorCode(error),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось подготовить зашифрованную диагностику.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingBundle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_humanMode && widget.askAssistant != null) {
      return _AssistantChatSheet(
        askAssistant: widget.askAssistant!,
        onEscalate: () {
          setState(() => _humanMode = true);
          _composerFocusNode.requestFocus();
        },
        onAttachDiagnostics: _showDiagnosticsPreview,
      );
    }
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _FocusSupportComposerIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true): _SendSupportMessageIntent(),
      },
      child: Actions(actions: <Type, Action<Intent>>{
        _FocusSupportComposerIntent: CallbackAction<_FocusSupportComposerIntent>(onInvoke: (_) { _composerFocusNode.requestFocus(); return null; }),
        _SendSupportMessageIntent: CallbackAction<_SendSupportMessageIntent>(onInvoke: (_) { if (!_conversation.sending && !_conversation.loadingThread) unawaited(_sendMessage()); return null; }),
      }, child: ui.SupportScreen(
        key: const ValueKey('support-chat-screen'),
        data: ui.SupportViewData(
          subtitle: 'Чат с человеком · ответ придёт сюда',
          topics: const [],
          messages: [for (final message in _conversation.messages)
            message.role == SupportChatRole.user
                ? ui.ChatMessage.user(message.body)
                : ui.ChatMessage.assistant(short: message.body, steps: const [],
                    author: message.role == SupportChatRole.operator ? 'Поддержка' : message.label),
          ],
          busy: _conversation.sending || _conversation.loadingThread,
          busyLabel: _conversation.loadingThread ? 'Загружаем переписку…' : 'Отправляем…',
          notice: _conversation.sendError ?? switch (_conversation.lifecycle) {
            SupportConversationLifecycle.offline => 'Переписка не обновилась. Попробуй ещё раз.',
            SupportConversationLifecycle.closed => 'Обращение закрыто. Можешь написать снова.',
            _ => _attachDiagnosticsToNextMessage
                ? 'К следующему сообщению добавим краткую сводку.' : null,
          },
        ),
        composer: _composer, composerFocus: _composerFocusNode, scrollController: _messageListController,
        adSlot: widget.promoSlot == null ? null : _HomeAdminPromoCard(
          slot: widget.promoSlot!, compact: true, keyPrefix: 'support-promo',
          onOpenHandoff: widget.onOpenHandoff, onPromoEvent: widget.onPromoEvent),

        onSend: (_) => unawaited(_sendMessage()),
        onRetry: _conversation.sendError != null ? () => unawaited(_sendMessage())
            : _conversation.lifecycle == SupportConversationLifecycle.offline ? _conversation.retry : null,
        onAssistant: widget.askAssistant == null ? null : () => unawaited(_openAssistantSheet()),
        onReport: _showDiagnosticsPreview,
        onFeedback: () => unawaited(_openFeedbackForm()),
        onBack: () => Navigator.of(context).maybePop(),
      )),
    );
  }
}

class _SupportFeedbackCategory {
  const _SupportFeedbackCategory({
    required this.id,
    required this.label,
    required this.subject,
  });

  final String id;
  final String label;
  final String subject;
}

const _supportFeedbackCategories = <_SupportFeedbackCategory>[
  _SupportFeedbackCategory(id: 'idea', label: 'Идея', subject: 'идея'),
  _SupportFeedbackCategory(id: 'bug', label: 'Ошибка', subject: 'ошибка'),
  _SupportFeedbackCategory(id: 'other', label: 'Другое', subject: 'другое'),
];

class _SupportFeedbackDraft {
  const _SupportFeedbackDraft({
    required this.category,
    required this.message,
    required this.attachDiagnostics,
  });

  final _SupportFeedbackCategory category;
  final String message;
  final bool attachDiagnostics;
}

class _SupportFeedbackSheet extends StatefulWidget {
  const _SupportFeedbackSheet({required this.onSubmit});

  final Future<String?> Function(_SupportFeedbackDraft draft) onSubmit;

  @override
  State<_SupportFeedbackSheet> createState() => _SupportFeedbackSheetState();
}

class _SupportFeedbackSheetState extends State<_SupportFeedbackSheet> {
  late final TextEditingController _messageController;
  _SupportFeedbackCategory _category = _supportFeedbackCategories.first;
  bool _attachDiagnostics = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (_submitting || message.length < 3) {
      setState(() {
        _error = 'Напишите хотя бы несколько слов.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      _SupportFeedbackDraft(
        category: _category,
        message: message,
        attachDiagnostics: _attachDiagnostics,
      ),
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PokrovPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: _MotionTokens.short,
        curve: _MotionTokens.ease,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight),
              child: SingleChildScrollView(
                key: const ValueKey('support-feedback-form'),
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Обратная связь',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: p.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Идеи и замечания попадут команде POKROV прямо из приложения.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: p.muted,
                                    height: 1.35,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in _supportFeedbackCategories)
                              ChoiceChip(
                                key: ValueKey(
                                  'support-feedback-category-${category.id}',
                                ),
                                label: Text(category.label),
                                selected: category.id == _category.id,
                                onSelected: _submitting
                                    ? null
                                    : (_) => setState(() {
                                          _category = category;
                                          _error = null;
                                        }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const ValueKey('support-feedback-message'),
                          controller: _messageController,
                          autofocus: true,
                          enabled: !_submitting,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 1500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Что улучшить?',
                            hintText: 'Опишите идею или проблему',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                        CheckboxListTile(
                          key: const ValueKey(
                            'support-feedback-attach-diagnostics',
                          ),
                          value: _attachDiagnostics,
                          enabled: !_submitting,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Приложить безопасную диагностику'),
                          subtitle: const Text(
                            'Версия, устройство, режим, статус VPN и WARP — без ключей и адресов серверов.',
                          ),
                          onChanged: (value) => setState(() {
                            _attachDiagnostics = value ?? false;
                          }),
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 8),
                          Text(
                            error,
                            key: const ValueKey('support-feedback-error'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('support-feedback-submit'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 19),
                            label: Text(
                              _submitting ? 'Отправляем…' : 'Отправить',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
  Widget build(BuildContext context) => ui.SupportScreen(
    data: ui.SupportViewData(
      subtitle: _shouldEscalate ? 'Можешь позвать человека — он поможет дальше' : 'Сначала ответит ИИ, потом человек',
      topics: const ['Не подключается', 'Медленно', 'Сайт не открывается'],
      messages: [for (final message in _messages) _assistantViewMessage(message)],
      busy: _thinking,
      notice: _failedQuestion == null ? null : 'Не удалось получить ответ. Можно попробовать снова.',
    ),
    composer: _composer, composerFocus: _composerFocusNode, scrollController: _listController,
    onSend: (_) => unawaited(_send()),
    onTopic: (topic) { _composer.text = topic; unawaited(_send()); },
    onHuman: _openHumanSupport,
    onRetry: _failedQuestion == null || _thinking ? null : () => unawaited(_send(retryQuestion: _failedQuestion)),
    onAnswerAction: (key) {
      for (final message in _messages.reversed) {
        for (final action in message.actions) {
          if (action.key == key) { _activateAction(action); return; }
        }
      }
    },
    onBack: () => Navigator.of(context).maybePop(),
  );

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

ui.ChatMessage _assistantViewMessage(PokrovAssistantMessage message) {
  if (message.role == PokrovAssistantRole.user) return ui.ChatMessage.user(message.safeBody);
  final sections = _assistantAnswerSections(message.safeBody);
  String section(_AssistantSentencePair? value) => value == null ? ''
      : [value.primary, if (value.details != null) value.details!].join(' ');
  return ui.ChatMessage.assistant(
    short: sections.isStructured
        ? [section(sections.summary), ...sections.extra].where((value) => value.isNotEmpty).join('\n\n')
        : message.safeBody,
    steps: sections.action == null ? const [] : [section(sections.action)],
    author: message.sourceLabel ?? 'ИИ-помощник',
    actions: [for (final action in message.actions) (id: action.key, label: action.label)],
  );
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

String _diagnosticCategoryLabel(DiagnosticCategory category) =>
    switch (category) {
      DiagnosticCategory.build => 'сборка',
      DiagnosticCategory.system => 'система',
      DiagnosticCategory.network => 'сеть',
      DiagnosticCategory.events => 'события',
      DiagnosticCategory.crashes => 'сбои',
      DiagnosticCategory.redaction => 'очистка',
    };


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
