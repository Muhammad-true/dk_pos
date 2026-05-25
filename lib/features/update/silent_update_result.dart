class SilentUpdateResult {
  const SilentUpdateResult({
    required this.ok,
    required this.message,
    this.needsUserAction = false,
    this.restartApp = false,
  });

  final bool ok;
  final String message;
  final bool needsUserAction;
  final bool restartApp;
}

enum SilentUpdateTarget {
  server,
  posWindows,
  posAndroid,
}
