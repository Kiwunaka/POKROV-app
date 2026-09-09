[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

function Read-RepoText([string]$RelativePath) {
  $path = Join-Path $root $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $errors.Add("Missing boundary input: $RelativePath")
    return ""
  }
  return [System.IO.File]::ReadAllText($path)
}

$homeSurface = Read-RepoText "packages\app_shell\lib\src\features\home\home_surface.dart"
$seed = Read-RepoText "packages\app_shell\lib\src\shell\seed_shell.dart"
$connection = Read-RepoText "packages\app_shell\lib\src\features\home\connection_experience.dart"
$onboarding = Read-RepoText "packages\app_shell\lib\src\features\onboarding\onboarding_flow.dart"
$protectionCenter = Read-RepoText "packages\app_shell\lib\src\features\home\protection_center.dart"
$clientUpdate = Read-RepoText "packages\app_shell\lib\src\features\update\client_update.dart"
$bootstrap = Read-RepoText "packages\app_shell\lib\app_first_runtime_bootstrap.dart"
$appShell = Read-RepoText "packages\app_shell\lib\app_shell.dart"

if ($seed -notmatch [regex]::Escape("late final ManagedProfileLifecycle _managedProfileLifecycle;")) {
  $errors.Add("Composition root must delegate profile lifecycle to its standalone owner.")
}
foreach ($forbidden in @("bool _managedProfileDirty =", "int _managedProfileRevision =", "_quickSettingsInvalidationInFlight", "_managedProfileInvalidationTimer")) {
  if ($seed -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root retained raw profile lifecycle state: '$forbidden'.")
  }
}

if ($seed -notmatch [regex]::Escape("late final ConnectionCoordinator _connectionCoordinator;")) {
  $errors.Add("Composition root must own one ConnectionCoordinator boundary.")
}
foreach ($forbidden in @(
  "RuntimeSnapshot? _runtimeSnapshot;",
  "bool _runtimeBusy = false;",
  "ConnectionTransitionIntent _runtimeIntent = ConnectionTransitionIntent.none;",
  "DateTime? _connectionAttemptStartedAt;",
  "int _connectionAttemptNumber = 0;"
)) {
  if ($seed -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root retained raw connection state: '$forbidden'.")
  }
}
if ($seed -match [regex]::Escape("_processedAcquisitionHandles")) {
  $errors.Add("Composition root must not own or persist opaque acquisition handles.")
}
foreach ($required in @(
  "FirstSessionAcquisitionState",
  "FirstSessionVpnPermissionState",
  "bool beginAcquisition(String handle)",
  "bool beginVpnPermissionExplanation()",
  "bool markFirstVerifiedConnectSeen()",
  "ValueKey('vpn-permission-explainer')"
)) {
  if ($onboarding -notmatch [regex]::Escape($required)) {
    $errors.Add("First-session coordinator boundary must contain '$required'.")
  }
}
foreach ($required in @(
  "abstract interface class AppFirstFirstSessionEventService",
  "'surface': 'first_session'",
  "'subsystem': 'onboarding'"
)) {
  if ($bootstrap -notmatch [regex]::Escape($required)) {
    $errors.Add("Safe first-session analytics boundary must contain '$required'.")
  }
}

if ($seed -notmatch [regex]::Escape("late final DiagnosticsCoordinator _diagnosticsCoordinator;")) {
  $errors.Add("Composition root must own one DiagnosticsCoordinator boundary.")
}
foreach ($forbidden in @(
  "bool _runtimeResumeRefreshPending = false;",
  "Timer? _postConnectHealthTimer;",
  "int _postConnectHealthGeneration = 0;",
  "int? _postConnectHealthPollInFlight;"
)) {
  if ($seed -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root retained raw diagnostics lifecycle state: '$forbidden'.")
  }
}

if ($seed -notmatch [regex]::Escape("late final AccountSessionCoordinator _accountSessionCoordinator;")) {
  $errors.Add("Composition root must own one AccountSessionCoordinator boundary.")
}
foreach ($forbidden in @(
  "late final AppFirstAccountActionService? _accountActionService;",
  "FreeProfileAccess? _freeProfileAccess;",
  "ClientSubscriptionInfo? _subscriptionInfo;"
)) {
  if ($seed -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root retained raw account/session state: '$forbidden'.")
  }
}

if ($seed -notmatch [regex]::Escape("late final FirstSessionCoordinator _firstSessionCoordinator;")) {
  $errors.Add("Composition root must own one FirstSessionCoordinator boundary.")
}
foreach ($forbidden in @(
  "late final PokrovFirstLaunchStore _firstLaunchStore;",
  "bool _firstLaunchBusy = false;",
  "_FirstLaunchStep _firstLaunchStep = _FirstLaunchStep.choice;",
  "bool _firstLaunchExitAnimated = false;"
)) {
  if ($seed -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root retained raw first-session state: '$forbidden'.")
  }
}

