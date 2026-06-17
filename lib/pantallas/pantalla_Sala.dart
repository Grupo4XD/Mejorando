import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Inicio.dart';
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

class _PantallaSalaState extends State<PantallaSala> {
  //Para mostrar la quis en el buscador
  bool mostrarequis = false;

  String _tokenActual = ''; // <-- Almacenará el token de forma interna

  //############## VARIABLE PARA VER EL BUSCADOR

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

  //############## Mostrar usaurios y dislikes
  List<String> _nombresUsuarios =
      []; // <-- Guardará todos los nombres de la sala
  int _dislikesRequeridos =
      1; // <-- Configuración por defecto para saltar canción
  // ── LISTA DE COLA ───────────────────────────────────────────────────
  // Cada elemento tiene: { 'titulo': ..., 'artista': ..., 'imagen': ... }
  List<Map<String, dynamic>> listaColaEspera = [];

  Timer? _timer;

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
      if (datosCancion != null) {
        // 1. Extraemos el ID único de la canción que viene de Spotify
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

    // Inicializamos el token con el que viene del creador (si viene vacío, el Stream lo rellenará)
    _tokenActual = widget.token;

    // Primera carga inmediata
    _actualizarReproductor();

    // Temporizador cada 3 segundos usando nuestra variable interna
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
                // El número de usuarios en línea ahora es el tamaño de la lista
                usuariosEnLinea = listaUsuarios.length;

                // Si el creador ya configuró los dislikes en la base de datos, los leemos aquí
                _dislikesRequeridos = datos['dislikes_requeridos'] ?? 1;

                // Leemos la lista de dislikes. Si no existe, usamos una lista vacía.
                final List<dynamic> dislikes = datos['usuarios_dislike'] ?? [];
                _usuariosDislike = List<String>.from(dislikes);

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

  @override
  void dispose() {
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
              backgroundColor: Variables.fondoBotones,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Usuarios en la Sala",
                style: GoogleFonts.comfortaa(
                  color: Variables.textos_primarios,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              trailing:
                                  _nombresUsuarios[index] ==
                                      widget.nombreUsuarioActual
                                  ? const Text(
                                      "(Tú)",
                                      style: TextStyle(
                                        color: Variables.textos_primarios,
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
                                    color: Variables.textos_primarios,
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
                                    color: Variables.textos_primarios,
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
    // 1. Verificamos si el usuario ya votó
    if (_usuariosDislike.contains(widget.nombreUsuarioActual)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya diste dislike a esta canción')),
      );
      return;
    }

    DocumentReference salaRef = FirebaseFirestore.instance
        .collection('salas')
        .doc(widget.codigoSala);

    // 2. ACTUALIZACIÓN VISUAL INMEDIATA (Para todos los casos)
    // Agregamos al usuario localmente primero para que el botón se pinte de rojo AL INSTANTE
    setState(() {
      _usuariosDislike.add(widget.nombreUsuarioActual);
    });

    // 3. EVALUACIÓN: ¿Con este voto (que ya está en la lista) alcanzamos el límite?
    // Nota: Como ya lo agregamos arriba, ya no sumamos "+ 1", solo comparamos la longitud real
    if (_usuariosDislike.length >= _dislikesRequeridos) {
      // LA MAGIA DE LA UX: Esperamos medio segundo (500 milisegundos)
      // Esto le da tiempo al usuario de ver el botón rojo y el "2/2" antes de que la canción desaparezca
      await Future.delayed(const Duration(milliseconds: 500));

      print("⏭️ ¡Límite de dislikes alcanzado! Saltando canción...");

      // Reseteamos la base de datos a vacío para la próxima canción
      await salaRef.update({'usuarios_dislike': []});

      // Mandamos la orden a Spotify
      bool exito = await Peticionesapi.saltarSiguienteCancion(_tokenActual);

      if (exito) {
        // Limpiamos la pantalla localmente y traemos la nueva canción
        setState(() {
          _usuariosDislike.clear();
        });
        _actualizarReproductor();
      }
    } else {
      // SI NO ES EL ÚLTIMO VOTO, simplemente guardamos este voto en Firebase
      // (Visualmente ya se actualizó en el paso 2)
      await salaRef.update({
        'usuarios_dislike': FieldValue.arrayUnion([widget.nombreUsuarioActual]),
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
        backgroundColor: Variables.fondoInferior,
      
        //###################### BUSCADOR ##################
        //Safe area detecta la muesca de camara del telefono o su barra de notificaciones y le da un area segura para delimitar el espacio
        body: SafeArea(
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
                        style: GoogleFonts.comfortaa(
                          color: Variables.textos_primarios,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ingresa una canción",
                          hintStyle: TextStyle(
                            color: Variables.textos_primarios.withOpacity(0.5),
                          ),
                          //Para poner el icono a la izquierda
                          prefixIcon: Icon(
                            Icons.search,
                            color: Variables.textos_primarios,
                          ),
                          //Para poner el icono a la derecha
                          suffixIcon: mostrarequis
                              ? IconButton(
                                  icon: Icon(Icons.close),
                                  color: Variables.textos_primarios,
                                  onPressed: () {
                                    _buscadorController.clear();
                                    mostrarequis = false;
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Variables.textos_primarios.withOpacity(0.4),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Variables.textos_primarios,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
      
                    // ── RESULTADOS DE BÚSQUEDA (Condicional) ────────────────────────
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
      
                          SizedBox(
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 180,
                            height: 180,
                            color: Colors.grey[900],
                            child: Image.network(
                              imagen,
                              fit: BoxFit.cover,
                              // Si la imagen falla, muestra un icono
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.album,
                                color: Colors.white54,
                                size: 80,
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
                            color: Variables.textos_primarios,
                          ),
                        ),
      
                        const SizedBox(height: 3),
      
                        // Barra de progreso
                        Slider(
                          value: progresoCancion,
                          onChanged: (value) {},
                          activeColor: Variables.textos_primarios,
                        ),
                      ],
                    ),
      
                    const SizedBox(height: 5),
      
                    // Separador visual
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          "Lista de reproducción",
                          style: GoogleFonts.comfortaa(
                            color: Variables.textos_primarios,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
      
                    // ============================================================
                    // BLOQUE 2: COLA DE CANCIONES
                    // ============================================================
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: listaColaEspera.isEmpty
                            ? Center(
                                child: Text(
                                  "La cola está vacía, ¡añade canciones!",
                                  style: GoogleFonts.comfortaa(
                                    color: Variables.textos_primarios.withOpacity(
                                      0.4,
                                    ),
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
                                  final bool esLaQueEstaSonando = (index == 0);
                                  //print("La lista de canciones son: $cancionCola");
      
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: esLaQueEstaSonando
                                          ? const Color(0xFF0D2A2A)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      border: esLaQueEstaSonando
                                          ? Border.all(
                                              color: const Color(
                                                0xFF00FFCC,
                                              ).withOpacity(0.5),
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    child: ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
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
                                            : _iconoMusica(esLaQueEstaSonando),
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
                                                    fontWeight: FontWeight.bold,
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
      
              //PARA MIS TAACK
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
                      color: Variables.fondoBotones,
                      borderRadius: BorderRadius.circular(22),
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
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                color: Colors.transparent,
                                margin: const EdgeInsets.symmetric(vertical: 0),
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
                                      backgroundColor: Variables.fondoBotones,
      
                                      foregroundColor: Variables.textos_primarios,
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
                              style: GoogleFonts.comfortaa(color: Colors.grey),
                            ),
                          ),
                  ),
                ),
            ],
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
