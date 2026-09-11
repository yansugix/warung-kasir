import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final AppSettings instance = AppSettings._internal();
  AppSettings._internal();

  static const _keyStoreName = 'store_name';
  static const _keyStoreAddress = 'store_address';
  static const _keyStorePhone = 'store_phone';
  static const _keyLastBackup = 'last_backup';

  Future<String> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreName) ?? 'Warung Kasir';
  }

  Future<void> setStoreName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoreName, value);
  }

  Future<String> getStoreAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreAddress) ?? '';
  }

  Future<void> setStoreAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoreAddress, value);
  }

  Future<String> getStorePhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStorePhone) ?? '';
  }

  Future<void> setStorePhone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorePhone, value);
  }

  Future<String?> getLastBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastBackup);
  }

  Future<void> setLastBackup(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackup, value);
  }

  Future<Map<String, String>> getStoreInfo() async {
    return {
      'name': await getStoreName(),
      'address': await getStoreAddress(),
      'phone': await getStorePhone(),
    };
  }
}
