part of pokrov_app_shell;

class _QuickConnectSection extends StatelessWidget {
  const _QuickConnectSection({
    required this.advanced,
    required this.preferredCountryCode,
    required this.onHelp,
    required this.appContext,
    required this.freeProfileAccess,
    required this.protectionState,
    required this.protectionIntents,
    required this.revealHold,
    required this.bonusSummary,
    required this.subscriptionInfo,
    required this.telegramBonusBusy,
    required this.warpPolicy,
    required this.warpRuntimeConsent,
    required this.warpRuntimeActive,
    required this.warpBusy,
    required this.onTelegramBonus,
    required this.onOpenWarp,
    required this.onWarpConsentChanged,
    required this.notificationsUnread,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onOpenPromoHandoff,
    required this.onPromoEvent,
  });

  final SeedAppContext appContext;
  final bool advanced;
  final String preferredCountryCode;
  final Future<void> Function() onHelp;
  final FreeProfileAccess? freeProfileAccess;
  final ProtectionViewState protectionState;
  final ProtectionIntents protectionIntents;

  /// Welcome Handover: true while the first-launch gate covers the shell,
  /// so the staged reveal waits for the handover instead of burning at boot.
  final bool revealHold;
  final AppFirstBonusSummary? bonusSummary;
  final ClientSubscriptionInfo? subscriptionInfo;
  final bool telegramBonusBusy;
  final WarpRuntimePolicy warpPolicy;
  final bool warpRuntimeConsent;
  final bool warpRuntimeActive;
  final bool warpBusy;
  final VoidCallback? onTelegramBonus;
  final Future<void> Function() onOpenWarp;
  final Future<void> Function(bool value) onWarpConsentChanged;
  final int notificationsUnread;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final void Function(String label, String value) onOpenPromoHandoff;
  final void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent;

  @override
  Widget build(BuildContext context) {
    final presentation = protectionState.connection;
    final snapshot = presentation.experience.snapshot;
    final slots = _homeAdminPromoSlots(bonusSummary);
    final country = preferredCountryCode.trim();
    final showTip = bonusSummary?.channelBonusEligible == true &&
        bonusSummary?.channelBonusClaimed != true && onTelegramBonus != null;
    return ui.HomeScreen(
      data: ui.HomeViewData(
        phase: _homeUiPhase(presentation),
        mode: advanced ? ui.InterfaceMode.advanced : ui.InterfaceMode.simple,
        accessBadge: _accessShortValue(appContext, bonusSummary, freeProfileAccess, subscriptionInfo),
        countryCaption: country.isEmpty ? 'Страна · авто' : 'Страна',
        countryLabel: country.isEmpty ? 'Авто' : _locationCountryDisplayName(country, country),
        countryCode: country.isEmpty ? null : country,
        connectedCountry: protectionState.locationLabel.split(' · ').first,
        statusLabel: presentation.isVerified
            ? protectionState.locationLabel.split(' · ').first
            : presentation.isDegraded ? 'Защита требует внимания'
            : presentation.experience.phase == ConnectionExperiencePhase.disconnecting
                ? 'Отключаем защиту' : null,
        actionLabel: presentation.isVerified ? null : presentation.primaryActionLabel,
        routeValue: protectionState.routeMode == RouteMode.allExceptRu ? 'напрямую' : 'по правилам',
        warpEnabled: warpRuntimeConsent,
        notificationsUnread: notificationsUnread,
        checks: [
          ui.HealthCheck('Связь', ok: snapshot?.uplinkState == RuntimeDiagnosticState.healthy),
          ui.HealthCheck('Сайты', ok: snapshot?.dnsState == RuntimeDiagnosticState.healthy),
          ui.HealthCheck('Защита', ok: snapshot?.coreEgressValidated == true),
        ],
        tip: showTip ? ui.NextStepTip(title: 'Подпишись на канал',
          text: _telegramBonusHomeLabel(bonusSummary), icon: Icons.send_rounded) : null,
        showAdSlot: slots.isNotEmpty,
      ),
      onToggle: presentation.primaryActionEnabled
          ? () => unawaited(protectionIntents.toggleConnection()) : null,
      onOpenStatus: protectionIntents.openConnectionDetails,
      onOpenCountry: protectionIntents.openLocations,
      onOpenRoute: protectionIntents.openRules,
      onOpenAccess: onOpenProfile,
      onNotifications: onOpenNotifications,
      onWarpChanged: warpBusy ? null : (value) => unawaited(onWarpConsentChanged(value)),
      onTip: onTelegramBonus,
      onHelp: () => unawaited(onHelp()),
      adSlot: slots.isEmpty ? null : Column(children: [
        for (final slot in slots) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _HomeAdminPromoCard(
            key: ValueKey('home-promo-' + slot.slotId + '-' + slot.contentId),
            slot: slot, compact: advanced,
            onOpenHandoff: onOpenPromoHandoff, onPromoEvent: onPromoEvent,
          ),
        ),
      ]),
    );
  }
}

