import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kUsername = 'bio_u';
  static const _kPassword = 'bio_p';

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Verify your identity to sign in'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCredentials(String username, String password) async {
    await _store.write(key: _kUsername, value: username);
    await _store.write(key: _kPassword, value: password);
  }

  Future<Map<String, String>?> loadCredentials() async {
    final u = await _store.read(key: _kUsername);
    final p = await _store.read(key: _kPassword);
    if (u == null || u.isEmpty || p == null) return null;
    return {'username': u, 'password': p};
  }

  Future<bool> hasCredentials() async {
    final u = await _store.read(key: _kUsername);
    return u != null && u.trim().isNotEmpty;
  }

  Future<String?> savedUsername() async {
    return _store.read(key: _kUsername);
  }

  Future<void> clearCredentials() async {
    await _store.delete(key: _kUsername);
    await _store.delete(key: _kPassword);
  }
}
