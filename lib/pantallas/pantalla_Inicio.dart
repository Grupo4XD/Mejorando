import 'package:flutter/material.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
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
    // 1. Agregamos el Scaffold aquí para que la pantalla sea independiente
    return Scaffold(
      //Para que el body se extienda hasta arriba y haga que se vea como transparente
      extendBodyBehindAppBar: true,
      //appBar: Variables.MiAppbar, // Traemos tu AppBar personalizado
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: Variables.fondobody,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/imagenes/logo.png",
                width: MediaQuery.of(context).size.width * 0.35,
                //height: MediaQuery.of(context).size.width * 0.8,
              ),
              //Texto despues de la iamgen
              Text('Rockify', style: Disenos.estiloTitulo),
              const SizedBox(height: 5),
              Text('Tu rockola remota', style: Disenos.estiloSubtitulo),

              SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaName(),
                      ),
                    );
                  },
                  style: Disenos.estiloBotonPrimario,
                  child: const Text('Crear Sala'),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PantallaInvitado(),
                      ),
                    );
                  },
                  style: Disenos.estiloBotonSecundario,
                  child: const Text('Unirse a Sala'),
                ),
              ),
              const SizedBox(height: 30), // Espacio antes del texto final
              
              Text(
                'Necesitas Spotify Premium\npara crear una sala.',
                textAlign: TextAlign.center,
                style: Disenos.estiloNotaFinal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
