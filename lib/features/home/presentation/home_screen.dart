import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.queue_music_rounded, size: 84, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text('Rockify', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Crea una sala, conecta tu Spotify Premium e invita a tus amigos a elegir la música.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 40),
                FilledButton.icon(onPressed: () => context.push('/create'), icon: const Icon(Icons.add), label: const Text('Crear sala')),
                const SizedBox(height: 14),
                OutlinedButton.icon(onPressed: () => context.push('/join'), icon: const Icon(Icons.group_add_outlined), label: const Text('Unirme a una sala'))
              ])
            )
          )
        )
      )
    );
  }
}
