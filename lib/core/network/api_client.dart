import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient(AppConfig config, this._storage) : _dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15), headers: {'Content-Type': 'application/json'}));

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _request(() => _dio.get(path, queryParameters: query));
  Future<Map<String, dynamic>> post(String path, {Object? data}) => _request(() => _dio.post(path, data: data));

  Future<Map<String, dynamic>> _request(Future<Response<dynamic>> Function() request) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) _dio.options.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await request();
      if (response.data is Map<String, dynamic>) return response.data as Map<String, dynamic>;
      return {'data': response.data};
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] != null ? data['message'].toString() : 'No se pudo completar la solicitud';
      throw ApiException(message, error.response?.statusCode);
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
