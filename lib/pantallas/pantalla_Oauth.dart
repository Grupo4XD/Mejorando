import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:proyecto_rockify/pantallas/spotify_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class PantallaOauth extends StatefulWidget {
  final String nombreUsuario;
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
      // Si la cuenta no es Premium, se rechaza la creación de sala
      if (resultado.containsKey('error') && resultado['error'] == true) {
        setState(() {
          cargando = false;
        });
        _mostrarErrorPremium(resultado['mensaje']);
        return;
      }

      String tokencito = resultado['token']!;
      String codigoDeLaSala = resultado['codigoSala']!;

      context.push(
        '/sala/$codigoDeLaSala',
        extra: {'token': tokencito, 'nombre': widget.nombreUsuario},
      );
    } else {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  void _mostrarErrorPremium(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Disenos.colorFondoSuperior,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: Text(
            "Cuenta no compatible",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            mensaje,
            style: GoogleFonts.poppins(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actions: [
            
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () {
                  context.go('/');
                },
                child: const Text("Entendido", style: TextStyle(color: Colors.white)),
              ),
            ),

          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> canjearCodigoPorToken(
    String codigoAutorizacion,
  ) async {
    const String urlSpotify = 'https://accounts.spotify.com/api/token';
    final String clientId = SpotifyAuth.clientId;
    final String clientSecret = SpotifyAuth.clientSecret;
    const String redirectUri = 'https://macrobyte.site';

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

      if (respuesta.statusCode == 200) {
        final datosJson = jsonDecode(respuesta.body);
        String token = datosJson['access_token'];
        String refreshToken = datosJson['refresh_token'];
        int expiresIn = datosJson['expires_in'] ?? 3600;

        // Requiere Spotify Premium para controlar la reproducción de la rockola
        final respuestaPerfil = await http.get(
          Uri.parse('https://api.spotify.com/v1/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        String spotifyId = 'desconocido';

        if (respuestaPerfil.statusCode == 200) {
          final perfilData = jsonDecode(respuestaPerfil.body);
          spotifyId = perfilData['id'];
          String tipoSuscripcion = perfilData['product'] ?? 'free';

          if (tipoSuscripcion != 'premium') {
            return {
              "error": true,
              "mensaje":
                  "Necesitas Spotify Premium para ser el anfitrión de una sala.",
            };
          }
        } else {
          return {
            "error": true,
            "mensaje":
                "No se pudo verificar tu cuenta de Spotify. Intenta de nuevo.",
          };
        }

        // Eliminar salas huérfanas creadas anteriormente por este usuario
        if (spotifyId != 'desconocido') {
          final salasAnteriores = await FirebaseFirestore.instance
              .collection('salas')
              .where('spotify_id', isEqualTo: spotifyId)
              .get();

          for (var doc in salasAnteriores.docs) {
            await doc.reference.delete();
          }
        }

        // Limpieza de salas vencidas en segundo plano
        try {
          final salasBasura = await FirebaseFirestore.instance
              .collection('salas')
              .where('expira_en', isLessThan: Timestamp.now())
              .limit(5)
              .get();

          for (var sala in salasBasura.docs) {
            await sala.reference.delete();
          }
        } catch (_) {}

        DateTime horaDeMuerte = DateTime.now().add(const Duration(hours: 4));
        String codigoSala = (1000 + Random().nextInt(9000)).toString();

        await FirebaseFirestore.instance
            .collection('salas')
            .doc(codigoSala)
            .set({
              'codigo_sala': codigoSala,
              'spotify_access_token': token,
              'spotify_refresh_token': refreshToken,
              'spotify_id': spotifyId,
              'usuarios': [widget.nombreUsuario],
              'creado_en': FieldValue.serverTimestamp(),
              // Expiración de la sala (4 horas)
              'expira_en': Timestamp.fromDate(horaDeMuerte),
              // Expiración del access_token para refrescarlo oportunamente (~1 hora)
              'expira_token_en': Timestamp.fromDate(
                DateTime.now().add(Duration(seconds: expiresIn)),
              ),
            });

        return {"token": token, "codigoSala": codigoSala};
      } else {
        return null;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error_autenticacion = "Error de conexión: $e";
        });
      }
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
          // Intercepta la URL de callback de OAuth para obtener el authorization code
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://macrobyte.site')) {
              Uri uri = Uri.parse(request.url);
              String? codigoAutorizacion = uri.queryParameters['code'];

              if (codigoAutorizacion != null) {
                setState(() {
                  cargando = true;
                });
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
          'https://accounts.spotify.com/authorize?client_id=cf4410e8df834a21998c3fe4d6518987&response_type=code&redirect_uri=https://macrobyte.site&scope=user-modify-playback-state%20user-read-currently-playing%20user-read-playback-state%20user-read-private%20user-read-email&show_dialog=true',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A1A),
      body: Container(
        decoration: Variables.fondobody,
        child: cargando
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Disenos.colorVerdeNeon,
                    ),
                    const SizedBox(height: 20),
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
