import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/room.dart';

class RoomsRepository {
  RoomsRepository(this._api, this._config, this._auth);
  final ApiClient _api;
  final AppConfig _config;
  final AuthRepository _auth;

  Future<Room> create(String name) async => Room.fromJson(await _api.post('/rooms', data: {'displayName': name}));
  Future<Room> join(String code, String name) async => Room.fromJson(await _api.post('/rooms/$code/join', data: {'displayName': name}));
  Future<Room> get(String code) async => Room.fromJson(await _api.get('/rooms/$code'));
  Future<void> leave(String code) async { await _api.post('/rooms/$code/leave'); }
  Future<void> vote(String code) async { await _api.post('/rooms/$code/votes'); }
  Future<void> refresh(String code) async { await _api.post('/rooms/$code/refresh'); }
  Future<void> queue(String code, String trackId) async { await _api.post('/rooms/$code/queue', data: {'trackId': trackId}); }
  Future<void> setThreshold(String code, int value) async { await _api.post('/rooms/$code/threshold', data: {'skipThreshold': value}); }
  Future<List<Track>> search(String code, String query) async {
    final response = await _api.get('/rooms/$code/search', query: {'q': query});
    final data = response['data'] as List<dynamic>? ?? [];
    return data.map((item) => Track.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<io.Socket> connect(String code, void Function(Room room) onUpdate) async {
    final token = await _auth.accessToken();
    final socket = io.io('${_config.wsBaseUrl}/rooms', io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().build());
    socket.on('room:updated', (data) { if (data is Map) onUpdate(Room.fromJson(Map<String, dynamic>.from(data))); });
    socket.connect();
    socket.emit('room:subscribe', {'code': code});
    return socket;
  }
}
