import 'package:http/http.dart' as http;
import 'dart:convert';

class Peticionesapi {
  // ignore: non_constant_identifier_names
  static Future<Map<String, dynamic>?> ObtenerCancionActual(
    String token,
  ) async {
    final Uri url = Uri.parse(
      'https://api.spotify.com/v1/me/player/currently-playing',
    );

    try {
      final respuesta = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      // 204 indica que el reproductor está pausado o inactivo
      if (respuesta.statusCode == 204) return null;
      if (respuesta.statusCode == 200) {
        return jsonDecode(respuesta.body);
      }
    } catch (e) {
      print("Error al obtener la cancion actual: $e");
      return null;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> obtenerColaReproduccion(
    String token,
  ) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/queue');
    try {
      final respuesta = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (respuesta.statusCode == 200) {
        return jsonDecode(respuesta.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error obteniendo la cola: $e");
      return null;
    }
  }

  static Future<bool> anadirCancionACola(
    String token,
    String uriCancion,
  ) async {
    final url = Uri.parse(
      'https://api.spotify.com/v1/me/player/queue?uri=$uriCancion',
    );
    try {
      final respuesta = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      return respuesta.statusCode == 204;
    } catch (e) {
      print("Error al añadir a la cola: $e");
      return false;
    }
  }

  static Future<bool> saltarSiguienteCancion(String token) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/next');
    try {
      final respuesta = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      return respuesta.statusCode == 204;
    } catch (e) {
      print("Error al saltar canción: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> buscarCanciones(
    String query,
    String token,
  ) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      'https://api.spotify.com/v1/search?q=$query&type=track&limit=10',
    );

    try {
      final respuesta = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        final List cancionesJson = datos['tracks']['items'] ?? [];

        return cancionesJson
            .map<Map<String, dynamic>>(
              (track) => {
                'id': track['id'],
                'titulo': track['name'],
                'artista': track['artists'][0]['name'],
                'urlImagen': track['album']['images'].isNotEmpty
                    ? track['album']['images'][0]['url']
                    : '',
              },
            )
            .toList();
      }
      return [];
    } catch (e) {
      print("Error buscando canciones: $e");
      return [];
    }
  }

  static Future<bool> anadirACola(String idCancion, String token) async {
    // Formatea al identificador URI requerido por Spotify
    String uriFormateada = idCancion.contains('spotify:track:')
        ? idCancion
        : 'spotify:track:$idCancion';

    final url = Uri.parse(
      'https://api.spotify.com/v1/me/player/queue?uri=$uriFormateada',
    );

    try {
      final respuesta = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Spotify responde 200 o 204 tras encolar exitosamente
      return respuesta.statusCode == 200 || respuesta.statusCode == 204;
    } catch (e) {
      print("❌ Error de conexión al añadir a la cola: $e");
      return false;
    }
  }
}
