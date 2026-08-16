import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.wsBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api'),
    wsBaseUrl: String.fromEnvironment('WS_BASE_URL', defaultValue: 'http://10.0.2.2:3000')
  );

  final String apiBaseUrl;
  final String wsBaseUrl;
}

final appConfigProvider = Provider<AppConfig>((_) => throw UnimplementedError());