ui.ConnectionPhase _homeUiPhase(ConnectionPresentation presentation) =>
    presentation.isVerified ? ui.ConnectionPhase.on : switch (presentation.discPhase) {
      ConnectionDiscPhase.error => ui.ConnectionPhase.error,
      ConnectionDiscPhase.idle => ui.ConnectionPhase.off,
      _ => ui.ConnectionPhase.connecting,
    };

class _HomeAdminPromoCard extends StatefulWidget {
  const _HomeAdminPromoCard({
    super.key,
    required this.slot,
    required this.onOpenHandoff,
    required this.onPromoEvent,
    this.keyPrefix = 'home-admin-promo',
    this.compact,
  });

  final AppFirstPromoSlot slot;
  final void Function(String label, String value) onOpenHandoff;
  final void Function(AppFirstPromoSlot slot, String eventName) onPromoEvent;
  final String keyPrefix;
  final bool? compact;

  @override
  State<_HomeAdminPromoCard> createState() => _HomeAdminPromoCardState();
}

class _HomeAdminPromoCardState extends State<_HomeAdminPromoCard> {
  final PokrovFilePromoDismissStore _dismissStore =
      const PokrovFilePromoDismissStore();
  bool _dismissed = true;
  bool _dismissStateLoaded = false;
  bool _reportedImpression = false;
  bool _reportedExpiry = false;
  Timer? _countdownTimer;

  String get _campaignKey {
    final slot = widget.slot;
    return <String>[
      slot.slotId.trim(),
      slot.contentId.trim(),
      slot.startsAt.trim(),
      slot.endsAt.trim(),
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restoreDismissState());
  }

