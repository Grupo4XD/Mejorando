import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';

class Variables {
  static const Color textos_primarios = Colors.tealAccent;
  //static const Color fondoSuperior = Color(0xFF003333);
  static const Color fondoInferior = Color(0xFF001A1A);
  static const Color fondoBotones = Color(0xFF003333);
  static final estiloTextoBotones = GoogleFonts.comfortaa(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static final estiloBotones = ElevatedButton.styleFrom(
    padding: EdgeInsets.zero,
    elevation: 2,
    textStyle: Variables.estiloTextoBotones,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    backgroundColor: Disenos.colorVerdeNeon,
    foregroundColor: Colors.black,
  );

  //Fondo de mi body
  static const BoxDecoration fondobody = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center, // El punto de origen del gradiente
      radius:
          1.2, // Qué tanto se expande (1.2 cubre toda la pantalla suavemente)
      colors: [
        Color(0xFF141E30), // El azul oscuro/marino del centro
        Color(0xFF070B14), // El negro profundo de los bordes
      ],
      stops: [0.3, 1.0], // Controla dónde empieza a oscurecerse
    ),
  );
  
  //El appBar

  static final AppBar MiAppbar = AppBar(
    backgroundColor: Colors.transparent, // Hace el AppBar transparente
    elevation: 0, // Elimina la sombra del AppBar
    title: Row(
      mainAxisAlignment:
          MainAxisAlignment.center, // Centra el contenido del AppBar
      children: [
        Icon(
          Icons.music_note,
          color: Variables.textos_primarios,
          size: 35,
        ), // Ajusta el tamaño del logo
        const SizedBox(width: 10), // Espacio entre el logo y el texto
        Text(
          'Rockify',
          style: GoogleFonts.comfortaa(
            color: Variables.textos_primarios,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ), // Título del AppBar
      ],
    ),
  );
}
