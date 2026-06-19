import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Inicio.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // Para usar Timer
import 'package:proyecto_rockify/pantallas/peticionesApi.dart';

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

//El WidgetsBindingObserver es el vigilante del SO que escuhca cuando la app esta apunto de destruirse
class _PantallaSalaState extends State<PantallaSala>
    with WidgetsBindingObserver {
  bool _saltandoCancion = false;
  // Variables para la alerta flotante
  bool _mostrarAlertaDislike = false;
  String _mensajeAlerta = "";

  //Para mostrar la quis en el buscador

  bool mostrarequis = false;
  //Para mostrar las alertas de dislike
  //List<dynamic> _dislikesAnteriores = [];

  String _tokenActual = ''; // <-- Almacenará el token de forma interna

  //############## VARIABLE PARA VER EL BUSCADOR ###################

  List<String> _usuariosDislike = []; // <-- Nombres de quienes dieron dislike
  //###### PARA RASTREAR LA CANCION QUE ESTA SONANDO #######
  String _idCancionActual = ''; // <-- Rastreará qué canción está sonando

  // ── VARIABLES DEL BUSCADOR ──────────────────────────────────────────
  final TextEditingController _buscadorController = TextEditingController();
  Timer? _debounceBusqueda;
  bool _buscandoApi = false;
  List<Map<String, dynamic>> _resultadosBusqueda = [];
  //########### VARIABLES DE LA COLA DE REPRODUCCION ###############
  bool dislikePresionado = false;
  int dislikesCancionActual = 0;
  double progresoCancion = 0.0;

  // ── VARIABLES DEL REPRODUCTOR CENTRAL ──────────────────────────────
  String imagen = "https://picsum.photos/250";
  String titulo = "Ninguna canción sonando";
  String artista = "Abre Spotify en tu navegador";

  // ── USUARIOS EN LÍNEA (tiempo real desde Firestore) ─────────────────
  int usuariosEnLinea = 1;
  StreamSubscription<DocumentSnapshot>? _streamUsuarios;

  //############## Mostrar usuarios y dislikes
  List<String> _nombresUsuarios =
      []; // <-- Guardará todos los nombres de la sala
  int _dislikesRequeridos =
      1; // <-- Configuración por defecto para saltar canción
  // ── LISTA DE COLA ───────────────────────────────────────────────────
  // Cada elemento tiene: { 'titulo': ..., 'artista': ..., 'imagen': ... }
  List<Map<String, dynamic>> listaColaEspera = [];

  Timer? _timer;
  //FUNCION PARA EJECUTAR EL SALTO
  Future<void> _ejecutarSaltoSincronizado() async {
    if (_saltandoCancion) return; // Evita que se dispare dos veces
    _saltandoCancion = true;

    // 1. TODOS LOS CELULARES ESPERAN 1 SEGUNDO Y VEN EL VOTO
    await Future.delayed(const Duration(seconds: 1));

    // 2. SOLO EL CREADOR HACE EL TRABAJO DE LIMPIAR Y SALTAR
    // (Para que no manden 10 órdenes a Spotify al mismo tiempo)
    bool esCreador =
        _nombresUsuarios.isNotEmpty &&
        widget.nombreUsuarioActual == _nombresUsuarios[0];

    if (esCreador) {
      await FirebaseFirestore.instance
          .collection('salas')
          .doc(widget.codigoSala)
          .update({
            'usuarios_dislike': [], // Limpiamos la base de datos
          });

      bool exito = await Peticionesapi.saltarSiguienteCancion(_tokenActual);
      if (exito) {
        _actualizarReproductor();
      }
    }

    _saltandoCancion = false;
  }

  // ── MÉTODOS DEL BUSCADOR ────────────────────────────────────────────
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
      // Usa el método de tu peticionesApi.dart
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
    // Llamada a tu API

    bool exito = await Peticionesapi.anadirACola(idCancion, _tokenActual);

    if (exito && mounted) {
      print("✅ ¡La API aceptó la canción! Mostrando alerta...");
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

      // Actualizamos la cola para que aparezca en pantalla de inmediato
      _actualizarReproductor();
    } else {
      // Si entra aquí, Spotify dijo que NO. Revisa tu consola de depuración.
      print("⚠️ Falló la inserción. La alerta flotante no se mostrará.");
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // FUNCIÓN QUE HACE AMBAS PETICIONES Y ACTUALIZA EL ESTADO
  // ────────────────────────────────────────────────────────────────────
  Future<void> _actualizarReproductor() async {
    // Si todavía no se ha descargado el token de Firestore, detenemos la función
    if (_tokenActual.isEmpty) return;
    // 1. Canción actual
    final Map<String, dynamic>? datosCancion =
        await Peticionesapi.ObtenerCancionActual(_tokenActual);

    // 2. Cola de reproducción
    final Map<String, dynamic>? datosCola =
        await Peticionesapi.obtenerColaReproduccion(_tokenActual);

    // Solo actualiza la UI si el widget sigue montado (el usuario no salió)
    if (!mounted) return;

    setState(() {
      // ── Actualizar reproductor central ──────────────────────────────

      // Agregamos la verificación && datosCancion['item'] != null
      if (datosCancion != null && datosCancion['item'] != null) {
        // 1. Extraemos el ID único...
        final nuevoId = datosCancion['item']['id'] ?? '';

        // 2. DETECTOR DE CAMBIO: Si ya teníamos una canción y el ID es diferente, ¡cambió la música!
        if (_idCancionActual.isNotEmpty && _idCancionActual != nuevoId) {
          // Limpiamos los dislikes en pantalla al instante
          setState(() {
            _usuariosDislike.clear();
          });

          // Solo el CREADOR limpia Firebase (para que no lo hagan los 10 invitados a la vez)

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

        // 3. Guardamos el nuevo ID para la próxima comprobación
        _idCancionActual = nuevoId;

        titulo = datosCancion['item']['name'] ?? 'Sin título';

        // Los artistas vienen como lista; los unimos con coma
        final artistas = datosCancion['item']['artists'] as List<dynamic>?;
        artista = artistas != null
            ? artistas.map((a) => a['name']).join(', ')
            : 'Desconocido';

        // La imagen viene dentro de album -> images -> [0] -> url
        final imagenes =
            datosCancion['item']['album']?['images'] as List<dynamic>?;
        imagen = (imagenes != null && imagenes.isNotEmpty)
            ? imagenes[0]['url']
            : 'https://picsum.photos/250';

        // Progreso: progress_ms / duration_ms  (estos vienen en el objeto
        // raíz del currently-playing, pero ObtenerCancionActual devuelve
        // solo el 'item'. Por ahora dejamos progreso en 0; lo ampliaremos
        // cuando ajustes la API para devolver también progress_ms)
        int progresoMs = datosCancion['progress_ms'] ?? 0;
        int duracionMs = datosCancion['item']['duration_ms'] ?? 1;

        progresoCancion = progresoMs / duracionMs;
      } else {
        print("Ha ocurrido un error dentro de obtener cola de reproduccion");
        titulo = "Ninguna canción sonando";
        artista = "Abre Spotify en tu navegador";
        imagen = "https://picsum.photos/250";
        progresoCancion = 0.0;
      }

      // ── Actualizar cola ─────────────────────────────────────────────
      if (datosCola != null) {
        // 1. Extraemos la lista de canciones en espera (si es null, usamos lista vacía)
        final queue = datosCola['queue'] as List<dynamic>? ?? [];

        // 2. Extraemos la canción que está sonando AHORA MISMO de la API de la cola
        final currentlyPlaying = datosCola['currently_playing'];

        // 3. Creamos una lista temporal para unirlas
        List<dynamic> listaCompleta = [];

        // Añadimos la canción actual al PRINCIPIO (índice 0)
        if (currentlyPlaying != null) {
          listaCompleta.add(currentlyPlaying);
        }

        // Añadimos el resto de la cola detrás
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
    // El vigilante debe activarse primero
    WidgetsBinding.instance.addObserver(this);

    // Inicializamos el token con el que viene del creador (si viene vacío, el Stream lo rellenará)
    _tokenActual = widget.token;

    // Primera carga inmediata
    _actualizarReproductor();

    // Temporizador cada 3 segundos usando nuestra variable interna
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _actualizarReproductor();
    });

    // Stream corregido para leer la nueva estructura de lista
    _streamUsuarios = FirebaseFirestore.instance
        .collection('salas')
        .doc(widget.codigoSala)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            // Obtenemos los datos del documento de forma segura
            final datos = snapshot.data();
            if (datos != null) {
              // Extraemos la lista de usuarios
              final List<dynamic> listaUsuarios = datos['usuarios'] ?? [];

              setState(() {
                //Para traer los nombres de los usauriso
                _nombresUsuarios = List<String>.from(listaUsuarios);
                print("LOS NOMBRES DE USUARIO AHORA SON: $_nombresUsuarios");

                // El número de usuarios en línea ahora es el tamaño de la lista
                usuariosEnLinea = listaUsuarios.length;

                // Si el creador ya configuró los dislikes en la base de datos, los leemos aquí
                _dislikesRequeridos = datos['dislikes_requeridos'] ?? 1;

                // Leemos la lista de dislikes. Si no existe, usamos una lista vacía.
                final List<dynamic> dislikes = datos['usuarios_dislike'] ?? [];
                _usuariosDislike = List<String>.from(dislikes);
                // (Dentro de tu Stream, después de que recibes los datos de Firebase y haces el setState)

                // ######### NUEVA LÓGICA DE SALTO SINCRONIZADO #########
                if (_usuariosDislike.length >= _dislikesRequeridos &&
                    _dislikesRequeridos > 0) {
                  _ejecutarSaltoSincronizado();
                }

                print(
                  "La cantidad de dislikes que se encontraron por defecto fueron $_usuariosDislike",
                );

                // Actualizamos el token dinámicamente (vital para los invitados)
                _tokenActual = datos['spotify_access_token'] ?? '';
              });
            }
          }
        });
  }

  // ── CERRAR SALA: borra el doc de Firestore o elimina al invitado ─
  Future<void> _cerrarSala() async {
    _timer?.cancel();
    _streamUsuarios?.cancel();

    // Verificamos de forma segura si el usuario actual es el creador

    bool esCreador =
        _nombresUsuarios.isNotEmpty &&
        widget.nombreUsuarioActual == _nombresUsuarios[0];

    try {
      print("EL CREADOR DICE QUE ES $esCreador");
      if (esCreador) {
        // 1. EL CREADOR DESTRUYE LA SALA
        print("👑 El creador cerró la sala. Borrando documento...");

        await FirebaseFirestore.instance
            .collection("salas")
            .doc(widget.codigoSala)
            .update({
              // Lo quitamos de la lista de conectados
              'usuarios': FieldValue.arrayRemove([widget.nombreUsuarioActual]),
              // Lo quitamos de los dislikes por si había votado
              'usuarios_dislike': FieldValue.arrayRemove([
                widget.nombreUsuarioActual,
              ]),
            });

        //Luego pasamos a borrar la sala pero antes hicimos eso porque el usuario deb ser el que sepa que el creador se fue
        await FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .delete();
      } else {
        // 2. EL INVITADO SE RETIRA DE LA SALA
        print("🚶‍♂️ Un invitado salió. Borrando sus datos de la sala...");
        await FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .update({
              // Lo quitamos de la lista de conectados
              'usuarios': FieldValue.arrayRemove([widget.nombreUsuarioActual]),
              // Lo quitamos de los dislikes por si había votado
              'usuarios_dislike': FieldValue.arrayRemove([
                widget.nombreUsuarioActual,
              ]),
            });
      }
    } catch (e) {
      print("Error al cerrar sala/salir: $e");
    }

    if (!mounted) return;

    // Navega a PantallaInicio limpiando todo el stack de navegación
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PantallaInicio()),
      (route) => false,
    );
  }

  //ESTA FUNCION ES LA QUE MAS IMPORTA,
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app está a punto de ser destruida (detached) o pausada (cerrada de golpe)
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      bool esCreador =
          _nombresUsuarios.isNotEmpty &&
          widget.nombreUsuarioActual == _nombresUsuarios[0];

      // Si es un INVITADO, mandamos un borrado rápido a Firebase en el último milisegundo
      if (!esCreador) {
        print("🚨 El sistema mató la app. Borrando al invitado fantasma...");
        FirebaseFirestore.instance
            .collection('salas')
            .doc(widget.codigoSala)
            .update({
              'usuarios': FieldValue.arrayRemove([widget.nombreUsuarioActual]),
              'usuarios_dislike': FieldValue.arrayRemove([
                widget.nombreUsuarioActual,
              ]),
            });
      } else {
        print("EL CREADOR SE SALIO, BORRANDO LA SALA");
        _cerrarSala();
      }

      // (Si es el creador, podríamos borrar la sala aquí también, pero a veces el creador
      // solo minimiza la app para contestar un WhatsApp, así que es mejor solo limpiar invitados
      // o dejar que el sistema TTL de Firebase borre la sala horas después).
    }
  }

  @override
  void dispose() {
    //Si la aplicacion se destruye entonces apagamos al vigilante
    WidgetsBinding.instance.removeObserver(this);
    // Cancelar el timer cuando el widget se destruye (usuario sale de la sala)
    _timer?.cancel();
    _streamUsuarios?.cancel();

    super.dispose();
  }

  //################# FUNCION VENTANA EMERGENTE ##################
  void _mostrarUsuariosEnLinea() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 1. ENVOLVEMOS TODO EN UN StatefulBuilder
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // <-- setStateDialog es nuestro nuevo actualizador local

            bool esCreador =
                _nombresUsuarios.isNotEmpty &&
                widget.nombreUsuarioActual == _nombresUsuarios[0];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(15),
                side: BorderSide(color: Disenos.colorVerdeNeon, width: 2),
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
                      // --- LISTA DE USUARIOS ---
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _nombresUsuarios.length,
                          itemBuilder: (context, index) {
                            bool esElCreador = index == 0;
                            return ListTile(
                              leading: Icon(
                                esElCreador ? Icons.star : Icons.person,
                                color: esElCreador
                                    ? Colors.amber
                                    : Colors.white70,
                              ),
                              title: Text(
                                _nombresUsuarios[index],
                                style: GoogleFonts.comfortaa(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              trailing:
                                  _nombresUsuarios[index] ==
                                      widget.nombreUsuarioActual
                                  ? Text(
                                      "(Tú)",
                                      style: GoogleFonts.comfortaa(
                                        color: Disenos.colorVerdeNeon,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),

                      // --- CONFIGURACIÓN  DE DISLIKES ---
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
                            //Expanded le dara todo el espacio nesesario a lo widgets para que se acomoden
                            Expanded(
                              child: const Text(
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
                                      // 2. ACTUALIZAMOS LA VENTANA AL INSTANTE
                                      setStateDialog(() {
                                        _dislikesRequeridos--;
                                      });
                                      // 3. MANDAMOS EL DATO A FIREBASE EN SEGUNDO PLANO
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
                                    // 2. ACTUALIZAMOS LA VENTANA AL INSTANTE
                                    setStateDialog(() {
                                      _dislikesRequeridos++;
                                    });
                                    // 3. MANDAMOS EL DATO A FIREBASE EN SEGUNDO PLANO
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

  //############## BOTON PARA DAR DISLIKES #########################
  Future<void> _darDislike() async {
    // Si ya votó, no hacemos nada
    if (_usuariosDislike.contains(widget.nombreUsuarioActual)) return;

    // ACTUALIZACIÓN VISUAL INMEDIATA LOCAL
    setState(() {
      _usuariosDislike.add(widget.nombreUsuarioActual);
    });

    // SOLO SUBIMOS EL VOTO A FIREBASE
    // El Stream se encargará del resto para todos los celulares
    await FirebaseFirestore.instance
        .collection('salas')
        .doc(widget.codigoSala)
        .update({
          'usuarios_dislike': FieldValue.arrayUnion([
            widget.nombreUsuarioActual,
          ]),
        });
  }

  //Funcion para lanzar la ventana flotante
  void _lanzarAlertaFlotante(String nombre) async {
    // 1. Encendemos la alerta con el nombre del usuario
    setState(() {
      _mensajeAlerta = "$nombre le dio dislike 👎";
      _mostrarAlertaDislike = true;
    });

    // 2. Esperamos 2 segundos
    await Future.delayed(const Duration(seconds: 2));

    // 3. Apagamos la alerta (verificando que la pantalla siga viva)
    //Mounted verifica que la pantalla aun esta viva
    if (mounted) {
      setState(() {
        _mostrarAlertaDislike = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //El popscope sirve para que no haga retroceso con las siguiente propiedades
    return PopScope(
      canPop: false, // Bloqueamos el retroceso automático
      // ignore: deprecated_member_use
      onPopInvoked: (bool didPop) async {
        if (didPop) return; // Si ya hizo pop, no hacemos nada
        // ¡Ejecutamos TU función que ya tiene toda la lógica de limpiar Firebase!
        await _cerrarSala();
      },
      child: Scaffold(
        //Hace que el teclado no empuje todo hacia arriab y que vaya por encima
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,

        //###################### BUSCADOR ##################
        //Safe area detecta la muesca de camara del telefono o su barra de notificaciones y le da un area segura para delimitar el espacio
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: Variables.fondobody,
          child: SafeArea(
            child: Stack(
              children: [
                //Identifica si todo el contenido cabe en la pantalla sino activa un scrolling
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 30.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 45,
                        child: TextField(
                          controller:
                              _buscadorController, //  Se conecta al controlador
                          onChanged: _alEscribirTexto, //  Dispara el Timer
                          style: Disenos.estiloTextoInput,
                          decoration: Disenos.estiloCampoTexto.copyWith(
                            hintText: "Busca una cancion",
                            prefixIcon: Icon(
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
                                    "ID: ${widget.codigoSala}",
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
                                    ), // Ajusta la opacidad a tu gusto
                                    blurRadius:
                                        7, // Qué tan suave o difuminado es el brillo (muy alto)
                                    spreadRadius:
                                        2, // Qué tanto se expande hacia afuera
                                    offset: const Offset(
                                      0,
                                      0,
                                    ), // IMPORTANTE: 0,0 para que brille en todas direcciones, no solo hacia abajo
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
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ============================================================
                      // BLOQUE 1: REPRODUCTOR ACTUAL
                      // ============================================================
                      Column(
                        children: [
                          // Portada de la canción
                          SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.black,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 180,
                                height: 180,
                                //color: Colors.grey[900],
                                child: Image.network(
                                  imagen,
                                  fit: BoxFit.cover,
                                  // Si la imagen  falla, muestra un icono
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.album,
                                    color: Colors.white54,
                                    size: 80,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Título
                          Text(
                            titulo,
                            style: GoogleFonts.comfortaa(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          // Artista
                          Text(
                            artista,
                            style: GoogleFonts.comfortaa(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 4),

                          Text(
                            "Dislikes requeridos para saltar: ${_dislikesRequeridos.toString()}",
                            style: GoogleFonts.comfortaa(
                              color: Disenos.colorVerdeNeon,
                            ),
                          ),

                          const SizedBox(height: 3),

                          // Barra de progreso
                          Slider(
                            value: progresoCancion,
                            onChanged: (value) {},
                            activeColor: Disenos.colorVerdeNeon,
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // Separador visual
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

                      SizedBox(height: 5),
                      // ============================================================
                      // BLOQUE 2: COLA DE CANCIONES
                      // ============================================================
                      Expanded(
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
                                  //Le dice al listview builder que ocupe el espacio que ocupen sus elemento osea se usa dentro de un singlechildscrollview sino se expnadira infinitamente
                                  //shrinkWrap: true,
                                  //Desactiva el scroll de la lista
                                  //physics: NeverScrollableScrollPhysics(),
                                  itemCount: listaColaEspera.length,
                                  itemBuilder: (context, index) {
                                    final cancionCola = listaColaEspera[index];
                                    final bool esLaQueEstaSonando =
                                        (index == 0);
                                    //print("La lista de canciones son: $cancionCola");

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 6,
                                      ),

                                      decoration: BoxDecoration(
                                        boxShadow: esLaQueEstaSonando
                                            ? [
                                                BoxShadow(
                                                  color: Disenos.colorVerdeNeon
                                                      .withOpacity(
                                                        0.4,
                                                      ), // Ajusta la opacidad a tu gusto
                                                  blurRadius:
                                                      10, // Qué tan suave o difuminado es el brillo (muy alto)
                                                  spreadRadius:
                                                      1, // Qué tanto se expande hacia afuera
                                                  offset: const Offset(
                                                    0,
                                                    0,
                                                  ), // IMPORTANTE: 0,0 para que brille en todas direcciones, no solo hacia abajo
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
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: cancionCola['imagen'] != ''
                                              ? Image.network(
                                                  cancionCola['imagen'],
                                                  width: 45,
                                                  height: 45,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      _iconoMusica(
                                                        esLaQueEstaSonando,
                                                      ),
                                                )
                                              : _iconoMusica(
                                                  esLaQueEstaSonando,
                                                ),
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
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          cancionCola['artista'],
                                          style: GoogleFonts.comfortaa(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        trailing: esLaQueEstaSonando
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Mostramos visualmente el progreso, ej: "1/3"
                                                  Text(
                                                    "${_usuariosDislike.length}/$_dislikesRequeridos",
                                                    style: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    // Si el usuario ya está en la lista, mostramos el ícono relleno, sino el delineado
                                                    icon: Icon(
                                                      _usuariosDislike.contains(
                                                            widget
                                                                .nombreUsuarioActual,
                                                          )
                                                          ? Icons.thumb_down
                                                          : Icons
                                                                .thumb_down_off_alt,
                                                      color: Colors.red,
                                                      size: 26,
                                                    ),
                                                    onPressed:
                                                        _darDislike, // Conectamos la nueva función
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

                      // ============================================================
                      // BLOQUE 3: BOTÓN CERRAR SALA
                      // ============================================================
                      SizedBox(
                        //Sirve para poner el ancho de un widget al porcentaje total de una pantalla
                        width: MediaQuery.of(context).size.width * 0.5,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[900],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(34),
                            ),
                          ),
                          label: Text(
                            "Cerrar Sala",
                            style: GoogleFonts.comfortaa(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            //await FirebaseFirestore.instance
                            //  .collection('salas')
                            //.doc(widget.codigoSala)
                            //.delete();
                            //// Borra la sala de Firebase al salir
                            // Regresa a la pantalla anterior (login)
                            _cerrarSala();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                //PARA MIS TRACK
                if (_buscadorController.text.isNotEmpty)
                  Positioned(
                    top: 75,
                    left: 14,
                    right: 14,
                    child: Container(
                      //Con esto podemosdarle un alto fijo de acuerdo al procentaje de la pantalla
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      decoration: BoxDecoration(
                        color: Disenos.colorFondoInferior,
                        borderRadius: BorderRadius.circular(22),
                        //border: Border.all(
                        //color: Disenos.colorVerdeNeon,
                        // width: 2
                        //)
                      ),

                      child: _buscandoApi
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Variables.textos_primarios,
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
                                      child: Text("Añadir"),
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

                // ── CAPA 3: ALERTA FLOTANTE DE DISLIKE ───────────────────────
                // IgnorePointer evita que la alerta bloquee los toques en la pantalla
                IgnorePointer(
                  ignoring: !_mostrarAlertaDislike,
                  child: Align(
                    alignment: Alignment.center, // Aparecerá justo en el medio
                    child: AnimatedOpacity(
                      opacity: _mostrarAlertaDislike ? 1.0 : 0.0,
                      duration: const Duration(
                        milliseconds: 400,
                      ), // Transición súper fluida
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

  // Widget auxiliar para el icono de música en la lista
  Widget _iconoMusica(bool destacado) {
    return Container(
      width: 45,
      height: 45,
      color: destacado
          ? const Color(0xFF00FFCC).withOpacity(0.1)
          : Colors.white.withOpacity(0.05),
      child: Icon(
        Icons.music_note,
        color: destacado ? const Color(0xFF00FFCC) : Colors.white54,
        size: 24,
      ),
    );
  }
}
