import 'package:shared_preferences/shared_preferences.dart';

class PopupSuppressionStore {
  PopupSuppressionStore({Future<SharedPreferences>? preferences}) : _preferences = preferences ?? SharedPreferences.getInstance();
  final Future<SharedPreferences> _preferences;
  String _key(String church, String popup) => 'popup_notice.dismissed.v1/$church/$popup';
  String dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  Future<bool> isSuppressedToday(String church, String popup, DateTime now) async => (await _preferences).getString(_key(church, popup)) == dateKey(now.toLocal());
  Future<void> suppressToday(String church, String popup, DateTime now) async => (await _preferences).setString(_key(church, popup), dateKey(now.toLocal()));
}
