import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  final config = AppConfig.fromEnvironment();
  final authRepository = AuthRepository(ApiClient(config, storage), storage);
  await authRepository.initialize();
  runApp(ProviderScope(overrides: [appConfigProvider.overrideWithValue(config), authRepositoryProvider.overrideWithValue(authRepository)], child: const RockifyApp()));
}
