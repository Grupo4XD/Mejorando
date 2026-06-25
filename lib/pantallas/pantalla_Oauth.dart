import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Inicio.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Sala.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class PantallaOauth extends StatefulWidget {
  final String nombreUsuario; // <-- Agregamos esta línea
  const PantallaOauth({super.key, required this.nombreUsuario});

  @override
  State<PantallaOauth> createState() => _PantallaOauthState();
}

class _PantallaOauthState extends State<PantallaOauth> {
  late WebViewController _controller;

  bool cargando = false;
  String? error_autenticacion;

  Future<void> _procesarToken(String codigoAutorizacion) async {
    Map<String, dynamic>? resultado = await canjearCodigoPorToken(
      codigoAutorizacion,
    );

    if (resultado != null && mounted) {
      // ¡NUEVA LÓGICA AQUÍ!
      // Verificamos si la función anterior nos devolvió un error (Usuario Free)
      if (resultado.containsKey('error') && resultado['error'] == true) {
        setState(() {
          cargando = false;
        });

        // Le mostramos un cartel al usuario y lo mandamos a la pantalla de inicio
        _mostrarErrorPremium(resultado['mensaje']);
        return; // Detenemos la ejecución de esta función
      }

      // Si no hay error, el flujo continúa normal (Es Premium)
      String tokencito = resultado['token']!;
      String codigoDeLaSala = resultado['codigoSala']!;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PantallaSala(
            token: tokencito,
            codigoSala: codigoDeLaSala,
            nombreUsuarioActual: widget.nombreUsuario,
          ),
        ),
      );
    } else {
      setState(() {
        cargando = false;
        print("Algo ocurrió mal");
      });
    }
  }

  // Función para mostrar el cartel si el usuario no es Premium
  void _mostrarErrorPremium(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga al usuario a tocar el botón
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Disenos.colorFondoSuperior, // Usamos tu paleta
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: Text(
            "Cuenta no compatible",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          content: Text(
            mensaje,
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                // Cerramos el diálogo y enviamos al usuario al principio
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PantallaInicio(),
                  ),
                  (route) => false,
                );
              },
              child: Text("Entendido", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Cambiamos el retorno a Future<String?> por si ocurre un error
  Future<Map<String, dynamic>?> canjearCodigoPorToken(
    String codigoAutorizacion,
  ) async {
    final String urlSpotify = 'https://accounts.spotify.com/api/token';
    final String clientId = 'cf4410e8df834a21998c3fe4d6518987';
    final String clientSecret = 'eb34c8686e6044b9b6a2fcc6b37e9bb1';
    final String redirectUri = 'https://macrobyte.site';

    print("🔄 Enviando petición a Spotify...");
    print("📝 Código de autorización: $codigoAutorizacion");

    try {
      final respuesta = await http.post(
        Uri.parse(urlSpotify),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': codigoAutorizacion,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      print("📡 Status code: ${respuesta.statusCode}");
      print("📦 Respuesta: ${respuesta.body}");

      if (respuesta.statusCode == 200) {
        final datosJson = jsonDecode(respuesta.body);
        String token = datosJson['access_token'];
        String refreshToken = datosJson['refresh_token'];

        print("👤 Obteniendo identidad del usuario en Spotify...");

        // 1. NUEVO: Le pedimos a Spotify el perfil del usuario usando su token
        final respuestaPerfil = await http.get(
          Uri.parse('https://api.spotify.com/v1/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        String spotifyId = 'desconocido';

        if (respuestaPerfil.statusCode == 200) {
          // Guardamos el JSON decodificado en una variable
          final perfilData = jsonDecode(respuestaPerfil.body);

          spotifyId = perfilData['id'];
          print("🆔 ID de Spotify detectado: $spotifyId");

          // Leemos el tipo de suscripción del usuario
          String tipoSuscripcion = perfilData['product'] ?? 'free';

          if (tipoSuscripcion != 'premium') {
            // El usuario es Free.
            print("🚫 El usuario es Free. Deteniendo creación de sala.");

            // Devolvemos un mapa especial indicando el error
            return {
              "error": true,
              "mensaje":
                  "Necesitas Spotify Premium para ser el anfitrión de una sala.",
            };
          }
        }

        // 2. NUEVO: Buscamos si este usuario ya tenía una sala abierta y la eliminamos
        if (spotifyId != 'desconocido') {
          final salasAnteriores = await FirebaseFirestore.instance
              .collection('salas')
              .where('spotify_id', isEqualTo: spotifyId) // Buscamos su ID
              .get();

          for (var doc in salasAnteriores.docs) {
            await doc.reference.delete(); // Borramos la sala vieja
            print("🗑️ Sala antigua huérfana eliminada: ${doc.id}");
          }
        }
        // Calculamos la hora de expiración: El momento actual + 4 horas
        DateTime horaDeMuerte = DateTime.now().add(const Duration(hours: 4));

        // 3. Generamos el nuevo código de sala y lo guardamos
        String codigoSala = (1000 + Random().nextInt(9000)).toString();

        print("🏠 Creando NUEVA sala con código: $codigoSala");
        try {
          print("🧹 El conserje está buscando salas fantasma...");

          final salasBasura = await FirebaseFirestore.instance
              .collection('salas')
              .where('expira_en', isLessThan: Timestamp.now())
              .limit(5)
              .get();

          // Si encontró salas viejas, las borra una por una
          for (var sala in salasBasura.docs) {
            print("🗑️ Borrando sala huérfana: ${sala.id}");
            await sala.reference.delete();
          }
        } catch (e) {
          print(
            "Error en el conserje: $e",
          ); // Si falla por falta de internet, no pasa nada, la app sigue
        }

        // 2. AQUÍ SIGUE TU CÓDIGO NORMAL PARA CREAR LA NUEVA SALA...
        // DateTime horaDeMuerte = DateTime.now().add(const Duration(hours: 4));
        // String codigoSala = ...

        await FirebaseFirestore.instance
            .collection('salas')
            .doc(codigoSala)
            .set({
              'codigo_sala': codigoSala,
              'spotify_access_token': token,
              'spotify_refresh_token': refreshToken,
              'spotify_id': spotifyId, // <-- Guardamos su ID de Spotify aquí
              'usuarios': [widget.nombreUsuario],
              'creado_en': FieldValue.serverTimestamp(),
              // NUEVO CAMPO: Le decimos a Firebase cuándo destruir esta sala
              'expira_en': Timestamp.fromDate(horaDeMuerte),
            });

        print("✅ Sala creada en Firestore");
        return {"token": token, "codigoSala": codigoSala};
      } else {
        print("Error de autenticacion");
        return null;
      }
    } catch (e) {
      print("Exepcion: $e");
      setState(() {
        error_autenticacion = "Error de conexión: $e";
      });
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // IMPORTANTE: Convertimos esta función en asíncrona (async)
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://macrobyte.site')) {
              Uri uri = Uri.parse(request.url);
              String? codigoAutorizacion = uri.queryParameters['code'];

              if (codigoAutorizacion != null) {
                setState(() {
                  cargando = true;
                });

                // Llamamos sin await, dejamos que corra en paralelo
                _procesarToken(codigoAutorizacion);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          'https://accounts.spotify.com/authorize?client_id=cf4410e8df834a21998c3fe4d6518987&response_type=code&redirect_uri=https://macrobyte.site&scope=user-modify-playback-state%20user-read-currently-playing%20user-read-playback-state%20user-read-private%20user-read-email',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A1A), // Tu fondo oscuro de Rockola
      body: Container(
        decoration: Variables.fondobody,
        child: cargando
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Disenos.colorVerdeNeon, // Tu color cian brillante
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Cargando sala",
                      style: GoogleFonts.comfortaa(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
