import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';

class Variables {
  static const Color textos_primarios = Colors.tealAccent;
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

  static const BoxDecoration fondobody = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.2,
      colors: [
        Color(0xFF141E30),
        Color(0xFF070B14),
      ],
      stops: [0.3, 1.0],
    ),
  );

  static final AppBar MiAppbar = AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_note,
          color: Variables.textos_primarios,
          size: 35,
        ),
        const SizedBox(width: 10),
        Text(
          'Rockify',
          style: GoogleFonts.comfortaa(
            color: Variables.textos_primarios,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
