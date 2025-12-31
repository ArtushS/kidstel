/// DEV bypass toggle.
///
/// Enable with: --dart-define=DEV_BYPASS_AUTH=true
/// Disable with: --dart-define=DEV_BYPASS_AUTH=false
///
/// In release builds this is always false.
const bool _kIsReleaseMode = bool.fromEnvironment('dart.vm.product');

const bool kDevBypassAuth =
    bool.fromEnvironment('DEV_BYPASS_AUTH', defaultValue: false) &&
    !_kIsReleaseMode;
