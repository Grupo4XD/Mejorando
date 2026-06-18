import 'package:flutter/material.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Oauth.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';

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
      //Para que el appbar sea transparente
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Disenos.colorVerdeNeon),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: Variables.fondobody,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/imagenes/logo.png",
                width: MediaQuery.of(context).size.width * 0.35,
                //height: MediaQuery.of(context).size.width * 0.8,
              ),
              Text('¡Crea tu Sala!', style: Disenos.estiloTitulo),
              const SizedBox(height: 10),
              Text(
                'Ingresa tu nombre de usuario para que los demás te reconozcan en la rockola.',
                textAlign: TextAlign.center,
                style: Disenos.estiloSubtitulo,
              ),
        
              const SizedBox(height: 30),
        
              // Campo de texto para el nombre
              TextField(
                controller: _nameController,
                style: Disenos
                    .estiloTextoInput, // El color de lo que escribe el usuario
                cursorColor: Disenos.colorVerdeNeon, // El palito que parpadea
                decoration: Disenos.estiloCampoTexto.copyWith(
                  hintText: 'Tu nombre de usuario',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Disenos.colorVerdeNeon,
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
                        const SnackBar(
                          content: Text('Por favor, ingresa un nombre válido'),
                        ),
                      );
                    }
                  },
                  style: Disenos.estiloBotonPrimario,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
