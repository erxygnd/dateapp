import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final int statusCode;
  final String message;

  const BackendApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class BackendApiClient {
  static const Duration requestTimeout = Duration(seconds: 12);

  final String baseUrl;
  final http.Client httpClient;

  BackendApiClient({required this.baseUrl, http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  Future<Map<String, dynamic>> getMap(
    String path, {
    String? accessToken,
    Map<String, String>? query,
  }) async {
    final response = await httpClient
        .get(_uri(path, query), headers: _headers(accessToken: accessToken))
        .timeout(requestTimeout);

    return _decodeMap(response);
  }

  Future<List<dynamic>> getList(
    String path, {
    String? accessToken,
    Map<String, String>? query,
  }) async {
    final response = await httpClient
        .get(_uri(path, query), headers: _headers(accessToken: accessToken))
        .timeout(requestTimeout);

    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postMap(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final response = await httpClient
        .post(
          _uri(path),
          headers: _headers(accessToken: accessToken, hasBody: true),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> putMap(
    String path,
    Map<String, dynamic> body, {
    required String accessToken,
  }) async {
    final response = await httpClient
        .put(
          _uri(path),
          headers: _headers(accessToken: accessToken, hasBody: true),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);

    return _decodeMap(response);
  }

  Future<void> delete(String path, {required String accessToken}) async {
    final response = await httpClient
        .delete(_uri(path), headers: _headers(accessToken: accessToken))
        .timeout(requestTimeout);

    _throwIfFailed(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith("/")
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith("/") ? path : "/$path";

    return Uri.parse(
      "$normalizedBase$normalizedPath",
    ).replace(queryParameters: query);
  }

  Map<String, String> _headers({String? accessToken, bool hasBody = false}) {
    return {
      "Accept": "application/json",
      if (hasBody) "Content-Type": "application/json",
      if (accessToken != null) "Authorization": "Bearer $accessToken",
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    _throwIfFailed(response, decoded: decoded);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const BackendApiException(500, "Beklenmeyen API cevabi.");
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = response.body.trim().isEmpty
        ? <dynamic>[]
        : jsonDecode(response.body);

    _throwIfFailed(response, decoded: decoded);

    if (decoded is List) {
      return decoded;
    }

    throw const BackendApiException(500, "Beklenmeyen API cevabi.");
  }

  void _throwIfFailed(http.Response response, {dynamic decoded}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final body =
        decoded ??
        (response.body.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body));

    throw BackendApiException(
      response.statusCode,
      _errorMessage(body, response.statusCode),
    );
  }

  String _errorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded["message"];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }

      final errors = decoded["errors"];

      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;

        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }

      final title = decoded["title"];

      if (title is String && title.trim().isNotEmpty) {
        return title;
      }
    }

    return "API hatasi olustu. Kod: $statusCode";
  }
}
