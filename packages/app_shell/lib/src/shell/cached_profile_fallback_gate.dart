class CachedProfileFallbackGate {
  static const maximumRefreshWait = Duration(seconds: 3);

  static bool isCacheTimestampFresh({
    required DateTime modifiedAt,
    required DateTime now,
  }) {
    final age = now.difference(modifiedAt);
    return !age.isNegative && age <= const Duration(hours: 24);
  }

  bool _blockedUntilFreshProfile = false;
  bool _authorizationDenied = false;
  bool preferProvenProfile = false;

  static Duration refreshDeadline(Duration actionTimeout) {
    return actionTimeout < maximumRefreshWait
        ? actionTimeout
        : maximumRefreshWait;
  }

  bool canFallback({required bool cachedProfileAvailable, bool inputsVerified = false}) {
    return cachedProfileAvailable && !_authorizationDenied &&
        (inputsVerified || !_blockedUntilFreshProfile);
  }

  void markUserChange() {
    _blockedUntilFreshProfile = true;
  }

  void markAuthorizationDenied() {
    _authorizationDenied = true;
  }

  /// A transport failure is not an authorization denial. Prefer the last
  /// proven profile on a manual retry without extending its offline window.
  void markRuntimeFailure() {
    preferProvenProfile = true;
  }

  void markFreshProfileStaged() {
    _blockedUntilFreshProfile = false;
    _authorizationDenied = false;
    preferProvenProfile = false;
  }
}
