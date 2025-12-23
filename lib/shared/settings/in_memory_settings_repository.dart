import 'app_settings.dart';
import 'settings_repository.dart';

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _cache = AppSettings.defaults();

  @override
  Future<AppSettings> load() async => _cache;

  @override
  Future<void> save(AppSettings settings) async {
    _cache = settings;
  }

  @override
  Future<void> reset() async {
    _cache = AppSettings.defaults();
  }
}
