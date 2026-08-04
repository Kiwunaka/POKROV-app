class CachedProfileFallbackGate {
  bool _blockedUntilFreshProfile = false;

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
