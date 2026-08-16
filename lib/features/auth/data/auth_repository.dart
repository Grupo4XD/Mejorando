import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => throw UnimplementedError());

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<void> initialize() async {
    var deviceId = await _storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _storage.write(key: 'device_id', value: deviceId);
    }
    final response = await _api.post('/auth/anonymous', data: {'deviceId': deviceId});
    await _storage.write(key: 'access_token', value: response['accessToken'] as String);
    await _storage.write(key: 'user_id', value: response['userId'] as String? ?? '');
  }

  Future<String?> userId() => _storage.read(key: 'user_id');
  Future<String?> accessToken() => _storage.read(key: 'access_token');
}
