import 'package:go_router/go_router.dart';
// imports de tus pantallas
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
        //Con el extra podemos pasar parametros a la pantalla
        final nombre = state.extra as String; // o state.uri.queryParameters['nombre']
        return PantallaOauth(nombreUsuario: nombre);
      },
    ),

    //Para mandar con parametros
    GoRoute(
      path: '/sala/:codigo',
      builder: (context, state) {
        final codigo = state.pathParameters['codigo']!;
        final extra = state.extra as Map<String, dynamic>?; // token, nombre, etc.
        return PantallaSala(
          codigoSala: codigo,
          token: extra?['token'] as String? ?? '',
          nombreUsuarioActual: extra?['nombre'] as String? ?? '',
        );
      },
    ),
  ],
);