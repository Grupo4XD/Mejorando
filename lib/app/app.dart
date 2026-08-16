import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/rooms/presentation/create_room_screen.dart';
import '../features/rooms/presentation/join_room_screen.dart';
import '../features/rooms/presentation/room_screen.dart';

class RockifyApp extends StatelessWidget {
  const RockifyApp({super.key});

  static final GoRouter _router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/create', builder: (_, _) => const CreateRoomScreen()),
    GoRoute(path: '/join', builder: (_, _) => const JoinRoomScreen()),
    GoRoute(path: '/room/:code', builder: (_, state) {
      return RoomScreen(code: state.pathParameters['code']!);
    })
  ]);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1ED760), brightness: Brightness.dark);
    return MaterialApp.router(
      title: 'Rockify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFF07120D), textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme), useMaterial3: true),
      routerConfig: _router
    );
  }
}
