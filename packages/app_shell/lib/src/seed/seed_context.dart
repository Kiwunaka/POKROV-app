part of pokrov_app_shell;

const _apiBaseUrlOverride = String.fromEnvironment(
  'POKROV_API_BASE_URL',
  defaultValue: 'https://api.pokrov.space/',
);
const _checkoutUrlOverride = String.fromEnvironment(
  'POKROV_CHECKOUT_URL',
  defaultValue: 'https://pay.pokrov.space/checkout/?plan=1_month',
);
const _cabinetUrlOverride = String.fromEnvironment(
  'POKROV_CABINET_URL',
  defaultValue: 'https://app.pokrov.space/',
);

String _normalizeSeedUrl(String value, String fallback) {
  final candidate = value.trim();
  if (candidate.isEmpty) {
    return fallback;
  }
  return candidate.endsWith('/') ? candidate : '$candidate/';
}

const _seedMainBotUsername = String.fromEnvironment(
  'POKROV_MAIN_BOT_USERNAME',
  defaultValue: 'pokrov_vpnbot',
);

class SeedAppContext {
  const SeedAppContext({
    required this.hostPlatform,
    required this.accessLane,
    required this.scope,
    required this.runtimeProfile,
    required this.bootstrapContract,
    required this.supportSnapshot,
    required this.rulesPresetContract,
    required this.locations,
    required this.apiBaseUrl,
    required this.checkoutUrl,
    required this.cabinetUrl,
    required this.redeemHint,
    required this.managedProfileSeed,
    this.mainBotUsername = _seedMainBotUsername,
  });

  final HostPlatform hostPlatform;
  final AccessLane accessLane;
  final ProgramScope scope;
  final RuntimeProfile runtimeProfile;
  final PlatformBootstrapContract bootstrapContract;
  final SupportSnapshot supportSnapshot;
  final RulesPresetContract rulesPresetContract;
  final List<LocationCluster> locations;
  final String apiBaseUrl;
  final String checkoutUrl;
  final String cabinetUrl;
  final String redeemHint;
  final ManagedProfilePayload managedProfileSeed;
  final String mainBotUsername;

  List<SeedTab> get defaultTabs => const [
        SeedTab.protection,
        SeedTab.locations,
        SeedTab.rules,
        SeedTab.profile,
      ];
}

enum RulesPresetState {
  enabled,
  staged,
  locked,
}

