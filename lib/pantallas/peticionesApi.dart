import 'package:http/http.dart' as http;
import 'dart:convert';

class Peticionesapi {
  //1. Obtener la cancion actual
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
      if (respuesta.statusCode == 204) return null;
      // Spotify regresa 200 si hay música sonando, o 204 si el reproductor está pausado/vacío
      if (respuesta.statusCode == 200) {
        return jsonDecode(respuesta.body);
      }
    } catch (e) {
      print("Error al obtener la cancion actual $e");
      return null;
    }
    return null;
  }

  //2. Obtener las peticiones
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

  // 3. Añadir una canción a la cola mediante su ID o URI de Spotify
  static Future<bool> anadirCancionACola(
    String token,
    String uriCancion,
  ) async {
    // Spotify pide la URI como un parámetro de consulta (Query Parameter)
    final url = Uri.parse(
      'https://api.spotify.com/v1/me/player/queue?uri=$uriCancion',
    );
    try {
      final respuesta = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Para añadir a la cola, Spotify responde con 204 (No Content) si fue exitoso
      return respuesta.statusCode == 204;
    } catch (e) {
      print("Error al añadir a la cola: $e");
      return false;
    }
  }

  // 4. Saltar a la siguiente canción (Next)
  static Future<bool> saltarSiguienteCancion(String token) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/next');
    try {
      final respuesta = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // Spotify responde 204 cuando salta la canción con éxito
      return respuesta.statusCode == 204;
    } catch (e) {
      print("Error al dar Next: $e");
      return false;
    }
  }

  // 5. FUNCIÓN PARA BUSCAR CANCIONES
  static Future<List<Map<String, dynamic>>> buscarCanciones(
    String query,
    String token,
  ) async {
    // Si el usuario borra todo el texto, devolvemos una lista vacía de inmediato sin gastar internet
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
        print("El resultadpo de la busqueda es la siguiente: $cancionesJson");

        // Convertimos la respuesta en una lista limpia de mapas para nuestra interfaz
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
      print("Error buscando: $e");
      return [];
    }
  }

  // 6. FUNCIÓN PARA AÑADIR A LA COLA DE REPRODUCCIÓN
  static Future<bool> anadirACola(String idCancion, String token) async {
    // 1. Asegurarnos del formato URI de Spotify
    String uriFormateada = idCancion.contains('spotify:track:')
        ? idCancion
        : 'spotify:track:$idCancion';

    final url = Uri.parse(
      'https://api.spotify.com/v1/me/player/queue?uri=$uriFormateada',
    ); // Tu endpoint

    try {
      final respuesta = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
        // Si tu API requiere que le mandes el ID en el body, asegúrate de pasarlo aquí:
        // body: {'uri': uriFormateada}
      );

      print("📡 Status Añadir a Cola: ${respuesta.statusCode}");
      print("📦 Body Añadir a Cola: ${respuesta.body}");

      // 🔥 EL ARREGLO: Aceptamos tanto 200 (OK) como 204 (No Content) como un éxito rotundo
      return respuesta.statusCode == 200 || respuesta.statusCode == 204;
    } catch (e) {
      print("❌ Error de conexión al añadir a la cola: $e");
      return false;
    }
  }
}
