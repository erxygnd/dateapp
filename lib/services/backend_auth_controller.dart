import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/backend_auth_models.dart';
import 'backend_api_client.dart';

final BackendAuthController backendAuthController = BackendAuthController(
  BackendApiClient(baseUrl: backendApiBaseUrl),
);

class BackendAuthController extends ChangeNotifier {
  final BackendApiClient apiClient;

  BackendAuthController(this.apiClient);

  BackendAuthSession? _session;
  bool _initialized = false;

  BackendAuthSession? get session => _session;
  bool get initialized => _initialized;
  bool get isSignedIn => _session != null;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_Keys.accessToken);
    final refreshToken = prefs.getString(_Keys.refreshToken);
    final userId = prefs.getString(_Keys.userId);
    final userName = prefs.getString(_Keys.userName);
    final email = prefs.getString(_Keys.email);
    final accessTokenExpiresAt = DateTime.tryParse(
      prefs.getString(_Keys.accessTokenExpiresAt) ?? "",
    );
    final refreshTokenExpiresAt = DateTime.tryParse(
      prefs.getString(_Keys.refreshTokenExpiresAt) ?? "",
    );

    if (accessToken != null &&
        refreshToken != null &&
        userId != null &&
        userName != null &&
        email != null &&
        accessTokenExpiresAt != null &&
        refreshTokenExpiresAt != null &&
        refreshTokenExpiresAt.isAfter(DateTime.now())) {
      _session = BackendAuthSession(
        userId: userId,
        userName: userName,
        email: email,
        accessToken: accessToken,
        accessTokenExpiresAt: accessTokenExpiresAt,
        refreshToken: refreshToken,
        refreshTokenExpiresAt: refreshTokenExpiresAt,
      );
    } else {
      await clearSession();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> login({required String login, required String password}) async {
    final json = await apiClient.postMap("/api/auth/login", {
      "login": login,
      "password": password,
    });

    await saveSession(BackendAuthSession.fromJson(json));
  }

  Future<void> register({
    required String userName,
    required String email,
    required String password,
    required String displayName,
    required DateTime birthDate,
    required String gender,
    required String bio,
    required String phoneNumber,
    required List<String> photoUrls,
  }) async {
    final authJson = await apiClient.postMap("/api/auth/register", {
      "userName": userName,
      "email": email,
      "password": password,
      "displayName": displayName,
      "birthDate": backendDateOnly(birthDate),
      "city": "Ankara",
    });
    final authSession = BackendAuthSession.fromJson(authJson);
    await saveSession(authSession);

    await updateProfile(
      displayName: displayName,
      birthDate: birthDate,
      gender: gender,
      bio: bio,
      phoneNumber: phoneNumber,
      city: "Ankara",
      photoUrls: photoUrls,
    );
  }

  Future<BackendProfile> fetchProfile() async {
    final token = await accessToken();
    final json = await apiClient.getMap("/api/profile/me", accessToken: token);

    return BackendProfile.fromJson(json);
  }

  Future<BackendProfile> updateProfile({
    required String displayName,
    required DateTime birthDate,
    required String gender,
    required String bio,
    required String phoneNumber,
    required String city,
    required List<String> photoUrls,
  }) async {
    final token = await accessToken();
    final json = await apiClient.putMap("/api/profile/me", {
      "displayName": displayName,
      "birthDate": backendDateOnly(birthDate),
      "gender": gender,
      "bio": bio,
      "phoneNumber": phoneNumber,
      "city": city,
      "photoUrls": photoUrls,
    }, accessToken: token);

    return BackendProfile.fromJson(json);
  }

  Future<void> logout() async {
    final current = _session;

    if (current != null) {
      try {
        await apiClient.postMap("/api/auth/logout", {
          "refreshToken": current.refreshToken,
        });
      } catch (_) {
        // Local session yine temizlenir; logout endpointine ulasamamak kullaniciyi kilitlemesin.
      }
    }

    await clearSession();
    notifyListeners();
  }

  Future<String> accessToken() async {
    await initialize();
    final current = _session;

    if (current == null) {
      throw const BackendApiException(401, "Backend oturumu bulunamadı.");
    }

    if (current.accessTokenExpiresAt.isAfter(
      DateTime.now().add(const Duration(minutes: 1)),
    )) {
      return current.accessToken;
    }

    final json = await apiClient.postMap("/api/auth/refresh", {
      "refreshToken": current.refreshToken,
    });
    final refreshed = BackendAuthSession.fromJson(json);
    await saveSession(refreshed);

    return refreshed.accessToken;
  }

  Future<void> saveSession(BackendAuthSession session) async {
    _session = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.userId, session.userId);
    await prefs.setString(_Keys.userName, session.userName);
    await prefs.setString(_Keys.email, session.email);
    await prefs.setString(_Keys.accessToken, session.accessToken);
    await prefs.setString(_Keys.refreshToken, session.refreshToken);
    await prefs.setString(
      _Keys.accessTokenExpiresAt,
      session.accessTokenExpiresAt.toIso8601String(),
    );
    await prefs.setString(
      _Keys.refreshTokenExpiresAt,
      session.refreshTokenExpiresAt.toIso8601String(),
    );
    notifyListeners();
  }

  Future<void> clearSession() async {
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_Keys.userId);
    await prefs.remove(_Keys.userName);
    await prefs.remove(_Keys.email);
    await prefs.remove(_Keys.accessToken);
    await prefs.remove(_Keys.refreshToken);
    await prefs.remove(_Keys.accessTokenExpiresAt);
    await prefs.remove(_Keys.refreshTokenExpiresAt);
  }
}

class _Keys {
  static const userId = "backend_user_id";
  static const userName = "backend_user_name";
  static const email = "backend_email";
  static const accessToken = "backend_access_token";
  static const refreshToken = "backend_refresh_token";
  static const accessTokenExpiresAt = "backend_access_token_expires_at";
  static const refreshTokenExpiresAt = "backend_refresh_token_expires_at";
}