if ($seed -notmatch [regex]::Escape("final ClientUpdateCoordinator _clientUpdateCoordinator")) {
  $errors.Add("Composition root must own one ClientUpdateCoordinator boundary.")
}
foreach ($forbidden in @(
  "bool _clientUpdateCheckBusy = false;",
  "bool _clientUpdatePromptVisible = false;",
  "String _lastPromptedUpdateKey = '';",
  "ValueKey('client-update-prompt')",
  "ValueKey('client-update-download-progress')"
)) {
  if ($seed -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root retained update state or presentation: '$forbidden'.")
  }
}
foreach ($required in @(
  "class ClientUpdateCoordinator",
  "Future<void> checkAndPresent",
  "Future<void> showPokrovClientUpdatePrompt",
  "class PokrovClientUpdateProgressDialog",
  "ValueKey('client-update-prompt')",
  "ValueKey('client-update-download-progress')"
)) {
  if ($clientUpdate -notmatch [regex]::Escape($required)) {
    $errors.Add("Client update owner must contain '$required'.")
  }
}
if ($appShell -match "(?m)^part 'src/features/update/client_update\.dart';") {
  $errors.Add("Client update owner must remain an ordinary imported library.")
}

foreach ($required in @(
  "class ProtectionViewState",
  "final ConnectionPresentation connection;",
  "class ProtectionIntents",
  "this.slowStageThreshold = const Duration(seconds: 10)",
  "bool get slowStageVisible"
)) {
  if ($connection -notmatch [regex]::Escape($required)) {
    $errors.Add("Connection presentation boundary must contain '$required'.")
  }
}

foreach ($required in @(
  "class _ProtectionCenterController extends ChangeNotifier",
  "late final _ProtectionCenterController _controller;",
  "ValueKey('protection-summary')",
  "ValueKey('protection-details-toggle')",
  "ValueKey('protection-repair-confirmation')",
  "ValueKey('protection-repair-progress')",
  "ValueKey('protection-repair-outcome')"
)) {
  if ($protectionCenter -notmatch [regex]::Escape($required)) {
    $errors.Add("Protection Center boundary must contain '$required'.")
  }
}
if ($homeSurface -notmatch [regex]::Escape("ValueKey('home-slow-connection-notice')")) {
  $errors.Add("Home must expose the guarded long-connect disclosure.")
}
if ($homeSurface -notmatch [regex]::Escape("ValueKey('home-vpn-permission-recovery')")) {
  $errors.Add("Home must expose the guarded VPN-permission recovery action.")
}

$quickConnect = [regex]::Match(
  $homeSurface,
  "(?s)class _QuickConnectSection.*?(?=class _HomeStage)"
).Value
if ([string]::IsNullOrWhiteSpace($quickConnect)) {
  $errors.Add("Could not resolve the Home quick-connect boundary.")
} else {
  foreach ($required in @(
    "final ProtectionViewState protectionState;",
    "final ProtectionIntents protectionIntents;"
  )) {
    if ($quickConnect -notmatch [regex]::Escape($required)) {
      $errors.Add("Home quick-connect must consume '$required'.")
    }
  }
  foreach ($forbidden in @(
    "final ConnectionPresentation connectionPresentation;",
    "final String? runtimeHeadline;",
    "final Future<void> Function() onToggleRuntime;",
    "final VoidCallback onOpenConnectionDetails;"
  )) {
    if ($quickConnect -match [regex]::Escape($forbidden)) {
      $errors.Add("Home quick-connect leaked a parallel protection prop: '$forbidden'.")
    }
  }
}

$seedHomeCall = [regex]::Match(
  $seed,
  "(?s)_QuickConnectSection\(.*?(?=\(context\) => _LocationsSection)"
).Value
foreach ($required in @("protectionState: protectionState", "protectionIntents: protectionIntents")) {
  if ($seedHomeCall -notmatch [regex]::Escape($required)) {
    $errors.Add("Composition root must pass '$required' to Home.")
  }
}
foreach ($forbidden in @("connectionPresentation:", "runtimeHeadline:", "onToggleRuntime:", "onOpenConnectionDetails:")) {
  if ($seedHomeCall -match [regex]::Escape($forbidden)) {
    $errors.Add("Composition root leaked '$forbidden' through the Home constructor.")
  }
}

$partCount = [regex]::Matches($appShell, "(?m)^part '").Count
if ($partCount -gt 29) {
  $errors.Add("app_shell.dart part count increased from the guarded ceiling of 29 to $partCount.")
}

$directHaptics = @(
  Get-ChildItem -LiteralPath (Join-Path $root "packages\app_shell\lib\src") -Recurse -File -Filter "*.dart" |
    Select-String -Pattern "HapticFeedback\."
)
$unexpectedHaptics = @($directHaptics | Where-Object {
  $_.Path -notmatch "src[\\/]shared[\\/]pokrov_haptics\.dart$"
})
foreach ($match in $unexpectedHaptics) {
  $errors.Add("Direct haptic call must use PokrovHaptics: $match")
}

if ($errors.Count -gt 0) {
  Write-Host "Client presentation boundary check failed." -ForegroundColor Red
  $errors | ForEach-Object { Write-Host $_ }
  exit 1
}

Write-Host "Client presentation boundary OK: aggregate Home state/intents, five coordinators, update feature owner, progressive protection disclosure, $partCount parts, centralized haptics." -ForegroundColor Green
exit 0
