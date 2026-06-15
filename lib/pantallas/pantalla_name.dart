import 'package:flutter/material.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Oauth.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:google_fonts/google_fonts.dart';

class PantallaName extends StatefulWidget {
  const PantallaName({super.key});

  @override
  State<PantallaName> createState() => _PantallaNameState();
}

class _PantallaNameState extends State<PantallaName> {
  // El TextEditingController nos permite capturar y leer lo que el usuario escribe en el TextField
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    // Buenas prácticas: Siempre limpia los controladores cuando el widget se destruye para liberar memoria
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Variables.fondoInferior, // Usamos tu color oscuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Variables.textos_primarios),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¡Crea tu Sala!',
              style: GoogleFonts.comfortaa(
                color: Variables.textos_primarios,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ingresa tu nombre de usuario para que los demás te reconozcan en la rockola.',
              textAlign: TextAlign.center,
              style: GoogleFonts.comfortaa(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 30),
            
            // Campo de texto para el nombre
            TextField(
              controller: _nameController,
              style: GoogleFonts.comfortaa(color: Variables.textos_primarios),
              decoration: InputDecoration(
                hintText: "Tu apodo o nombre",
                hintStyle: TextStyle(color: Variables.textos_primarios.withOpacity(0.4)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Variables.textos_primarios.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Variables.textos_primarios, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Botón para continuar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // .trim() elimina los espacios vacíos al principio y al final
                  if (_nameController.text.trim().isNotEmpty) {
                    // Si escribió algo, avanzamos a PantallaOauth pasando el nombre como parámetro
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaOauth(
                          nombreUsuario: _nameController.text.trim(),
                        ),
                      ),
                    );
                  } else {
                    // Si dejó el campo vacío, le mostramos una alerta rápida (SnackBar)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, ingresa un nombre válido')),
                    );
                  }
                },
                style: Variables.estiloBotones,
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}