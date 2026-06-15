import 'package:flutter/material.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Name.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Invitado.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PantallaName(),
                  ), // <-- Cambiado aquí
                );
              },
              style: Variables.estiloBotones,
              child: Text('Crear Sala'),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                // Navegamos a la pantalla de invitados que acabamos de crear
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PantallaInvitado(),
                  ),
                );
              },
              style: Variables.estiloBotones,
              child: Text('Unirse a Sala'),
            ),
          ),
        ],
      ),
    );
  }
}
