import 'package:flutter/material.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:go_router/go_router.dart';

class PantallaName extends StatefulWidget {
  const PantallaName({super.key});

  @override
  State<PantallaName> createState() => _PantallaNameState();
}

class _PantallaNameState extends State<PantallaName> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              ),
              Text('¡Crea tu Sala!', style: Disenos.estiloTitulo),
              const SizedBox(height: 10),
              Text(
                'Ingresa tu nombre de usuario para que los demás te reconozcan en la rockola.',
                textAlign: TextAlign.center,
                style: Disenos.estiloSubtitulo,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                style: Disenos.estiloTextoInput,
                cursorColor: Disenos.colorVerdeNeon,
                decoration: Disenos.estiloCampoTexto.copyWith(
                  hintText: 'Tu nombre de usuario',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Disenos.colorVerdeNeon,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final String nombre = _nameController.text.trim();
                    if (nombre.isNotEmpty) {
                      context.push('/oauth', extra: nombre);
                    } else {
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
