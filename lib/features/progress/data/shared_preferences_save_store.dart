import 'package:shared_preferences/shared_preferences.dart';

import 'progress_repository.dart';

class SharedPreferencesSaveStore implements KeyValueSaveStore {
  SharedPreferencesSaveStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  @override
  Future<String?> read(String key) => _preferences.getString(key);
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}