  @override
  void didUpdateWidget(covariant _HomeAdminPromoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = <String>[
      oldWidget.slot.slotId.trim(),
      oldWidget.slot.contentId.trim(),
      oldWidget.slot.startsAt.trim(),
      oldWidget.slot.endsAt.trim(),
    ].join('|');
    if (oldKey != _campaignKey) {
      _countdownTimer?.cancel();
      _dismissed = true;
      _dismissStateLoaded = false;
      _reportedImpression = false;
      _reportedExpiry = false;
      unawaited(_restoreDismissState());
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  DateTime get _serverNow => DateTime.now().toUtc().add(
        Duration(milliseconds: widget.slot.serverTimeOffsetMs),
      );

  Duration? get _countdownRemaining {
    if (widget.slot.countdownMode.trim().toLowerCase() != 'ends_at') {
      return null;
    }
    final end = DateTime.tryParse(widget.slot.endsAt.trim())?.toUtc();
    if (end == null) {
      return null;
    }
    final remaining = end.difference(_serverNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get _expired => _countdownRemaining == Duration.zero;

  void _startCountdown() {
    _countdownTimer?.cancel();
    final remaining = _countdownRemaining;
    if (remaining == null) {
      return;
    }
    if (remaining == Duration.zero) {
      _reportExpiry();
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_expired) {
        _countdownTimer?.cancel();
        _reportExpiry();
      }
      setState(() {});
    });
  }

  void _reportExpiry() {
    if (_reportedExpiry) {
      return;
    }
    _reportedExpiry = true;
    widget.onPromoEvent(widget.slot, 'expired');
  }

  void _reportImpression() {
    if (_reportedImpression || _dismissed || _expired) {
      return;
    }
    _reportedImpression = true;
    widget.onPromoEvent(widget.slot, 'impression');
  }

  Future<void> _restoreDismissState() async {
    final key = _campaignKey;
    final dismissed = widget.slot.dismissible
        ? await _dismissStore.isDismissed(key).timeout(
              const Duration(milliseconds: 400),
              onTimeout: () => false,
            )
        : false;
    if (!mounted || key != _campaignKey) {
      return;
    }
    setState(() {
      _dismissed = dismissed;
      _dismissStateLoaded = true;
    });
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reportImpression();
      }
    });
  }

  void _dismiss() {
    final key = _campaignKey;
    setState(() => _dismissed = true);
    widget.onPromoEvent(widget.slot, 'dismiss');
    unawaited(_dismissStore.dismiss(key));
  }

  void _open(Uri href) {
    widget.onPromoEvent(widget.slot, 'click');
    widget.onOpenHandoff('promo', href.toString());
  }

  void _openTerms(Uri href) {
    widget.onOpenHandoff('promo_terms', href.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (!_dismissStateLoaded || _dismissed || _expired) {
      return SizedBox.shrink(
        key: ValueKey('${widget.keyPrefix}-dismissed'),
      );
    }
    final slot = widget.slot;
    final safeHref = _safeHomePromoSlotHref(slot.ctaHref);
    final safeTermsHref = slot.hasReadyCommercialOffer
        ? _safeHomePromoSlotHref(slot.termsUrl)
        : null;
    final safeMedia = _safeHomePromoImageUri(
      slot.mediaUrl.trim().isEmpty ? slot.imageUrl : slot.mediaUrl,
    );
    final safePoster = _safeHomePromoImageUri(slot.posterUrl);
    final safeFallback = _safeHomePromoImageUri(slot.fallbackImageUrl);
    final ctaLabel = slot.ctaLabel.trim().isEmpty ? 'Открыть' : slot.ctaLabel;
    final title = slot.title.trim();
    final body = slot.body.trim();
    final badge = slot.badgeLabel.trim();
    final p = PokrovPalette.of(context);
    final accent = _promoHexColor(slot.accentColor) ?? p.accent;
    final background = _promoHexColor(slot.backgroundColor) ?? p.surface;
    final textColor = _promoHexColor(slot.textColor) ?? p.ink;
    final buttonColor = _promoHexColor(slot.buttonColor) ?? accent;
    final buttonTextColor = _promoHexColor(slot.buttonTextColor) ??
        (ThemeData.estimateBrightnessForColor(buttonColor) == Brightness.dark
            ? Colors.white
            : Colors.black);
    final mediaOnly = safeMedia != null &&
        (slot.imageLayout.trim().toLowerCase() == 'media_only' ||
            (title.isEmpty && body.isEmpty && badge.isEmpty));
    final bannerImage = slot.imageLayout.trim().toLowerCase() == 'banner';
    final open = safeHref == null ? null : () => _open(safeHref);
    final remaining = _countdownRemaining;
    final countdown = remaining == null ? '' : _formatPromoCountdown(remaining);
    final countdownLabel = slot.countdownLabel.trim().isEmpty
        ? 'Осталось'
        : slot.countdownLabel.trim();
    final commercialPrice = slot.hasReadyCommercialOffer
        ? '${slot.basePriceRub} ₽ → ${slot.finalPriceRub} ₽'
        : '';
    final commercialDeadline = slot.hasReadyCommercialOffer
        ? _formatPromoAbsoluteDeadline(slot.endsAt)
        : '';
    final aspectRatio = slot.mediaWidth != null &&
            slot.mediaHeight != null &&
            slot.mediaWidth! > 0 &&
            slot.mediaHeight! > 0
        ? (slot.mediaWidth! / slot.mediaHeight!).clamp(0.6, 2.4).toDouble()
        : 16 / 9;
    final dismissButton = IconButton(
      key: ValueKey('${widget.keyPrefix}-dismiss'),
      tooltip: 'Скрыть предложение',
      onPressed: _dismiss,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
      ),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.90),
          shape: BoxShape.circle,
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x18000000), blurRadius: 6),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close_rounded, size: 16),
        ),
      ),
    );

    Widget remoteMedia({required double? height, required BoxFit fit}) {
      if (safeMedia == null) {
        return const _BrandMark(size: 46);
      }
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (slot.mediaType.trim().toLowerCase() == 'video') {
        return SizedBox(
          height: height,
          width: double.infinity,
          child: _PromoVideo(
            url: safeMedia,
            poster: safePoster ?? safeFallback,
            autoplay: slot.autoplay && !reduceMotion,
            loop: slot.loop,
            fit: fit,
          ),
        );
      }
      final imageUri = reduceMotion &&
              slot.mediaType.trim().toLowerCase() == 'animated_image'
          ? safeFallback ?? safePoster ?? safeMedia
          : safeMedia;
      return Image.network(
        imageUri.toString(),
        height: height,
        width: double.infinity,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) =>
            safeFallback != null && safeFallback != imageUri
                ? Image.network(safeFallback.toString(), fit: fit)
                : const Center(child: _BrandMark(size: 46)),
      );
    }

    if (widget.compact != null) {
      return ui.AdSlot(
        key: ValueKey(widget.keyPrefix + '-card'), compact: widget.compact!,
        child: Material(color: background, child: InkWell(onTap: open,
          child: Stack(children: [
            if (mediaOnly) Positioned.fill(child: remoteMedia(height: null, fit: BoxFit.cover))
            else Padding(padding: const EdgeInsets.fromLTRB(14, 24, 14, 8),
              child: Row(children: [
                if (safeMedia != null) ...[
                  SizedBox(width: 64, child: remoteMedia(height: 64, fit: BoxFit.contain)),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (badge.isNotEmpty) Text(badge, style: TextStyle(fontSize: 11, color: textColor)),
                  if (title.isNotEmpty) Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                  if (body.isNotEmpty && !widget.compact!) Text(body, maxLines: 2,
                    overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textColor)),
                  if (safeTermsHref != null) InkWell(onTap: () => _openTerms(safeTermsHref),
                    child: Text(commercialPrice + ' · Условия', style: TextStyle(fontSize: 12, color: textColor))),
                ])),
                if (slot.dismissible) const SizedBox(width: 32),
              ]),
            ),
            if (slot.dismissible) Positioned(top: 0, right: 0, child: dismissButton),
          ]),
        )),
      );
    }

    final card = Container(
      key: ValueKey('${widget.keyPrefix}-card'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.64)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (slot.dismissible && mediaOnly)
                Align(
                  alignment: Alignment.centerRight,
                  child: dismissButton,
                ),
              if ((bannerImage || mediaOnly) && safeMedia != null)
                AspectRatio(
                  key: ValueKey('${widget.keyPrefix}-media'),
                  aspectRatio: aspectRatio,
                  child: remoteMedia(height: null, fit: BoxFit.cover),
                ),
              if (!mediaOnly)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    bannerImage && safeMedia != null ? 13 : 16,
                    16,
                    16,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 390;
                      final copy = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!bannerImage) ...[
                            SizedBox(
                              width: 54,
                              height: 54,
                              child:
                                  remoteMedia(height: 54, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 13),
                          ],
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: slot.dismissible ? 48 : 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (badge.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 5),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        badge.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.25,
                                            ),
                                      ),
                                    ),
                                  if (title.isNotEmpty)
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w800,
                                            height: 1.16,
                                          ),
                                    ),
                                  if (body.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      body,
                                      maxLines: compact ? 3 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: textColor.withValues(
                                                alpha: 0.72),
                                            height: 1.28,
                                          ),
                                    ),
                                  ],
                                  if (countdown.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '$countdownLabel $countdown',
                                      key: ValueKey(
                                        '${widget.keyPrefix}-countdown',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: accent,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                  if (commercialPrice.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      commercialPrice,
                                      key: ValueKey(
                                        '${widget.keyPrefix}-price',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      'До $commercialDeadline · доступно не более ${slot.remainingQuotaLowerBound}',
                                      key: ValueKey(
                                        '${widget.keyPrefix}-commercial-state',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: textColor.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                    ),
                                    if (safeTermsHref != null)
                                      TextButton(
                                        key: ValueKey(
                                          '${widget.keyPrefix}-terms',
                                        ),
                                        onPressed: () =>
                                            _openTerms(safeTermsHref),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(48, 44),
                                          alignment: Alignment.centerLeft,
                                          foregroundColor: accent,
                                        ),
                                        child: const Text(
                                          'Условия предложения',
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                      final copyWithDismiss =
                          slot.dismissible && bannerImage && safeMedia != null
                              ? Stack(
                                  children: [
                                    copy,
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: dismissButton,
                                    ),
                                  ],
                                )
                              : copy;
                      final action = open == null
                          ? null
                          : FilledButton(
                              key: ValueKey('${widget.keyPrefix}-action'),
                              onPressed: open,
                              style: FilledButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: buttonTextColor,
                                minimumSize:
                                    Size(compact ? double.infinity : 96, 46),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(ctaLabel,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            copyWithDismiss,
                            if (action != null) ...[
                              const SizedBox(height: 12),
                              action
                            ]
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: copyWithDismiss),
                          if (action != null) ...[
                            const SizedBox(width: 12),
                            action
                          ]
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
          if (mediaOnly && countdown.isNotEmpty)
            Positioned(
              left: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '$countdownLabel $countdown',
                    key: ValueKey('${widget.keyPrefix}-countdown'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          if (slot.dismissible &&
              !mediaOnly &&
              !(bannerImage && safeMedia != null))
            Positioned(
              top: 4,
              right: 4,
              child: dismissButton,
            ),
        ],
      ),
    );
    final presentedCard = card;
    if (open == null || !slot.wholeCardClickable) {
      return presentedCard;
    }
    return Semantics(
      button: true,
      label: '${title.isEmpty ? 'Предложение' : title}. $ctaLabel',
      onTap: open,
      child: PokrovSettingsRowPressSurface(onTap: open, child: presentedCard),
    );
  }
}

String _formatPromoCountdown(Duration remaining) {
  final totalSeconds = math.max(0, remaining.inSeconds);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}

String _formatPromoAbsoluteDeadline(String value) {
  final parsed = DateTime.tryParse(value.trim())?.toLocal();
  if (parsed == null) {
    return 'срок уточняется';
  }
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

class _PromoVideo extends StatefulWidget {
  const _PromoVideo({
    required this.url,
    required this.poster,
    required this.autoplay,
    required this.loop,
    required this.fit,
  });

  final Uri url;
  final Uri? poster;
  final bool autoplay;
  final bool loop;
  final BoxFit fit;

  @override
  State<_PromoVideo> createState() => _PromoVideoState();
}

class _PromoVideoState extends State<_PromoVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant _PromoVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      unawaited(_initialize());
    } else if (oldWidget.loop != widget.loop) {
      unawaited(_controller?.setLooping(widget.loop));
    }
  }

  Future<void> _initialize() async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (Platform.isWindows) {
      if (mounted) {
        setState(() => _failed = true);
      }
      return;
    }
    final controller = VideoPlayerController.networkUrl(widget.url);
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(widget.loop);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _failed = false;
      if (widget.autoplay) {
        await controller.play();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
    }
    setState(() {});
  }

  Widget _poster() {
    final poster = widget.poster;
    if (poster == null) {
      return const ColoredBox(
        color: Color(0x11000000),
        child: Center(child: _BrandMark(size: 46)),
      );
    }
    return Image.network(
      poster.toString(),
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const Center(child: _BrandMark(size: 46)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _poster(),
          if (!_failed)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    }
    return Semantics(
      button: true,
      label: controller.value.isPlaying
          ? 'Поставить видео на паузу'
          : 'Воспроизвести видео',
      onTap: _toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
            Center(
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      color: Color(0x99000000), shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<AppFirstPromoSlot> _homeAdminPromoSlots(
  AppFirstBonusSummary? bonusSummary,
) {
  final promoSlots = bonusSummary?.promoSlots;
  if (promoSlots == null) {
    return const <AppFirstPromoSlot>[];
  }
  const placements = <String>[
    'home_banner',
    'home_corner',
    'protection_contextual',
    'global_banner',
    'home',
    'home_primary',
    'protection',
    'protection_home',
  ];
  return List<AppFirstPromoSlot>.unmodifiable(
    <AppFirstPromoSlot>[
      for (final placement in placements)
        ...promoSlots
            .visibleForPlacement(placement)
            .where(_isRenderableHomePromoSlot),
    ],
  );
}

bool _isRenderableHomePromoSlot(AppFirstPromoSlot slot) {
  final title = slot.title.trim();
  final body = slot.body.trim();
  final safeImage = _safeHomePromoImageUri(
    slot.mediaUrl.trim().isEmpty ? slot.imageUrl : slot.mediaUrl,
  );
  final safeHref = _safeHomePromoSlotHref(slot.ctaHref);
  if (body.isNotEmpty || safeImage != null) {
    return true;
  }
  return title.isNotEmpty && safeHref != null;
}

Color? _promoHexColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    return null;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}

Uri? _safeHomePromoImageUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host != 'pokrov.space' && !host.endsWith('.pokrov.space')) {
    return null;
  }
  return uri;
}

Uri? _safeHomePromoSlotHref(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'tg' && (host == 'resolve' || host == 'join')) {
    return uri;
  }
  if (scheme == 'https' && host.isNotEmpty) {
    return uri;
  }
  return null;
}

Widget _fadeSlideTransition(Widget child, Animation<double> animation) {
  return pokrovFadeSlideTransition(child, animation);
}

class _MotionSkeletonList extends PokrovSkeletonList {
  const _MotionSkeletonList({super.rows = 4});
}
