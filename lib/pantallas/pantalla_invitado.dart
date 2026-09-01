import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_rockify/widgets/disenios.dart';
import 'package:proyecto_rockify/widgets/variables.dart';
import 'package:go_router/go_router.dart';

class PantallaInvitado extends StatefulWidget {
  const PantallaInvitado({super.key});

  @override
  State<PantallaInvitado> createState() => _PantallaInvitadoState();
}

class _PantallaInvitadoState extends State<PantallaInvitado> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  bool _cargando = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _unirseALaSala() async {
    final String nombre = _nameController.text.trim();
    final String codigo = _codigoController.text.trim();

    if (nombre.isEmpty || codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      DocumentReference salaRef = FirebaseFirestore.instance
          .collection('salas')
          .doc(codigo);
      DocumentSnapshot doc = await salaRef.get();

      if (doc.exists) {
        List<dynamic> usuariosActuales = doc['usuarios'] ?? [];

        // Evita nombres duplicados dentro de la misma sala
        if (usuariosActuales.contains(nombre)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este nombre ya está en uso en esta sala. Por favor, elige otro.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        // Agrega el invitado a la lista en Firestore sin duplicar
        await salaRef.update({
          'usuarios': FieldValue.arrayUnion([nombre]),
        });

        if (!mounted) return;

        // El token se pasa vacío porque la sala lo obtiene y sincroniza desde Firestore
        context.push('/sala/$codigo', extra: {
          'token': '',
          'nombre': nombre,
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La sala no existe. Verifica el código.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al unirse: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
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
        decoration: Variables.fondobody,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/imagenes/logo.png",
                    width: MediaQuery.of(context).size.width * 0.35,
                  ),
                  Text(
                    'Unirse a una Sala',
                    style: Disenos.estiloTitulo,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    style: Disenos.estiloTextoInput,
                    decoration: Disenos.estiloCampoTexto.copyWith(
                      hintText: "Nombre de usuario",
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Disenos.colorVerdeNeon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codigoController,
                    keyboardType: TextInputType.number,
                    style: Disenos.estiloTextoInput,
                    decoration: Disenos.estiloCampoTexto.copyWith(
                      hintText: "Codigo de sala",
                      prefixIcon: const Icon(
                        Icons.code,
                        color: Disenos.colorVerdeNeon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _unirseALaSala,
                      style: Disenos.estiloBotonPrimario,
                      child: _cargando
                          ? const CircularProgressIndicator(
                              color: Disenos.colorVerdeNeon,
                            )
                          : const Text('Unirme a Sala'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
