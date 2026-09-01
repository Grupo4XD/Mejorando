import 'package:flutter/material.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:go_router/go_router.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
              ),
              Text('Rockify', style: Disenos.estiloTitulo),
              const SizedBox(height: 5),
              Text('Tu rockola remota', style: Disenos.estiloSubtitulo),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/crear-sala');
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
                    context.push('/unirse');
                  },
                  style: Disenos.estiloBotonSecundario,
                  child: const Text('Unirse a Sala'),
                ),
              ),
              const SizedBox(height: 30),
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
