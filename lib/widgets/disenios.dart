import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Disenos {
  static const Color colorVerdeNeon = Color(0xFF1DB954);
  static const Color colorFondoSuperior = Color(0xFF0F172A);
  static const Color colorFondoInferior = Color(0xFF000000);

  static const BoxDecoration fondobody = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colorFondoSuperior, colorFondoInferior],
      stops: [0.0, 0.8],
    ),
  );

  static final ButtonStyle estiloBotonPrimario = ElevatedButton.styleFrom(
    backgroundColor: colorVerdeNeon,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    textStyle: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold),
  );

  static final ButtonStyle estiloBotonSecundario = OutlinedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: colorVerdeNeon,
    side: const BorderSide(color: colorVerdeNeon, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    textStyle: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold),
  );

  static final TextStyle estiloTitulo = GoogleFonts.montserrat(
    fontSize: 42,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -1,
  );

  static final TextStyle estiloSubtitulo = GoogleFonts.poppins(
    fontSize: 16,
    color: Colors.white70,
  );

  static final TextStyle estiloNotaFinal = GoogleFonts.poppins(
    fontSize: 13,
    color: Colors.white54,
  );

  static final InputDecoration estiloCampoTexto = InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
    hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(
        color: colorVerdeNeon,
        width: 2.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2.5),
    ),
  );

  static final TextStyle estiloTextoInput = GoogleFonts.poppins(
    color: Colors.white,
    fontSize: 16,
  );
}
