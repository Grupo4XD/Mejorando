import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Sala.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';

class PantallaInvitado extends StatefulWidget {
  const PantallaInvitado({super.key});

  @override
  State<PantallaInvitado> createState() => _PantallaInvitadoState();
}

class _PantallaInvitadoState extends State<PantallaInvitado> {
  // Dos controladores: uno para el apodo y otro para el código de 4 dígitos
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  bool _cargando = false;

  @override
  //Cuando se destruye la pantalla esto se ejecuta y evita la fuga de memoria
  void dispose() {
    _nameController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _unirseALaSala() async {
    final String nombre = _nameController.text.trim();
    final String codigo = _codigoController.text.trim();

    // Validamos que los campos no estén vacíos
    if (nombre.isEmpty || codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() {
      _cargando = true;
    });
  
    try {
      // Buscamos en Firestore si existe un documento con ese código de sala
      DocumentReference salaRef = FirebaseFirestore.instance
          .collection('salas')
          .doc(codigo);
      DocumentSnapshot doc = await salaRef.get();
      

      if (doc.exists) {
        // Extraemos la lista actual de usuarios de la base de datos
        List<dynamic> usuariosActuales = doc['usuarios'] ?? [];
        // El nombre que escribió el invitado

        //VERIFICAMOS SI EL NOMBRE ESTA EN LA SALA
        if (usuariosActuales.contains(nombre)) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este nombre ya está en uso en esta sala. Por favor, elige otro.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return; // Detenemos la función, no lo dejamos entrar
        }

        // 2. Si la sala existe, agregamos el nombre del invitado a la lista 'usuarios'
        // 'arrayUnion' añade el elemento solo si no se repite, manteniendo la lista limpia
        await salaRef.update({
          'usuarios': FieldValue.arrayUnion([nombre]),
        });

        if (!mounted) return;

        // 3. Redirigimos a la PantallaSala pasándole el código
        // NOTA: Dejamos el token como opcional porque la sala lo cargará desde Firestore
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PantallaSala(
              codigoSala: codigo,
              token:
                  '', // Le pasamos un texto vacío; la pantalla se encargará de buscar el real
              nombreUsuarioActual: nombre,
            ),
          ),
        );
      } else {
        // Si el código no existe en Firestore, avisamos al usuario
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La sala no existe. Verifica el código.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al unirse: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Disenos.colorVerdeNeon),
      ),
      body: 
      Container(
        
        decoration: Variables.fondobody,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Center(
            child: SingleChildScrollView(
              // Evita errores de pantalla si se abre el teclado
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/imagenes/logo.png",
                    width: MediaQuery.of(context).size.width * 0.35,
                    //height: MediaQuery.of(context).size.width * 0.8,
                  ),
                  Text(
                    'Unirse a una Sala',
                    style: Disenos.estiloTitulo,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
        
                  // TextField para el nombre
                  TextField(
                    controller: _nameController,
                    style: Disenos.estiloTextoInput,
                    decoration: Disenos.estiloCampoTexto.copyWith(
                      hintText: "Nombre de usuario",
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Disenos.colorVerdeNeon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
        
                  // TextField para el código de sala
                  TextField(
                    controller: _codigoController,
                    keyboardType:
                        TextInputType.number, // Muestra el teclado numérico
                    style: Disenos.estiloTextoInput,
                    decoration: Disenos.estiloCampoTexto.copyWith(
                      hintText: "Codigo de sala",
                      prefixIcon: const Icon(
                        Icons.code,
                        color: Disenos.colorVerdeNeon,
                      )
                    )
                  ),
                  const SizedBox(height: 40),
        
                  // Botón Unirme
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _unirseALaSala,
                      style: Disenos.estiloBotonPrimario,
                      child: _cargando
                          ? const CircularProgressIndicator(
                              color: Disenos.colorVerdeNeon,
                            )
                          : const Text('Unirme a Sala'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
