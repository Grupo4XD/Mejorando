import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    foregroundColor: Variables.textos_primarios,
    textStyle: Variables.estiloTextoBotones,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    backgroundColor: Variables.fondoBotones,
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
