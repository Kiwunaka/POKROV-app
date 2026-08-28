class CachedProfileFallbackGate {
  static const maximumRefreshWait = Duration(seconds: 15);

  bool _blockedUntilFreshProfile = false;

  static Duration refreshDeadline(Duration actionTimeout) {
    return actionTimeout < maximumRefreshWait
        ? actionTimeout
        : maximumRefreshWait;
  }

  bool canFallback({required bool cachedProfileAvailable}) {
    return cachedProfileAvailable && !_blockedUntilFreshProfile;
  }

  void markUserChange() {
    _blockedUntilFreshProfile = true;
  }

  /// A failed dataplane is not evidence that the staged authorization is
  /// still valid. Keep normal offline fallback available until that point,
  /// then require a fresh managed profile before the next connect.
  void markRuntimeProfileInvalid() {
    _blockedUntilFreshProfile = true;
  }

  void markFreshProfileStaged() {
    _blockedUntilFreshProfile = false;
  }
}
