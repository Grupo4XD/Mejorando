import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Sala.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:google_fonts/google_fonts.dart';

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
      // 1. Buscamos en Firestore si existe un documento con ese código de sala
      DocumentReference salaRef = FirebaseFirestore.instance
          .collection('salas')
          .doc(codigo);
      DocumentSnapshot doc = await salaRef.get();

      if (doc.exists) {
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
      backgroundColor: Variables.fondoInferior,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Variables.textos_primarios),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Center(
          child: SingleChildScrollView(
            // Evita errores de pantalla si se abre el teclado
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                Text(
                  'Unirse a una Sala',
                  style: GoogleFonts.comfortaa(
                    color: Variables.textos_primarios,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
          
                // TextField para el nombre
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.comfortaa(color: Variables.textos_primarios),
                  decoration: InputDecoration(
                    hintText: "Tu nombre de usuario",
                    hintStyle: TextStyle(
                      color: Variables.textos_primarios.withOpacity(0.4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(
                        color: Variables.textos_primarios.withOpacity(0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(
                        color: Variables.textos_primarios,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
          
                // TextField para el código de sala
                TextField(
                  controller: _codigoController,
                  keyboardType:
                      TextInputType.number, // Muestra el teclado numérico
                  style: GoogleFonts.comfortaa(color: Variables.textos_primarios),
                  decoration: InputDecoration(
                    hintText: "Código de la sala (4 dígitos)",
                    hintStyle: TextStyle(
                      color: Variables.textos_primarios.withOpacity(0.4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(
                        color: Variables.textos_primarios.withOpacity(0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(
                        color: Variables.textos_primarios,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
          
                // Botón Unirme
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _unirseALaSala,
                    style: Variables.estiloBotones,
                    child: _cargando
                        ? const CircularProgressIndicator(
                            color: Variables.textos_primarios,
                          )
                        : const Text('Unirme a Sala'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
