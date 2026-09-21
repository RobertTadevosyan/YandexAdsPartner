import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adpocket/services/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('tokens live in secure storage, not in SharedPreferences', () async {
    await TokenStorage.saveToken('abc');
    await TokenStorage.saveInventoryToken('inv');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('oauth_token'), isNull);
    expect(prefs.getString('inventory_token'), isNull);
    expect(await TokenStorage.getToken(), 'abc');
    expect(await TokenStorage.getInventoryToken(), 'inv');
    expect(await const FlutterSecureStorage().read(key: 'oauth_token'), 'abc');
  });

  test('clearing removes the token', () async {
    await TokenStorage.saveToken('abc');
    await TokenStorage.clearToken();
    expect(await TokenStorage.getToken(), isNull);
  });

  test('legacy SharedPreferences token is migrated and removed', () async {
    SharedPreferences.setMockInitialValues({'oauth_token': 'legacy'});
    expect(await TokenStorage.getToken(), 'legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('oauth_token'), isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'oauth_token'),
      'legacy',
    );
  });
}
