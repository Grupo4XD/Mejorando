import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Disenos {
  // --- COLORES BASE ---
  static const Color colorVerdeNeon = Color(
    0xFF1DB954,
  );
  static const Color colorFondoSuperior = Color(0xFF0F172A); // Azul oscuro
  static const Color colorFondoInferior = Color(0xFF000000); // Negro profundo

  // --- FONDO DE PANTALLA ---
  static const BoxDecoration fondobody = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colorFondoSuperior, colorFondoInferior],
      stops: [0.0, 0.8], // Controla el desvanecimiento
    ),
  );

  // --- ESTILOS DE BOTONES ---

  // 1. Botón Principal (Sólido - Crear Sala)
  static final ButtonStyle estiloBotonPrimario = ElevatedButton.styleFrom(
    backgroundColor: colorVerdeNeon,
    foregroundColor: Colors.black, // Color del texto e icono
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    textStyle: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold),
  );

  // 2. Botón Secundario (Bordeado - Unirse a Sala)
  static final ButtonStyle estiloBotonSecundario = OutlinedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: colorVerdeNeon, // Color del texto e icono
    side: const BorderSide(color: colorVerdeNeon, width: 2), // Borde verde
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    textStyle: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold),
  );

  // --- ESTILOS DE TEXTO ---
  static final TextStyle estiloTitulo = GoogleFonts.montserrat(
    //Define el ancho o el grosor del texto
    fontSize: 42,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -1, // Junta un poco las letras para estilo logo
  );

  static final TextStyle estiloSubtitulo = GoogleFonts.poppins(
    fontSize: 16,
    color: Colors.white70,
  );

  static final TextStyle estiloNotaFinal = GoogleFonts.poppins(
    fontSize: 13,
    color: Colors.white54,
  );

  // --- ESTILOS DE TEXTFIELD ---
  static final InputDecoration estiloCampoTexto = InputDecoration(
    //El filled indica que el fondo del campo de texto tendra un color de relleno o sera tranasparente (por defecto es false)
    filled: true,
    fillColor: Colors.white.withOpacity(0.05), // Efecto cristal oscuro
    //Padding
    contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
    hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 15),

    // Borde normal (Sin seleccionar)
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(
        30,
      ), // Bordes redondeados como los botones
      borderSide: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
    ),

    // Borde iluminado (Cuando el usuario está escribiendo)
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(
        color: colorVerdeNeon, // Tu verde característico
        width: 2.5, // Un poco más grueso para que resalte
      ),
    ),

    // Borde por si hay un error de validación en el futuro
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2.5),
    ),
  );

  // Estilo del texto que el usuario escribe
  static final TextStyle estiloTextoInput = GoogleFonts.poppins(
    color: Colors.white,
    fontSize: 16,
  );
}
