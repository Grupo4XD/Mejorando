import 'package:go_router/go_router.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Inicio.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Name.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Invitado.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Oauth.dart';
import 'package:proyecto_rockify/pantallas/pantalla_Sala.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PantallaInicio(),
    ),
    GoRoute(
      path: '/crear-sala',
      builder: (context, state) => const PantallaName(),
    ),
    GoRoute(
      path: '/unirse',
      builder: (context, state) => const PantallaInvitado(),
    ),
    GoRoute(
      path: '/oauth',
      builder: (context, state) {
        final nombre = state.extra as String;
        return PantallaOauth(nombreUsuario: nombre);
      },
    ),
    GoRoute(
      path: '/sala/:codigo',
      builder: (context, state) {
        final codigo = state.pathParameters['codigo']!;
        // `extra` recibe los datos iniciales (token, nombre); la sala luego sincroniza con Firestore
        final extra = state.extra as Map<String, dynamic>?;
        return PantallaSala(
          codigoSala: codigo,
          token: extra?['token'] as String? ?? '',
          nombreUsuarioActual: extra?['nombre'] as String? ?? '',
        );
      },
    ),
  ],
);