class RulesPresetStatus {
  const RulesPresetStatus({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String id;
  final String title;
  final String subtitle;
  final RulesPresetState state;

  bool get enabled => state == RulesPresetState.enabled;
}

class RulesPresetContract {
  const RulesPresetContract({
    required this.rulesetVersion,
    required this.packageCatalogVersion,
    required this.presets,
  });

  final String rulesetVersion;
  final String packageCatalogVersion;
  final List<RulesPresetStatus> presets;

  int get enabledCount => presets
      .where((preset) => preset.state == RulesPresetState.enabled)
      .length;
}

RulesPresetContract _seedRulesPresetContractFor(HostPlatform hostPlatform) {
  return switch (hostPlatform) {
    HostPlatform.windows => const RulesPresetContract(
        rulesetVersion: _seedRulesetVersion,
        packageCatalogVersion: _seedPackageCatalogVersion,
        presets: [
          RulesPresetStatus(
            id: 'ru-region',
            title: 'Российские сервисы',
            subtitle:
                'Российские сайты, локальные адреса и нужные RU-сервисы идут напрямую.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'local-network',
            title: 'Локальная сеть',
            subtitle: 'Домашние и рабочие адреса работают напрямую.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'full-tunnel',
            title: 'Весь трафик устройства',
            subtitle: 'Можно направить весь трафик Windows через POKROV.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'selected-apps',
            title: 'Выбранные приложения',
            subtitle: 'POKROV работает только для выбранных приложений.',
            state: RulesPresetState.enabled,
          ),
        ],
      ),
    HostPlatform.android => const RulesPresetContract(
        rulesetVersion: _seedRulesetVersion,
        packageCatalogVersion: _seedPackageCatalogVersion,
        presets: [
          RulesPresetStatus(
            id: 'ru-banks',
            title: 'Российские банки',
            subtitle: 'Карты, платежи и приложения банков идут напрямую.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'gosuslugi',
            title: 'Госуслуги',
            subtitle: 'Государственные сервисы остаются без POKROV.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'marketplaces',
            title: 'Маркетплейсы',
            subtitle: 'Покупки и доставка работают привычным способом.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'messengers',
            title: 'Мессенджеры',
            subtitle: 'Добавим после проверки.',
            state: RulesPresetState.staged,
          ),
          RulesPresetStatus(
            id: 'selected-apps',
            title: 'Выбранные приложения',
            subtitle: 'Можно выбрать приложения, которые идут через POKROV.',
            state: RulesPresetState.enabled,
          ),
        ],
      ),
    HostPlatform.ios || HostPlatform.macos => const RulesPresetContract(
        rulesetVersion: _seedRulesetVersion,
        packageCatalogVersion: _seedPackageCatalogVersion,
        presets: [
          RulesPresetStatus(
            id: 'ru-region',
            title: 'Сайты из России',
            subtitle: 'Российские сайты и локальные адреса идут напрямую.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'full-tunnel',
            title: 'Весь трафик устройства',
            subtitle: 'Весь трафик устройства идет через POKROV.',
            state: RulesPresetState.enabled,
          ),
          RulesPresetStatus(
            id: 'selected-apps',
            title: 'Выбранные приложения',
            subtitle: 'Платформа пока не дает управлять приложениями отсюда.',
            state: RulesPresetState.locked,
          ),
        ],
      ),
  };
}

const _seedManagedProfilePayload = ManagedProfilePayload(
  profileName: 'pokrov-seed-runtime',
  configPayload: '''
{
  "log": {
    "disabled": false,
    "level": "info"
  },
  "dns": {
    "servers": [
      {
        "tag": "local",
        "address": "local"
      }
    ]
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "final": "direct"
  }
}
''',
  materializedForRuntime: true,
);

SeedAppContext buildSeedAppContext({
  required HostPlatform hostPlatform,
}) {
  final bootstrapContract = switch (hostPlatform) {
    HostPlatform.android => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.android,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.vpnProfile,
          PermissionRequirement.backgroundStart,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: true,
      ),
    HostPlatform.ios => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.ios,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.vpnProfile,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: false,
      ),
    HostPlatform.macos => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.macos,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.vpnProfile,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: false,
      ),
    HostPlatform.windows => const PlatformBootstrapContract(
        hostPlatform: HostPlatform.windows,
        requiredPermissions: [
          PermissionRequirement.notifications,
          PermissionRequirement.elevatedSession,
        ],
        defaultCore: RuntimeCore.singBox,
        advancedFallbackCore: RuntimeCore.xray,
        supportsSelectedAppsMode: true,
      ),
  };

  return SeedAppContext(
    hostPlatform: hostPlatform,
    accessLane: AccessLane.trialPremium,
    scope: const ProgramScope(
      publicReleaseTargets: [
        ClientPlatform.android,
        ClientPlatform.windows,
      ],
      readinessOnlyTargets: [
        ClientPlatform.ios,
        ClientPlatform.macos,
      ],
    ),
    runtimeProfile: RuntimeProfile(
      defaultCore: RuntimeCore.singBox,
      advancedFallbackCore: RuntimeCore.xray,
      defaultRouteMode: RouteMode.allExceptRu,
      supportedRouteModes: [
        RouteMode.allExceptRu,
        RouteMode.fullTunnel,
        if (bootstrapContract.supportsSelectedAppsMode &&
            _selectedAppsEnforcementReady)
          RouteMode.selectedApps,
        if (hostPlatform == HostPlatform.android &&
            bootstrapContract.supportsSelectedAppsMode &&
            _selectedAppsEnforcementReady)
          RouteMode.excludedApps,
      ],
      trialDays: 5,
      telegramBonusDays: 5,
      freeTier: const FreeTierPolicy(
        enabled: false,
        trafficGb: 0,
        periodDays: 0,
        speedMbps: 0,
        deviceLimit: 0,
        nodePool: '',
      ),
      allowsExternalCheckoutOnly: true,
      firstPartyPromosOnly: true,
    ),
    bootstrapContract: bootstrapContract,
    supportSnapshot: const SupportSnapshot(
      supportBot: '@pokrov_supportbot',
      feedbackBot: '@pokrov_feedbackbot',
      publicChannel: '@pokrov_vpn',
      supportEmail: 'support@pokrov.space',
      safeNotes:
          'Поддержка видит только версию приложения, платформу, режим и статус подключения.',
      recommendedRouteMode: RouteMode.allExceptRu,
      channelBonusDays: 5,
    ),
    rulesPresetContract: _seedRulesPresetContractFor(hostPlatform),
    locations: const [
      LocationCluster(
        code: 'pokrov-managed',
        label: 'POKROV',
        city: 'Автоматический выбор',
        countryCode: 'PO',
        recommendedLane: 'Авто',
        variants: [
          LocationVariant(kind: TransportKind.vlessReality),
          LocationVariant(kind: TransportKind.vmess),
          LocationVariant(kind: TransportKind.trojan),
          LocationVariant(
            kind: TransportKind.xhttp,
            availability: VariantAvailability.gated,
            note: 'Откроется, когда раздел будет готов.',
          ),
        ],
      ),
    ],
    apiBaseUrl: _normalizeSeedUrl(
      _apiBaseUrlOverride,
      'https://api.pokrov.space/',
    ),
    checkoutUrl: _checkoutUrlOverride.trim().isEmpty
        ? 'https://pay.pokrov.space/checkout/?plan=1_month'
        : _checkoutUrlOverride.trim(),
    cabinetUrl: _normalizeSeedUrl(
      _cabinetUrlOverride,
      'https://app.pokrov.space/',
    ),
    redeemHint: '',
    managedProfileSeed: _seedManagedProfilePayload,
  );
}
