import 'package:flutter/material.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Inicio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  runApp(const MainApp());
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        // Permite que el contenido del body se extienda detrás del AppBar
        extendBodyBehindAppBar: true,
        appBar: Variables.MiAppbar,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(color: Variables.fondoInferior),
          child: PantallaInicio(),
        ),
      ),
    );
  }
}