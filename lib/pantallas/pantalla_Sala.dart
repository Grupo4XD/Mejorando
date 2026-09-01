import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:proyecto_rockify/pantallas/peticionesApi.dart';
import 'package:proyecto_rockify/pantallas/spotify_auth.dart';
import 'package:go_router/go_router.dart';

class PantallaSala extends StatefulWidget {
  final String codigoSala;
  final String token;
  final String nombreUsuarioActual;
  const PantallaSala({
    super.key,
    required this.token,
    required this.codigoSala,
    required this.nombreUsuarioActual,
  });

  @override
  State<PantallaSala> createState() => _PantallaSalaState();
}

class _PantallaSalaState extends State<PantallaSala>
    with WidgetsBindingObserver {
  List<String> _dislikesAnteriores = [];
  bool _saltandoCancion = false;
  bool _mostrarAlertaDislike = false;
  String _mensajeAlerta = "";

  bool mostrarequis = false;

  String _tokenActual = '';
  DateTime? _expiraToken;

  List<String> _usuariosDislike = [];
  String _idCancionActual = '';

  final TextEditingController _buscadorController = TextEditingController();
  Timer? _debounceBusqueda;
  bool _buscandoApi = false;
  List<Map<String, dynamic>> _resultadosBusqueda = [];

  bool dislikePresionado = false;
  int dislikesCancionActual = 0;
  double progresoCancion = 0.0;

  String imagen = "https://picsum.photos/250";
  String titulo = "Ninguna canción sonando";
  String artista = "Abre Spotify en tu navegador";

  int usuariosEnLinea = 1;
  StreamSubscription<DocumentSnapshot>? _streamUsuarios;

  List<String> _nombresUsuarios = [];
  int _dislikesRequeridos = 1;
  List<Map<String, dynamic>> listaColaEspera = [];

  Timer? _timer;

  // Solo el anfitrión ejecuta la orden en Spotify API y resetea los dislikes en Firestore para evitar llamadas duplicadas
  Future<void> _ejecutarSaltoSincronizado() async {
    if (_saltandoCancion) return;
    _saltandoCancion = true;

    await Future.delayed(const Duration(seconds: 1));

    bool esCreador =
        _nombresUsuarios.isNotEmpty &&
        widget.nombreUsuarioActual == _nombresUsuarios[0];

    if (esCreador) {
      DateTime nuevaHoraDeMuerte = DateTime.now().add(const Duration(hours: 4));

      await FirebaseFirestore.instance
          .collection('salas')
          .doc(widget.codigoSala)
          .update({
            'usuarios_dislike': [],
            'expira_en': Timestamp.fromDate(nuevaHoraDeMuerte),
          });

      bool exito = await Peticionesapi.saltarSiguienteCancion(_tokenActual);
      if (exito) {
        _actualizarReproductor();
      }
    }

    _saltandoCancion = false;
  }

  void _alEscribirTexto(String texto) {
    if (_debounceBusqueda?.isActive ?? false) _debounceBusqueda!.cancel();

    setState(() {
      mostrarequis = true;
    });

    if (texto.isEmpty) {
      setState(() {
        _resultadosBusqueda = [];
        _buscandoApi = false;
        mostrarequis = false;
      });
      return;
    }

    setState(() => _buscandoApi = true);

    _debounceBusqueda = Timer(const Duration(milliseconds: 500), () async {
      final resultados = await Peticionesapi.buscarCanciones(
        texto,
        _tokenActual,
      );
      if (mounted) {
        setState(() {
          _resultadosBusqueda = resultados;
          _buscandoApi = false;
        });
      }
    });
  }

  void _agregarCancion(String idCancion) async {
    bool exito = await Peticionesapi.anadirACola(idCancion, _tokenActual);

    if (exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text("¡'$titulo' guardada en la lista de la sala!"),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _buscadorController.clear();
      });

      _actualizarReproductor();
    }
  }

  // Solo el anfitrión renueva el token y actualiza Firestore; los invitados lo reciben automáticamente por stream
  Future<void> _asegurarTokenValido() async {
    bool esCreador =
        _nombresUsuarios.isNotEmpty &&
        widget.nombreUsuarioActual == _nombresUsuarios[0];
    if (!esCreador) return;

    final ahora = DateTime.now();
    final bool porExpirar =
        _expiraToken == null ||
        ahora.isAfter(_expiraToken!.subtract(const Duration(minutes: 1)));
    if (!porExpirar) return;

    final nuevoToken = await SpotifyAuth.obtenerTokenValidoDeSala(
      widget.codigoSala,
    );
    if (nuevoToken != null && mounted) {
      setState(() {
        _tokenActual = nuevoToken;
      });
    }
  }

  Future<void> _actualizarReproductor() async {
    if (_tokenActual.isEmpty) return;

    await _asegurarTokenValido();

    final Map<String, dynamic>? datosCancion =
        await Peticionesapi.ObtenerCancionActual(_tokenActual);

    final Map<String, dynamic>? datosCola =
        await Peticionesapi.obtenerColaReproduccion(_tokenActual);

    if (!mounted) return;

    setState(() {
      if (datosCancion != null && datosCancion['item'] != null) {
        final nuevoId = datosCancion['item']['id'] ?? '';

        // Si cambió la canción en reproducción, se resetean los votos de dislike
        if (_idCancionActual.isNotEmpty && _idCancionActual != nuevoId) {
          _usuariosDislike.clear();

          bool esCreador =
              _nombresUsuarios.isNotEmpty &&
              widget.nombreUsuarioActual == _nombresUsuarios[0];
          if (esCreador) {
            FirebaseFirestore.instance
                .collection('salas')
                .doc(widget.codigoSala)
                .update({'usuarios_dislike': []});
          }
        }

        _idCancionActual = nuevoId;
        titulo = datosCancion['item']['name'] ?? 'Sin título';

        final artistas = datosCancion['item']['artists'] as List<dynamic>?;
        artista = artistas != null
            ? artistas.map((a) => a['name']).join(', ')
            : 'Desconocido';

        final imagenes =
            datosCancion['item']['album']?['images'] as List<dynamic>?;
        imagen = (imagenes != null && imagenes.isNotEmpty)
            ? imagenes[0]['url']
            : 'https://picsum.photos/250';

        int progresoMs = datosCancion['progress_ms'] ?? 0;
        int duracionMs = datosCancion['item']['duration_ms'] ?? 1;
        progresoCancion = progresoMs / duracionMs;
      } else {
        titulo = "Ninguna canción sonando";
        artista = "Abre Spotify en tu navegador";
        imagen = "https://picsum.photos/250";
        progresoCancion = 0.0;
      }

      if (datosCola != null) {
        final queue = datosCola['queue'] as List<dynamic>? ?? [];
        final currentlyPlaying = datosCola['currently_playing'];

        List<dynamic> listaCompleta = [];
        if (currentlyPlaying != null) {
          listaCompleta.add(currentlyPlaying);
        }
        listaCompleta.addAll(queue);

        if (listaCompleta.isNotEmpty) {
          listaColaEspera = listaCompleta.map((item) {
            final artistas = item['artists'] as List<dynamic>?;
            final imagenes = item['album']?['images'] as List<dynamic>?;
            return {
              'titulo': item['name'] ?? 'Sin título',
              'artista': artistas != null
                  ? artistas.map((a) => a['name']).join(', ')
                  : 'Desconocido',
              'imagen': (imagenes != null && imagenes.isNotEmpty)
                  ? imagenes[0]['url']
                  : '',
            };
          }).toList();
        } else {
          listaColaEspera = [];
        }
      } else {
        listaColaEspera = [];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tokenActual = widget.token;

    _actualizarReproductor();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _actualizarReproductor();
    });

    // Escucha en tiempo real cambios de usuarios, dislikes y token en la sala
    _streamUsuarios = FirebaseFirestore.instance
        .collection('salas')
        .doc(widget.codigoSala)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final datos = snapshot.data();
            if (datos != null) {
              final List<dynamic> listaUsuarios = datos['usuarios'] ?? [];

              setState(() {
                _nombresUsuarios = List<String>.from(listaUsuarios);
                usuariosEnLinea = listaUsuarios.length;
                _dislikesRequeridos = datos['dislikes_requeridos'] ?? 1;

                final List<dynamic> dislikesData =
                    datos['usuarios_dislike'] ?? [];
                List<String> dislikesNuevos = List<String>.from(dislikesData);

                // Detecta si otro usuario dio dislike para mostrar la alerta emergente
                for (String votante in dislikesNuevos) {
                  if (!_dislikesAnteriores.contains(votante) &&
                      votante != widget.nombreUsuarioActual) {
                    _lanzarAlertaFlotante(votante);
                  }
                }

                _dislikesAnteriores = List.from(dislikesNuevos);
                _usuariosDislike = dislikesNuevos;

                // Salto automático si se alcanza el umbral de dislikes
                if (_usuariosDislike.length >= _dislikesRequeridos &&
                    _dislikesRequeridos > 0) {
                  _ejecutarSaltoSincronizado();
                }

                _tokenActual = datos['spotify_access_token'] ?? '';
                final Timestamp? expiraTokenTs = datos['expira_token_en'];
                _expiraToken = expiraTokenTs?.toDate();
              });
            }
          }
        });
  }

  Future<void> _cerrarSala() async {
    _timer?.cancel();
    _streamUsuarios?.cancel();

    bool esCreador =
        _nombresUsuarios.isNotEmpty &&
        widget.nombreUsuarioActual == _nombresUsuarios[0];

    try {
      if (esCreador) {
        // Si el creador sale, se destruye la sala en Firestore
        await FirebaseFirestore.instance
            .collection("salas")
            .doc(widget.codigoSala)
            .update({
              'usuarios': FieldValue.arrayRemove([widget.nombreUsuarioActual]),
              'usuarios_dislike': FieldValue.arrayRemove([
                widget.nombreUsuarioActual,
              ]),
            });

        await FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .delete();
      } else {
        // Si sale un invitado, solo se retira su usuario de Firestore
        await FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .update({
              'usuarios': FieldValue.arrayRemove([widget.nombreUsuarioActual]),
              'usuarios_dislike': FieldValue.arrayRemove([
                widget.nombreUsuarioActual,
              ]),
            });
      }
    } catch (e) {
      print("Error al cerrar sala/salir: $e");
    }

    if (!mounted) return;
    context.go('/');
  }

  // Gestiona la presencia en tiempo real del invitado al minimizar o retomar la app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool esCreador =
        _nombresUsuarios.isNotEmpty &&
        widget.nombreUsuarioActual == _nombresUsuarios[0];

    if (!esCreador) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .update({
              'usuarios': FieldValue.arrayRemove([widget.nombreUsuarioActual]),
            });
      } else if (state == AppLifecycleState.resumed) {
        FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .update({
              'usuarios': FieldValue.arrayUnion([widget.nombreUsuarioActual]),
            });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _streamUsuarios?.cancel();
    super.dispose();
  }

  // ignore: non_constant_identifier_names
  void ConfirmarCerrarSala() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Disenos.colorVerdeNeon, width: 2),
            ),
            backgroundColor: Colors.black,
            title: const Text(
              "¿Salir de la sala?",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(color: Disenos.colorVerdeNeon),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _cerrarSala();
                    },
                    child: const Text(
                      "Salir",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarUsuariosEnLinea() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool esCreador =
                _nombresUsuarios.isNotEmpty &&
                widget.nombreUsuarioActual == _nombresUsuarios[0];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Disenos.colorVerdeNeon, width: 2),
              ),
              backgroundColor: Disenos.colorFondoInferior,
              title: Text(
                "Usuarios en la Sala",
                style: GoogleFonts.comfortaa(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _nombresUsuarios.length,
                          itemBuilder: (context, index) {
                            bool esElCreador = index == 0;
                            String nombreDelUsuarioEnLaLista =
                                _nombresUsuarios[index];

                            return GestureDetector(
                              onLongPress: () {
                                bool eresCreador =
                                    _nombresUsuarios.isNotEmpty &&
                                    widget.nombreUsuarioActual ==
                                        _nombresUsuarios[0];

                                if (eresCreador &&
                                    nombreDelUsuarioEnLaLista !=
                                        widget.nombreUsuarioActual) {
                                  showDialog(
                                    context: context,
                                    builder: (contextDialogo) => AlertDialog(
                                      backgroundColor: const Color(0xFF141E30),
                                      title: const Text(
                                        "Expulsar invitado",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: Text(
                                        "¿Quieres eliminar a $nombreDelUsuarioEnLaLista de la sala?",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(contextDialogo),
                                          child: const Text(
                                            "Cancelar",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('salas')
                                                .doc(widget.codigoSala)
                                                .update({
                                                  'usuarios':
                                                      FieldValue.arrayRemove([
                                                        nombreDelUsuarioEnLaLista,
                                                      ]),
                                                  'usuarios_dislike':
                                                      FieldValue.arrayRemove([
                                                        nombreDelUsuarioEnLaLista,
                                                      ]),
                                                });

                                            if (contextDialogo.mounted) {
                                              Navigator.pop(contextDialogo);
                                            }
                                          },
                                          child: const Text(
                                            "Expulsar",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              child: ListTile(
                                leading: Icon(
                                  esElCreador ? Icons.star : Icons.person,
                                  color: esElCreador
                                      ? Colors.amber
                                      : Colors.white70,
                                ),
                                title: Text(
                                  nombreDelUsuarioEnLaLista,
                                  style: GoogleFonts.comfortaa(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                trailing:
                                    nombreDelUsuarioEnLaLista ==
                                        widget.nombreUsuarioActual
                                    ? Text(
                                        "(Tú)",
                                        style: GoogleFonts.comfortaa(
                                          color: Disenos.colorVerdeNeon,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      if (esCreador) ...[
                        const Divider(
                          color: Colors.white24,
                          height: 30,
                          thickness: 1,
                        ),
                        Text(
                          "Configuración del Creador",
                          style: GoogleFonts.comfortaa(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Dislikes para pasar:",
                                style: TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Disenos.colorVerdeNeon,
                                  ),
                                  onPressed: () {
                                    if (_dislikesRequeridos > 1) {
                                      setStateDialog(() {
                                        _dislikesRequeridos--;
                                      });
                                      FirebaseFirestore.instance
                                          .collection('salas')
                                          .doc(widget.codigoSala)
                                          .update({
                                            'dislikes_requeridos':
                                                _dislikesRequeridos,
                                          });
                                    }
                                  },
                                ),
                                Text(
                                  "$_dislikesRequeridos",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Disenos.colorVerdeNeon,
                                  ),
                                  onPressed: () {
                                    setStateDialog(() {
                                      _dislikesRequeridos++;
                                    });
                                    FirebaseFirestore.instance
                                        .collection('salas')
                                        .doc(widget.codigoSala)
                                        .update({
                                          'dislikes_requeridos':
                                              _dislikesRequeridos,
                                        });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _darDislike() async {
    if (_usuariosDislike.contains(widget.nombreUsuarioActual)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blueGrey,
          content: Text("Ya diste dislike a esta cancion"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _usuariosDislike.add(widget.nombreUsuarioActual);
    });

    _lanzarAlertaFlotante(widget.nombreUsuarioActual);

    await FirebaseFirestore.instance
        .collection('salas')
        .doc(widget.codigoSala)
        .update({
          'usuarios_dislike': FieldValue.arrayUnion([
            widget.nombreUsuarioActual,
          ]),
        });
  }

  void _lanzarAlertaFlotante(String nombre) async {
    setState(() {
      _mensajeAlerta = "$nombre le dio dislike 👎";
      _mostrarAlertaDislike = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _mostrarAlertaDislike = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenH = screenSize.height;
    final screenW = screenSize.width;

    final bool pantallaCompacta = screenH < 720;
    final bool pantallaMuyCompacta = screenH < 640;

    final int flexReproductor = pantallaMuyCompacta
        ? 2
        : (pantallaCompacta ? 3 : 3);
    final int flexCola = pantallaMuyCompacta ? 3 : (pantallaCompacta ? 3 : 2);

    final double factorPortada = pantallaMuyCompacta
        ? 0.50
        : (pantallaCompacta ? 0.58 : 0.55);
    final double maxAlturaPortada = pantallaMuyCompacta
        ? screenH * 0.20
        : (pantallaCompacta ? screenH * 0.24 : screenH * 0.22);

    final double tamMiniaturaCola = pantallaMuyCompacta
        ? 34.0
        : (pantallaCompacta ? 40.0 : 45.0);
    final double tamTitulo = pantallaMuyCompacta
        ? 15.0
        : (pantallaCompacta ? 17.0 : 20.0);
    final double tamArtista = pantallaMuyCompacta
        ? 12.0
        : (pantallaCompacta ? 13.0 : 15.0);

    final double espaciadoReproductor = pantallaCompacta ? 4.0 : 6.0;

    final EdgeInsets paddingPantalla = pantallaCompacta
        ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0)
        : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0);

    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        await _cerrarSala();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: Variables.fondobody,
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: paddingPantalla,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 45,
                        child: TextField(
                          controller: _buscadorController,
                          onChanged: _alEscribirTexto,
                          style: Disenos.estiloTextoInput,
                          decoration: Disenos.estiloCampoTexto.copyWith(
                            hintText: "Busca una cancion",
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Disenos.colorVerdeNeon,
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 15, bottom: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () {},
                                style: Variables.estiloBotones,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    "Sala: ${widget.codigoSala}",
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ),

                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Disenos.colorVerdeNeon.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 7,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                height: 40,
                                child: ElevatedButton.icon(
                                  onPressed: _mostrarUsuariosEnLinea,
                                  style: Variables.estiloBotones,
                                  icon: const Icon(Icons.person),
                                  label: Text(
                                    "$usuariosEnLinea",
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: ConfirmarCerrarSala,
                                style: Variables.estiloBotones.copyWith(
                                  foregroundColor: WidgetStateProperty.all(
                                    Colors.black,
                                  ),
                                  backgroundColor: WidgetStateProperty.all(
                                    Colors.red,
                                  ),
                                  padding: WidgetStateProperty.all(
                                    const EdgeInsets.symmetric(horizontal: 15),
                                  ),
                                  minimumSize: WidgetStateProperty.all(
                                    Size.zero,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Icon(Icons.logout, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        flex: flexReproductor,
                        child: Column(
                          children: [
                            SizedBox(height: pantallaCompacta ? 4 : 10),
                            Flexible(
                              child: Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final anchoObjetivo =
                                        screenW * factorPortada;
                                    final altoDisponible =
                                        constraints.maxHeight;
                                    final ladoBase = altoDisponible > 0
                                        ? anchoObjetivo.clamp(
                                            100.0,
                                            altoDisponible,
                                          )
                                        : anchoObjetivo;
                                    final tamPortada = ladoBase.clamp(
                                      100.0,
                                      maxAlturaPortada,
                                    );

                                    return SizedBox(
                                      width: tamPortada,
                                      height: tamPortada,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          color: Colors.black,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.network(
                                            imagen,
                                            width: tamPortada,
                                            height: tamPortada,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Icon(
                                              Icons.album,
                                              color: Colors.white54,
                                              size: tamPortada * 0.35,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            SizedBox(height: espaciadoReproductor),

                            Text(
                              titulo,
                              style: GoogleFonts.comfortaa(
                                color: Colors.white,
                                fontSize: tamTitulo,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: pantallaCompacta ? 2 : 4),

                            Text(
                              artista,
                              style: GoogleFonts.comfortaa(
                                color: Colors.grey,
                                fontSize: tamArtista,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: pantallaCompacta ? 2 : 4),

                            Text(
                              "Dislikes requeridos para saltar: ${_dislikesRequeridos.toString()}",
                              style: GoogleFonts.comfortaa(
                                color: Disenos.colorVerdeNeon,
                                fontSize: pantallaCompacta ? 11 : 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: pantallaCompacta ? 0 : 3),

                            Slider(
                              value: progresoCancion,
                              onChanged: (value) {},
                              activeColor: Disenos.colorVerdeNeon,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 1),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            "Lista de reproducción",
                            style: GoogleFonts.comfortaa(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 3),

                      Expanded(
                        flex: flexCola,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: listaColaEspera.isEmpty
                              ? Center(
                                  child: Text(
                                    "La cola está vacía, ¡añade canciones!",
                                    style: GoogleFonts.comfortaa(
                                      color: Variables.textos_primarios
                                          .withOpacity(0.4),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: listaColaEspera.length,
                                  itemBuilder: (context, index) {
                                    final cancionCola = listaColaEspera[index];
                                    final bool esLaQueEstaSonando =
                                        (index == 0);

                                    return Container(
                                      margin: EdgeInsets.symmetric(
                                        vertical: pantallaMuyCompacta ? 1 : 2,
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        boxShadow: esLaQueEstaSonando
                                            ? [
                                                BoxShadow(
                                                  color: Disenos.colorVerdeNeon
                                                      .withOpacity(0.4),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 0),
                                                ),
                                              ]
                                            : null,
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(15),
                                        border: esLaQueEstaSonando
                                            ? Border.all(
                                                color: Disenos.colorVerdeNeon
                                                    .withOpacity(0.5),
                                                width: 1,
                                              )
                                            : null,
                                      ),
                                      child: ListTile(
                                        dense: pantallaCompacta,
                                        visualDensity: pantallaCompacta
                                            ? VisualDensity.compact
                                            : VisualDensity.standard,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: pantallaMuyCompacta
                                              ? 0
                                              : (pantallaCompacta ? 2 : 3),
                                        ),
                                        leading: _miniaturaCola(
                                          urlImagen:
                                              cancionCola['imagen'] ?? '',
                                          esLaQueEstaSonando:
                                              esLaQueEstaSonando,
                                          size: tamMiniaturaCola,
                                        ),
                                        title: Text(
                                          cancionCola['titulo'],
                                          style: GoogleFonts.comfortaa(
                                            color: esLaQueEstaSonando
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: esLaQueEstaSonando
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: pantallaCompacta
                                                ? 13
                                                : 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          cancionCola['artista'],
                                          style: GoogleFonts.comfortaa(
                                            color: Colors.grey,
                                            fontSize: pantallaCompacta
                                                ? 11
                                                : 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: esLaQueEstaSonando
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "${_usuariosDislike.length}/$_dislikesRequeridos",
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: pantallaCompacta
                                                          ? 13
                                                          : 16,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: Icon(
                                                      _usuariosDislike.contains(
                                                            widget
                                                                .nombreUsuarioActual,
                                                          )
                                                          ? Icons.thumb_down
                                                          : Icons
                                                                .thumb_down_off_alt,
                                                      color: Colors.red,
                                                      size: pantallaCompacta
                                                          ? 22
                                                          : 26,
                                                    ),
                                                    onPressed: _darDislike,
                                                  ),
                                                ],
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                if (_buscadorController.text.isNotEmpty)
                  Positioned(
                    top: 75,
                    left: 14,
                    right: 14,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      decoration: BoxDecoration(
                        color: Disenos.colorFondoInferior,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: _buscandoApi
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Disenos.colorVerdeNeon,
                              ),
                            )
                          : _resultadosBusqueda.isNotEmpty
                          ? ListView.builder(
                              itemCount: _resultadosBusqueda.length,
                              itemBuilder: (context, index) {
                                final cancion = _resultadosBusqueda[index];
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  color: Colors.transparent,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        cancion['urlImagen'],
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    title: Text(
                                      cancion['titulo'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.comfortaa(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      cancion['artista'],
                                      style: GoogleFonts.comfortaa(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Disenos.colorVerdeNeon,
                                        foregroundColor:
                                            Disenos.colorFondoInferior,
                                      ),
                                      onPressed: () =>
                                          _agregarCancion(cancion['id']),
                                      child: const Text("Añadir"),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                "No se encontraron canciones",
                                style: GoogleFonts.comfortaa(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ),

                IgnorePointer(
                  ignoring: !_mostrarAlertaDislike,
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedOpacity(
                      opacity: _mostrarAlertaDislike ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141E30).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          _mensajeAlerta,
                          style: GoogleFonts.comfortaa(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconoMusica(bool destacado, {double size = 45}) {
    return Container(
      width: size,
      height: size,
      color: destacado
          ? const Color(0xFF00FFCC).withOpacity(0.1)
          : Colors.white.withOpacity(0.05),
      child: Icon(
        Icons.music_note,
        color: destacado ? const Color(0xFF00FFCC) : Colors.white54,
        size: size * 0.53,
      ),
    );
  }

  Widget _miniaturaCola({
    required String urlImagen,
    required bool esLaQueEstaSonando,
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            urlImagen != ''
                ? Image.network(
                    urlImagen,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _iconoMusica(esLaQueEstaSonando, size: size),
                  )
                : _iconoMusica(esLaQueEstaSonando, size: size),
            if (esLaQueEstaSonando) ...[
              Container(color: Colors.black.withOpacity(0.45)),
              Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Disenos.colorVerdeNeon,
                  size: size * 0.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
