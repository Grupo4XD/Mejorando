import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centraliza credenciales y manejo de tokens de Spotify.
class SpotifyAuth {
  static const String clientId = 'cf4410e8df834a21998c3fe4d6518987';
  static const String clientSecret = 'eb34c8686e6044b9b6a2fcc6b37e9bb1';

  static const String _urlToken = 'https://accounts.spotify.com/api/token';

  /// Solicita un nuevo access_token a Spotify utilizando el refresh_token.
  static Future<Map<String, dynamic>?> refrescarToken(
    String refreshToken,
  ) async {
    try {
      final respuesta = await http.post(
        Uri.parse(_urlToken),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        return {
          'access_token': datos['access_token'],
          'expires_in': datos['expires_in'] ?? 3600,
          // Spotify no siempre renueva el refresh_token; si viene null se preserva el anterior
          'refresh_token': datos['refresh_token'],
        };
      } else {
        print(
          '❌ Error al refrescar token: ${respuesta.statusCode} ${respuesta.body}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Excepción al refrescar token: $e');
      return null;
    }
  }

  /// Comprueba la validez del access_token de la sala. Si expiró o está por vencer,
  /// lo renueva y lo guarda en Firestore para propagarlo en tiempo real a todos los clientes.
  static Future<String?> obtenerTokenValidoDeSala(String codigoSala) async {
    final docRef = FirebaseFirestore.instance
        .collection('salas')
        .doc(codigoSala);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return null;
    final datos = snapshot.data()!;

    final String? accessToken = datos['spotify_access_token'];
    final String? refreshToken = datos['spotify_refresh_token'];
    final Timestamp? expiraEn = datos['expira_token_en'];

    // Se renueva con 1 minuto de margen para evitar fallas a mitad de una petición
    final ahora = DateTime.now();
    final bool sigueValido =
        expiraEn != null &&
        ahora.isBefore(expiraEn.toDate().subtract(const Duration(minutes: 1)));

    if (accessToken != null && sigueValido) {
      return accessToken;
    }

    if (refreshToken == null) return accessToken;

    print('🔄 Token expirado o por expirar. Refrescando...');
    final resultado = await refrescarToken(refreshToken);
    if (resultado == null) return accessToken;

    final String nuevoToken = resultado['access_token'];
    final int expiresIn = resultado['expires_in'];
    final String? nuevoRefresh = resultado['refresh_token'];

    final nuevaExpiracion = DateTime.now().add(Duration(seconds: expiresIn));

    // Guardar en Firestore para actualizar en tiempo real a todos los invitados
    await docRef.update({
      'spotify_access_token': nuevoToken,
      'expira_token_en': Timestamp.fromDate(nuevaExpiracion),
      if (nuevoRefresh != null) 'spotify_refresh_token': nuevoRefresh,
    });

    print('✅ Token refrescado. Nuevo vencimiento: $nuevaExpiracion');
    return nuevoToken;
  }
}
