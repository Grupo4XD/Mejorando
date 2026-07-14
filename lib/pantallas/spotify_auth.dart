import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centraliza TODO lo relacionado con las credenciales y los tokens de Spotify.
///
/// ¿Por qué una sola clase? Porque antes las llaves y la lógica del token
/// estaban repartidas por varias pantallas. Al tenerlas en un solo lugar:
///   1. Si algo cambia, lo cambias aquí y ya.
///   2. Cuando migremos a PKCE, solo tocamos ESTE archivo.
///   3. Es más fácil de entender y de proteger.
class SpotifyAuth {
  // ⚠️ TEMPORAL: estas llaves siguen dentro de la app (igual que antes).
  // En el siguiente paso las moveremos a un .env y migraremos a PKCE para
  // ELIMINAR el clientSecret por completo. Por ahora solo las centralizamos.
  static const String clientId = 'cf4410e8df834a21998c3fe4d6518987';
  static const String clientSecret = 'eb34c8686e6044b9b6a2fcc6b37e9bb1';

  static const String _urlToken = 'https://accounts.spotify.com/api/token';

  /// Pide a Spotify un access_token NUEVO usando el refresh_token.
  ///
  /// Este es el corazón del asunto: el refresh_token es como una "membresía"
  /// que canjeas por un "ticket" (access_token) nuevo sin volver a loguearte.
  ///
  /// Devuelve un mapa con:
  ///   - 'access_token' : el token nuevo (dura ~1 hora)
  ///   - 'expires_in'   : cuántos segundos vive (normalmente 3600)
  ///   - 'refresh_token': a veces Spotify manda uno nuevo; si no, viene null
  /// Si algo falla, devuelve null.
  /// 
  static Future<Map<String, dynamic>?> refrescarToken(
    String refreshToken,
  ) async {
    try {
      final respuesta = await http.post(
        Uri.parse(_urlToken),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          // Fíjate: aquí el grant_type cambia. En el login era
          // 'authorization_code'; para refrescar es 'refresh_token'.
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
          // OJO: Spotify NO siempre devuelve un refresh_token nuevo.
          // Si no viene, seguimos usando el que ya teníamos.
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

  /// Se asegura de que la sala tenga un access_token VÁLIDO.
  ///
  /// Este es el método que usarás desde la pantalla. Su trabajo:
  ///   1. Lee el token y su fecha de expiración desde Firestore.
  ///   2. Si el token todavía sirve → lo devuelve tal cual (no gasta llamadas).
  ///   3. Si expiró (o está a punto) → lo refresca, lo guarda en Firestore
  ///      y devuelve el nuevo. Al guardarlo en Firestore, TODOS los invitados
  ///      lo reciben solos por su stream.
  ///
  /// Devuelve el access_token válido, o null si no se pudo obtener.
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

    // Refrescamos 1 minuto ANTES de que muera. ¿Por qué el margen? Para no
    // quedarnos a mitad de una petición con un token que expiró hace 1 segundo.
    final ahora = DateTime.now();
    final bool sigueValido =
        expiraEn != null &&
        ahora.isBefore(expiraEn.toDate().subtract(const Duration(minutes: 1)));

    if (accessToken != null && sigueValido) {
      return accessToken; // Todavía sirve; no gastamos una llamada de más.
    }

    // Sin refresh_token no hay nada que hacer: devolvemos lo que había.
    if (refreshToken == null) return accessToken;

    print('🔄 Token expirado o por expirar. Refrescando...');
    final resultado = await refrescarToken(refreshToken);
    if (resultado == null) return accessToken; // Falló; devolvemos lo previo.

    final String nuevoToken = resultado['access_token'];
    final int expiresIn = resultado['expires_in'];
    final String? nuevoRefresh = resultado['refresh_token'];

    final nuevaExpiracion = DateTime.now().add(Duration(seconds: expiresIn));

    // Guardamos el token nuevo en Firestore. Este es el paso clave que hace
    // que los invitados se enteren automáticamente (por su stream).
    await docRef.update({
      'spotify_access_token': nuevoToken,
      'expira_token_en': Timestamp.fromDate(nuevaExpiracion),
      // Solo pisamos el refresh_token si Spotify nos dio uno nuevo:
      if (nuevoRefresh != null) 'spotify_refresh_token': nuevoRefresh,
    });

    print('✅ Token refrescado. Nuevo vencimiento: $nuevaExpiracion');
    return nuevoToken;
  }
}
