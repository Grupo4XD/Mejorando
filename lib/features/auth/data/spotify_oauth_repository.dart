import 'dart:math';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../core/network/api_client.dart';

class SpotifyOauthRepository {
  SpotifyOauthRepository(this._api);
  final ApiClient _api;

  Future<void> connect() async {
    final verifier = _verifier();
    final session = await _api.post('/spotify/pkce/sessions', data: {'codeVerifier': verifier});
    final result = await FlutterWebAuth2.authenticate(url: session['authorizationUrl'] as String, callbackUrlScheme: 'rockify');
    final uri = Uri.parse(result);
    if (uri.queryParameters['result'] != 'success' || uri.queryParameters['state'] != session['state']) throw const ApiException('No se pudo conectar Spotify', null);
    final status = await _api.get('/spotify/pkce/sessions/${session['state']}');
    if (status['completed'] != true || status['success'] != true) throw const ApiException('La conexión con Spotify no se completó', null);
  }

  String _verifier() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(96, (_) => characters[random.nextInt(characters.length)]).join();
  }
}
