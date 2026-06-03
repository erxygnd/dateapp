import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_config.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'models/encounter_post.dart';
import 'models/local_profile_photo.dart';
import 'models/premium_access.dart';
import 'services/account_deletion_service.dart';
import 'services/profile_service.dart';
import 'utils/chat_utils.dart';
import 'utils/location_rules.dart';

Future<void> main() async {
  // Flutter tarafini hazirlamadan Firebase gibi native servisleri baslatamayiz.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    // Web'de sayfa yenilense bile kullanici oturumu tarayicida kalsin.
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const MyDatingApp());
}

String? loadedThemeUserId;

Future<void> loadSavedThemeForUser(User user) async {
  if (loadedThemeUserId == user.uid) {
    return;
  }

  loadedThemeUserId = user.uid;

  try {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();
    final themeMode = AppThemeChoice.fromValue(doc.data()?["themeMode"]);
    appThemeController.value = themeMode;
  } catch (_) {
    // Tema yuklenemezse uygulama acilmaya devam eder; varsayilan koyu mod kalir.
  }
}

class MyDatingApp extends StatelessWidget {
  const MyDatingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeChoice>(
      valueListenable: appThemeController,
      builder: (context, themeChoice, child) {
        return MaterialApp(
          title: 'Fıldır',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(themeChoice),
          home: const StartupPage(),
        );
      },
    );
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  bool showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1900), () {
      if (mounted) {
        setState(() {
          showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: showSplash
          ? const AppSplashPage(key: ValueKey("splash"))
          : const AuthGate(key: ValueKey("auth")),
    );
  }
}

class AppSplashPage extends StatelessWidget {
  const AppSplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            "assets/images/splash_street.png",
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66050816),
                  Color(0x11050816),
                  Color(0xD9050816),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 34),
              child: Column(
                children: [
                  Row(
                    children: [
                      appLogo(size: 54),
                      const SizedBox(width: 12),
                      const Text(
                        "Fıldır",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Yarım kalan bakışlar\nburada eşleşir.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Şehrin kalabalığında kaçırdığın anı yeniden bul.",
                      style: TextStyle(
                        color: Color(0xD6FFFFFF),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.accent,
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF211020), Color(0xFF120D1A), Color(0xFF1A1018)]
              : [Colors.white, AppColors.background, AppColors.backgroundSoft],
        ),
      ),
      child: child,
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(
              alpha: AppColors.isDark ? 0.16 : 0.10,
            ),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark ? 0.22 : 0.06,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (!enableExpensiveGlassBlur) {
      return panel;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: panel,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // FirebaseAuth burada uygulamanin kapicisi gibi calisir:
      // kullanici giris yaptiysa ana sayfa, yapmadiysa login ekrani acilir.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingPage();
        }

        if (snapshot.hasData) {
          unawaited(loadSavedThemeForUser(snapshot.data!));
          return const WelcomePage();
        }

        loadedThemeUserId = null;
        return const LoginPage();
      },
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
    );
  }
}

Future<Position> getCurrentPositionSafely() async {
  // Once telefonun konum servisi acik mi bakiyoruz. Kapaliysa izin istemek yetmez.
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    throw Exception("Konum servisi kapalı. Lütfen telefon konumunu aç.");
  }

  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    // Kullanici daha once karar vermediyse burada ilk kez izin penceresi acilir.
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    throw Exception("Konum izni reddedildi.");
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      "Konum izni kalıcı olarak reddedilmiş. Uygulama ayarlarından konum izni vermen gerekiyor.",
    );
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 12),
    ),
  );
}

String friendlyAuthError(FirebaseAuthException e) {
  // Firebase hata kodlari teknik gelir. Bu fonksiyon onlari insanca mesaja cevirir.
  switch (e.code) {
    case "invalid-email":
      return "Geçerli bir mail gir.";
    case "user-disabled":
      return "Bu kullanıcı hesabı devre dışı bırakılmış.";
    case "user-not-found":
      return "Bu e-posta ile kayıtlı kullanıcı bulunamadı.";
    case "wrong-password":
      return "Şifre hatalı.";
    case "email-already-in-use":
      return "Bu e-posta zaten kayıtlı.";
    case "weak-password":
      return "Şifre çok zayıf. En az 6 karakter kullan.";
    case "operation-not-allowed":
      return "Firebase Authentication içinde Email/Password giriş yöntemi açık değil.";
    default:
      return e.message ?? "Kimlik doğrulama hatası oluştu.";
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?) validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.text),
      validator: validator,
      decoration: baseInputDecoration(label: label, hint: hint, icon: icon),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool isRequired;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLines,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.text),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return isRequired ? "$label boş bırakılamaz" : null;
        }

        if (isRequired && value.trim().length < 3) {
          return "$label çok kısa";
        }

        return null;
      },
      decoration: baseInputDecoration(label: label, hint: hint, icon: icon),
    );
  }
}

int calculateAge(DateTime birthDate, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var age = now.year - birthDate.year;

  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }

  return age;
}

String formatBirthDate(DateTime birthDate) {
  final day = birthDate.day.toString().padLeft(2, "0");
  final month = birthDate.month.toString().padLeft(2, "0");
  return "$day.$month.${birthDate.year}";
}

String normalizeUsername(String value) {
  // Eray, eray ve ERAY ayni kullanici adi sayilsin diye hepsini kuculturuz.
  return value.trim().toLowerCase();
}

bool isValidUsername(String value) {
  return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value.trim());
}

bool isValidEmail(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}

String onlyPhoneDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), "");
}

String? validatePhoneNumber(String? value) {
  final phone = value?.trim() ?? "";
  final digits = onlyPhoneDigits(phone);

  if (phone.isEmpty) {
    return "Telefon numarası boş bırakılamaz";
  }

  if (digits.length < 10 || digits.length > 15) {
    return "Geçerli bir telefon numarası gir";
  }

  return null;
}

String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? "";

  if (email.isEmpty) {
    return "E-posta boş bırakılamaz";
  }

  if (!isValidEmail(email)) {
    return "Geçerli bir mail gir";
  }

  return null;
}

String? validateRegisterPassword(String? value) {
  final password = value ?? "";

  if (password.trim().isEmpty) {
    return "Şifre boş bırakılamaz";
  }

  if (password.length < 8) {
    return "Şifre en az 8 karakter olmalı";
  }

  if (!RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(password)) {
    return "Şifre en az 1 büyük harf içermeli";
  }

  if (!RegExp(r'[a-zçğıöşü]').hasMatch(password)) {
    return "Şifre en az 1 küçük harf içermeli";
  }

  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return "Şifre en az 1 rakam içermeli";
  }

  if (!RegExp(
    r"""[!@#$%^&*(),.?":{}|<>_\-+=;/'\[\]\\`~]""",
  ).hasMatch(password)) {
    return "Şifre en az 1 noktalama işareti içermeli";
  }

  return null;
}

final Map<String, ImageProvider<Object>> profilePhotoImageProviderCache = {};
final Map<String, Uint8List?> embeddedProfilePhotoBytesCache = {};

void trimProfilePhotoCaches() {
  while (profilePhotoImageProviderCache.length > profilePhotoMemoryCacheLimit) {
    profilePhotoImageProviderCache.remove(
      profilePhotoImageProviderCache.keys.first,
    );
  }

  while (embeddedProfilePhotoBytesCache.length > profilePhotoMemoryCacheLimit) {
    embeddedProfilePhotoBytesCache.remove(
      embeddedProfilePhotoBytesCache.keys.first,
    );
  }
}

T cacheProfilePhotoValue<T>(Map<String, T> cache, String source, T value) {
  cache[source] = value;
  trimProfilePhotoCaches();
  return value;
}

Future<List<String>> prepareProfilePhotoSources({
  required List<LocalProfilePhoto> photos,
}) async {
  // Su an fotograflari Storage'a yuklemek yerine base64 metin olarak sakliyoruz.
  // Yani resim aslinda uzun bir yaziya cevrilip Firestore alanina konuyor.
  return photos.map((photo) => photo.toDataUrl()).toList();
}

bool isEmbeddedProfilePhoto(String source) {
  return source.startsWith(profilePhotoDataPrefix);
}

Uint8List? embeddedProfilePhotoBytes(String source) {
  if (embeddedProfilePhotoBytesCache.containsKey(source)) {
    // Ayni fotografi tekrar tekrar decode etmek telefonu yorar; once cache'e bakiyoruz.
    return embeddedProfilePhotoBytesCache[source];
  }

  if (!isEmbeddedProfilePhoto(source)) {
    return cacheProfilePhotoValue(embeddedProfilePhotoBytesCache, source, null);
  }

  try {
    final bytes = base64Decode(source.substring(profilePhotoDataPrefix.length));
    return cacheProfilePhotoValue(
      embeddedProfilePhotoBytesCache,
      source,
      bytes,
    );
  } on FormatException {
    return cacheProfilePhotoValue(embeddedProfilePhotoBytesCache, source, null);
  }
}

Widget buildSavedProfilePhotoImage(String source) {
  final cachedProvider = profilePhotoImageProviderCache[source];

  if (cachedProvider != null) {
    // Resim provider'i daha once hazirlandiysa tekrar hazirlamiyoruz.
    return Image(
      image: cachedProvider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          const _PhotoTileMessage(icon: Icons.broken_image, text: "Açılamadı"),
    );
  }

  final embeddedBytes = embeddedProfilePhotoBytes(source);
  final ImageProvider<Object> baseProvider = embeddedBytes == null
      ? NetworkImage(source)
      : MemoryImage(embeddedBytes);
  final provider = ResizeImage(
    baseProvider,
    width: profilePhotoPreviewCacheSize,
  );
  cacheProfilePhotoValue(profilePhotoImageProviderCache, source, provider);

  return Image(
    image: provider,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) =>
        const _PhotoTileMessage(icon: Icons.broken_image, text: "Açılamadı"),
  );
}

Future<LocalProfilePhoto?> pickAndCropProfilePhoto({
  required BuildContext context,
  required ImagePicker imagePicker,
}) async {
  final picked = await imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
    maxWidth: 1200,
    maxHeight: 1200,
  );

  if (picked == null) {
    return null;
  }

  final originalBytes = await picked.readAsBytes().timeout(
    profilePhotoUploadTimeout,
  );

  if (!context.mounted) {
    return null;
  }

  final croppedBytes = await Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(builder: (_) => CropPhotoPage(imageBytes: originalBytes)),
  );

  if (croppedBytes == null) {
    return null;
  }

  return LocalProfilePhoto(
    // Crop ekranindan gelen temizlenmis kare fotograf artik profile kaydedilebilir.
    bytes: croppedBytes,
    fileName: "profile_${DateTime.now().millisecondsSinceEpoch}.png",
    contentType: "image/png",
  );
}

class ProfilePhotoPicker extends StatelessWidget {
  final List<LocalProfilePhoto> localPhotos;
  final List<String> photoUrls;
  final VoidCallback onAddPhoto;
  final void Function(int index) onRemoveLocalPhoto;
  final void Function(int index) onRemoveRemotePhoto;
  final bool enabled;

  const ProfilePhotoPicker({
    super.key,
    required this.localPhotos,
    required this.photoUrls,
    required this.onAddPhoto,
    required this.onRemoveLocalPhoto,
    required this.onRemoveRemotePhoto,
    this.enabled = true,
  });

  int get totalCount => localPhotos.length + photoUrls.length;

  @override
  Widget build(BuildContext context) {
    final slots = List<Widget>.generate(3, (index) {
      if (index < photoUrls.length) {
        return _PhotoTile(
          image: buildSavedProfilePhotoImage(photoUrls[index]),
          onRemove: enabled ? () => onRemoveRemotePhoto(index) : null,
        );
      }

      final localIndex = index - photoUrls.length;

      if (localIndex < localPhotos.length) {
        return _LocalPhotoTile(
          photo: localPhotos[localIndex],
          onRemove: enabled ? () => onRemoveLocalPhoto(localIndex) : null,
        );
      }

      return _AddPhotoTile(
        enabled: enabled && totalCount < 3,
        onTap: onAddPhoto,
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Profil fotoğrafları",
          style: TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "En az 1, en fazla 3 fotoğraf ekle.",
          style: TextStyle(color: AppColors.softText, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(children: slots.map((slot) => Expanded(child: slot)).toList()),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _AddPhotoTile({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.backgroundSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: enabled ? AppColors.secondary : AppColors.softText,
          ),
        ),
      ),
    );
  }
}

class _LocalPhotoTile extends StatelessWidget {
  final LocalProfilePhoto photo;
  final VoidCallback? onRemove;

  const _LocalPhotoTile({required this.photo, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _PhotoTile(
      image: Image.memory(
        photo.bytes,
        fit: BoxFit.cover,
        cacheWidth: profilePhotoPreviewCacheSize,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _PhotoTileMessage(
          icon: Icons.broken_image_outlined,
          text: "Açılamadı",
        ),
      ),
      onRemove: onRemove,
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Widget image;
  final VoidCallback? onRemove;

  const _PhotoTile({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 120,
              child: ColoredBox(color: AppColors.cardSolid, child: image),
            ),
            if (onRemove != null)
              Positioned(
                right: 6,
                top: 6,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: AppColors.text),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTileMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PhotoTileMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.softText, size: 24),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(color: AppColors.softText, fontSize: 12)),
        ],
      ),
    );
  }
}

class CropPhotoPage extends StatefulWidget {
  final Uint8List imageBytes;

  const CropPhotoPage({super.key, required this.imageBytes});

  @override
  State<CropPhotoPage> createState() => _CropPhotoPageState();
}

class _CropPhotoPageState extends State<CropPhotoPage> {
  final GlobalKey cropKey = GlobalKey();
  final TransformationController transformationController =
      TransformationController();

  bool isCropping = false;

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }

  Future<void> useCrop() async {
    if (isCropping) {
      return;
    }

    setState(() {
      isCropping = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception("Fotoğraf kırpılamadı.");
      }

      final cropPixelRatio =
          (profilePhotoStoredPixels / boundary.size.shortestSide)
              .clamp(0.2, 1.0)
              .toDouble();
      final croppedImage = await boundary.toImage(pixelRatio: cropPixelRatio);
      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      croppedImage.dispose();

      if (!mounted) {
        return;
      }

      if (byteData == null) {
        throw Exception("Fotoğraf hazırlanamadı.");
      }

      Navigator.pop(context, byteData.buffer.asUint8List());
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isCropping = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void resetCrop() {
    transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final cropSize = (MediaQuery.of(context).size.width - 48)
        .clamp(240.0, 420.0)
        .toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text("Fotoğrafı Kırp"),
        actions: [
          IconButton(
            onPressed: isCropping ? null : resetCrop,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: isCropping ? null : useCrop,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Center(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: cropKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox.square(
                          dimension: cropSize,
                          child: InteractiveViewer(
                            transformationController: transformationController,
                            minScale: 1,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(120),
                            child: Image.memory(
                              widget.imageBytes,
                              width: cropSize,
                              height: cropSize,
                              fit: BoxFit.cover,
                              cacheWidth: 1200,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isCropping)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isCropping
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text("Vazgeç"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isCropping ? null : useCrop,
                        icon: const Icon(Icons.check),
                        label: const Text("Kullan"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final loginId = emailController.text.trim();
      var email = loginId;

      if (!loginId.contains("@")) {
        // Kullanici e-posta yerine kullanici adi yazarsa once onun e-postasini buluyoruz.
        // Firebase Auth sadece e-posta+sifre ile giris yaptigi icin bu ara tablo gerekli.
        final usernameDoc = await FirebaseFirestore.instance
            .collection("usernames")
            .doc(normalizeUsername(loginId))
            .get();

        if (!mounted) {
          return;
        }

        if (!usernameDoc.exists) {
          showMessage("Bu kullanıcı adıyla kayıtlı hesap bulunamadı.");
          return;
        }

        email = (usernameDoc.data()?["email"] ?? "").toString();

        if (email.isEmpty) {
          showMessage("Bu kullanıcı adına bağlı e-posta bulunamadı.");
          return;
        }
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        // Burasi asil giris noktasi: Firebase e-posta ve sifreyi dogrular.
        email: email,
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(friendlyAuthError(e));
    } catch (e) {
      showMessage("Giriş yapılırken hata oluştu: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  appLogo(),
                  const SizedBox(height: 32),
                  Text(
                    "Fıldır",
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Hesabına giriş yap",
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Yakınındaki karşılaşmaları gör, kendi itirafını bırak ve sadece karşılıklı onayla iletişim kur.",
                    style: TextStyle(
                      color: AppColors.softText,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  AuthTextField(
                    controller: emailController,
                    label: "E-posta veya kullanıcı adı",
                    hint: "ornek@mail.com veya eray_24",
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "E-posta veya kullanıcı adı boş bırakılamaz";
                      }

                      if (value.contains("@") && !isValidEmail(value)) {
                        return "Geçerli bir mail gir";
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: isPasswordHidden,
                    style: TextStyle(color: AppColors.text),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Şifre boş bırakılamaz";
                      }

                      if (value.length < 6) {
                        return "Şifre en az 6 karakter olmalı";
                      }

                      return null;
                    },
                    decoration: authPasswordDecoration(
                      label: "Şifre",
                      hint: "Şifreni gir",
                      isHidden: isPasswordHidden,
                      onPressed: () {
                        setState(() {
                          isPasswordHidden = !isPasswordHidden;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: mainButtonStyle(),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Giriş Yap",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Hesabın yok mu?",
                        style: TextStyle(color: AppColors.softText),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text("Kayıt ol"),
                      ),
                    ],
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final ImagePicker imagePicker = ImagePicker();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordAgainController = TextEditingController();

  final List<LocalProfilePhoto> selectedPhotos = [];
  DateTime? selectedBirthDate;
  String? selectedGender;
  bool isPasswordHidden = true;
  bool isPasswordAgainHidden = true;
  bool acceptedRules = false;
  bool isLoading = false;

  @override
  void dispose() {
    usernameController.dispose();
    displayNameController.dispose();
    birthDateController.dispose();
    bioController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    passwordAgainController.dispose();
    super.dispose();
  }

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedBirthDate ?? DateTime(now.year - 24, now.month),
      firstDate: DateTime(now.year - 120),
      lastDate: lastDate,
    );

    if (picked == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      selectedBirthDate = picked;
      birthDateController.text = formatBirthDate(picked);
    });
  }

  Future<void> pickPhoto() async {
    if (selectedPhotos.length >= 3) {
      showMessage("En fazla 3 fotoğraf ekleyebilirsin.");
      return;
    }

    try {
      final croppedPhoto = await pickAndCropProfilePhoto(
        context: context,
        imagePicker: imagePicker,
      );

      if (croppedPhoto == null || !mounted) {
        return;
      }

      setState(() {
        selectedPhotos.add(croppedPhoto);
      });
    } on TimeoutException {
      showMessage("Fotoğraf hazırlanırken çok uzun sürdü. Tekrar dene.");
    } catch (e) {
      showMessage("Fotoğraf seçilemedi: $e");
    }
  }

  Future<void> register() async {
    // Kayit icin once ekrandaki kurallari kontrol ediyoruz.
    // Bunlardan biri eksikse Firebase'e hic gitmeden kullaniciyi durduruyoruz.
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!acceptedRules) {
      showMessage("Devam etmek için güvenlik kurallarını kabul etmelisin.");
      return;
    }

    if (selectedBirthDate == null) {
      showMessage("Doğum tarihini seçmelisin.");
      return;
    }

    if (selectedGender == null) {
      showMessage("Cinsiyet seçmelisin.");
      return;
    }

    if (selectedPhotos.isEmpty) {
      showMessage("En az 1 profil fotoğrafı eklemelisin.");
      return;
    }

    final age = calculateAge(selectedBirthDate!);

    if (age < 18) {
      showMessage("Devam etmek için 18 yaşından büyük olmalısın.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final username = usernameController.text.trim();
      final usernameLower = normalizeUsername(username);
      final phoneNumber = phoneController.text.trim();
      final phoneDigits = onlyPhoneDigits(phoneNumber);
      final firestore = FirebaseFirestore.instance;
      final usernameRef = firestore.collection("usernames").doc(usernameLower);
      final existingUsername = await usernameRef.get();

      if (!mounted) {
        return;
      }

      if (existingUsername.exists) {
        // Ayni kullanici adini iki kisinin almasini engelleyen ilk kontrol.
        showMessage("Bu kullanıcı adı alınmış.");
        return;
      }

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            // Once Firebase Auth hesabi acilir. UID burada olusur.
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final user = credential.user!;
      try {
        // Sonra kullanici adi ayri bir belgeye yazilir.
        // Boylece login ekraninda "kullanici adi -> e-posta" aramasi yapabiliriz.
        await usernameRef.set({
          "uid": user.uid,
          "username": username,
          "usernameLower": usernameLower,
          "email": emailController.text.trim(),
          "phoneDigits": phoneDigits,
          "createdAt": FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        // Burada hata olursa Auth hesabi bos bos kalmasin diye yeni acilan hesabi siliyoruz.
        await user.delete();
        showMessage("Bu kullanici adi az once alindi. Baska bir ad dene.");
        return;
      }

      final photoUrls = await prepareProfilePhotoSources(
        photos: selectedPhotos,
      );

      unawaited(
        // DisplayName sadece Firebase Auth profilindeki kisa isimdir.
        // Basarisiz olursa ana profil kaydini bozmasin diye beklemeden devam ediyoruz.
        user
            .updateDisplayName(displayNameController.text.trim())
            .timeout(profileSaveTimeout)
            .catchError((_) {}),
      );

      await firestore
          .collection("users")
          .doc(user.uid)
          .set({
            // Uygulamada asil kullanilan profil bilgisi Firestore'daki users/{uid} belgesidir.
            "uid": user.uid,
            "username": username,
            "usernameLower": usernameLower,
            "name": displayNameController.text.trim(),
            "displayName": displayNameController.text.trim(),
            "age": age,
            "birthDate": Timestamp.fromDate(selectedBirthDate!),
            "birthDateText": birthDateController.text,
            "gender": selectedGender,
            "bio": bioController.text.trim(),
            "email": emailController.text.trim(),
            "phoneNumber": phoneNumber,
            "phoneDigits": phoneDigits,
            "photoUrls": photoUrls,
            "photoUploadPending": false,
            "premium": PremiumAccess.defaultUserState(),
            "tutorialCompleted": false,
            "dismissedEncounterIds": [],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          })
          .timeout(profileSaveTimeout);

      if (mounted) {
        // Kayit biter bitmez kullaniciyi uygulamayi anlatan ilk tur ekrana aliyoruz.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppTutorialPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(friendlyAuthError(e));
    } on TimeoutException {
      showMessage(
        "Kayıt işlemi çok uzun sürdü. İnternetini kontrol edip tekrar dene.",
      );
    } catch (e) {
      showMessage("Kayıt oluşturulurken hata oluştu: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text("Kayıt Ol"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Yeni hesap oluştur",
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Yakınındaki itirafları görmek ve karşılaşma bırakmak için hesap oluştur.",
                  style: TextStyle(
                    color: AppColors.softText,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  controller: usernameController,
                  label: "Kullanıcı adı",
                  hint: "ornek: eray_24",
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    final username = value?.trim() ?? "";

                    if (username.isEmpty) {
                      return "Kullanıcı adı boş bırakılamaz";
                    }

                    if (!isValidUsername(username)) {
                      return "3-20 karakter; harf, rakam veya _ kullan";
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: displayNameController,
                  label: "Görünecek isim",
                  hint: "Örn: Eray",
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Ad boş bırakılamaz";
                    }

                    if (value.trim().length < 2) {
                      return "Ad çok kısa";
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: birthDateController,
                  readOnly: true,
                  onTap: isLoading ? null : pickBirthDate,
                  style: TextStyle(color: AppColors.text),
                  validator: (_) {
                    if (selectedBirthDate == null) {
                      return "Doğum tarihini seç";
                    }

                    if (calculateAge(selectedBirthDate!) < 18) {
                      return "18 yaşından büyük olmalısın";
                    }

                    return null;
                  },
                  decoration: baseInputDecoration(
                    label: "Doğum tarihi",
                    hint: "GG.AA.YYYY",
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  dropdownColor: AppColors.cardSolid,
                  decoration: baseInputDecoration(
                    label: "Cinsiyet",
                    hint: "Kadın veya Erkek",
                    icon: Icons.wc_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(value: "Kadın", child: Text("Kadın")),
                    DropdownMenuItem(value: "Erkek", child: Text("Erkek")),
                  ],
                  validator: (value) {
                    if (value == null) {
                      return "Cinsiyet seç";
                    }

                    return null;
                  },
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: bioController,
                  label: "Biografi",
                  hint: "Kendini birkaç cümleyle anlat",
                  icon: Icons.badge_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ProfilePhotoPicker(
                  localPhotos: selectedPhotos,
                  photoUrls: const [],
                  enabled: !isLoading,
                  onAddPhoto: pickPhoto,
                  onRemoveLocalPhoto: (index) {
                    setState(() {
                      selectedPhotos.removeAt(index);
                    });
                  },
                  onRemoveRemotePhoto: (_) {},
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: emailController,
                  label: "E-posta",
                  hint: "ornek@mail.com",
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmailAddress,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: phoneController,
                  label: "Telefon numarası",
                  hint: "05xx xxx xx xx",
                  icon: Icons.phone_iphone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: validatePhoneNumber,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: isPasswordHidden,
                  style: TextStyle(color: AppColors.text),
                  validator: validateRegisterPassword,
                  decoration: authPasswordDecoration(
                    label: "Şifre",
                    hint: "En az 8 karakter, A harfi ve ! gibi işaret",
                    isHidden: isPasswordHidden,
                    onPressed: () {
                      setState(() {
                        isPasswordHidden = !isPasswordHidden;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordAgainController,
                  obscureText: isPasswordAgainHidden,
                  style: TextStyle(color: AppColors.text),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Şifre tekrarı boş bırakılamaz";
                    }

                    if (value != passwordController.text) {
                      return "Şifreler uyuşmuyor";
                    }

                    return null;
                  },
                  decoration: authPasswordDecoration(
                    label: "Şifre Tekrar",
                    hint: "Şifreni tekrar gir",
                    isHidden: isPasswordAgainHidden,
                    onPressed: () {
                      setState(() {
                        isPasswordAgainHidden = !isPasswordAgainHidden;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: acceptedRules,
                        onChanged: (value) {
                          setState(() {
                            acceptedRules = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          "18 yaşından büyük olduğumu, ilan ve sohbetlerde açık adres/telefon gibi özel bilgiler paylaşmayacağımı ve karşılıklı onay olmadan iletişim kuramayacağımı kabul ediyorum.",
                          style: TextStyle(
                            color: AppColors.softText,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    style: mainButtonStyle(),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Kayıt Ol",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Zaten hesabın var mı?",
                      style: TextStyle(color: AppColors.softText),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Giriş yap"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "Kullanıcı";

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: PremiumBottomNav(
        onChats: () => openPage(context, const ChatListPage()),
        onBrowse: () => openPage(context, const BrowseEncountersPage()),
        onProfile: () => openPage(context, const ProfilePage()),
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 118),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    appLogo(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "Fıldır",
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  "Merhaba, $userName",
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Şehrin içinde yarım kalan anları bul.",
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 33,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Yakınındaki itirafları gör, kendi karşılaşmanı bırak. Sohbet sadece iki taraf onay verirse açılır.",
                  style: TextStyle(
                    color: AppColors.softText,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                GlassPanel(
                  radius: 28,
                  padding: EdgeInsets.zero,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 360),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x26FFFFFF),
                          Color(0x18111827),
                          Color(0x24111827),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -42,
                          right: -38,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: -28,
                          bottom: 18,
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.14,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _MetricChip(
                                    icon: Icons.radar_rounded,
                                    label: "Yakın çevre",
                                    color: AppColors.secondary,
                                  ),
                                  SizedBox(width: 8),
                                  _MetricChip(
                                    icon: Icons.shield_outlined,
                                    label: "Onaylı sohbet",
                                    color: AppColors.accent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 150),
                              Text(
                                "Bugün bir bakış yarım kaldıysa, şehir onu unutmaz.",
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "Tam konum paylaşılmaz. Sadece yakınlık ve zaman bilgisiyle güvenli eşleşme akışı kurulur.",
                                style: TextStyle(
                                  color: AppColors.softText,
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        openPage(context, const CreateEncounterPage()),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text(
                      "Karşılaşma Bırak",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        openPage(context, const MyEncountersPage()),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text("İtiraflarım"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        openPage(context, const BrowseEncountersPage()),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text("Yakındaki İtirafları Keşfet"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppTutorialPage extends StatefulWidget {
  const AppTutorialPage({super.key});

  @override
  State<AppTutorialPage> createState() => _AppTutorialPageState();
}

class _TutorialStepData {
  final IconData icon;
  final String title;
  final String body;
  final List<String> bullets;

  const _TutorialStepData({
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
  });
}

class _AppTutorialPageState extends State<AppTutorialPage> {
  final PageController controller = PageController();
  int stepIndex = 0;
  bool isFinishing = false;

  static const List<_TutorialStepData> steps = [
    _TutorialStepData(
      icon: Icons.swipe_outlined,
      title: "İtirafları kart kart gör",
      body:
          "Yakınımdaki İtiraflar ekranında artık uzun liste yok. Karşına tek bir itiraf kutucuğu gelir.",
      bullets: [
        "Kutuda yer, zaman, kişi tarifi, not ve mesafe görünür.",
        "Okuduktan sonra kartı sağa veya sola kaydırırsın.",
      ],
    ),
    _TutorialStepData(
      icon: Icons.favorite_outline,
      title: "Sağa kaydırırsan istek gider",
      body:
          "Bu kişi ben olabilirim diyorsan kartı sağa kaydır. Uygulama ilanı bırakan kişiye istek gönderir.",
      bullets: [
        "İstek beklemede kalır.",
        "İlan sahibi seni Gelen İstekler ekranında görür.",
      ],
    ),
    _TutorialStepData(
      icon: Icons.style_outlined,
      title: "Gelen istekler de adım adım",
      body:
          "Sen ilan bıraktığında biri sağa kaydırırsa sana istek gelir. Burada karar yine basit.",
      bullets: [
        "Sağa kaydırırsan kabul edersin.",
        "Sola kaydırırsan reddedersin.",
      ],
    ),
    _TutorialStepData(
      icon: Icons.chat_bubble_outline,
      title: "İki taraf onaylarsa sohbet açılır",
      body:
          "Sohbet sadece karşılıklı onaydan sonra başlar. İlk dakikalarda fotoğraf kilidi vardır.",
      bullets: [
        "Mesaj ve ses kaydı gönderebilirsin.",
        "Rahatsız olursan raporla veya engelle.",
      ],
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finishTutorial() async {
    if (isFinishing) {
      return;
    }

    setState(() {
      isFinishing = true;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "tutorialCompleted": true,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  void nextStep() {
    if (stepIndex == steps.length - 1) {
      unawaited(finishTutorial());
      return;
    }

    controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget buildStep(_TutorialStepData step, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassPanel(
        radius: 28,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.24),
                ),
              ),
              child: Icon(step.icon, color: AppColors.accent, size: 30),
            ),
            const SizedBox(height: 24),
            Text(
              "Adım ${index + 1}",
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              step.body,
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            ...step.bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final selected = index == stepIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                child: Row(
                  children: [
                    appLogo(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Fıldır'ı hızlıca tanıyalım",
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: isFinishing
                          ? null
                          : () {
                              unawaited(finishTutorial());
                            },
                      child: const Text("Geç"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: steps.length,
                  onPageChanged: (value) {
                    setState(() {
                      stepIndex = value;
                    });
                  },
                  itemBuilder: (context, index) => Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: buildStep(steps[index], index),
                    ),
                  ),
                ),
              ),
              buildDots(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: isFinishing ? null : nextStep,
                    icon: Icon(
                      stepIndex == steps.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      stepIndex == steps.length - 1 ? "Başla" : "Sonraki adım",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.isDark ? const Color(0xFFF5B5CE) : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEncounterSearch extends StatefulWidget {
  final Widget radiusSelector;

  const _EmptyEncounterSearch({required this.radiusSelector});

  @override
  State<_EmptyEncounterSearch> createState() => _EmptyEncounterSearchState();
}

class _EmptyEncounterSearchState extends State<_EmptyEncounterSearch>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulseController;
  bool showRadiusSelector = false;

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          showRadiusSelector = true;
        });
      }
    });
  }

  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  Widget buildPulseRing(double delay) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final rawProgress = (pulseController.value + delay) % 1;
        final opacity = (1 - rawProgress) * 0.28;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.78 + rawProgress * 2.15,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  buildPulseRing(0),
                  buildPulseRing(0.18),
                  buildPulseRing(0.36),
                  appLogo(size: 118),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Şimdilik kaydıracak yeni itiraf yok.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Gösterilecek mesafeyi artırınca keşif alanı genişler. Yeni itiraf geldiğinde burada sıradaki kart olarak görünür.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSlide(
              offset: showRadiusSelector ? Offset.zero : const Offset(0, -0.28),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: showRadiusSelector ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                child: widget.radiusSelector,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumBottomNav extends StatelessWidget {
  final VoidCallback onChats;
  final VoidCallback onBrowse;
  final VoidCallback onProfile;

  const PremiumBottomNav({
    super.key,
    required this.onChats,
    required this.onBrowse,
    required this.onProfile,
  });

  int unreadChatCountForUser(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    String userId,
  ) {
    if (snapshot == null) {
      return 0;
    }

    var total = 0;

    for (final doc in snapshot.docs) {
      final counts = doc.data()["unreadCounts"];

      if (counts is Map) {
        final value = counts[userId];

        if (value is int) {
          total += value;
        } else {
          total += int.tryParse(value?.toString() ?? "") ?? 0;
        }
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: user == null
            ? null
            : FirebaseFirestore.instance
                  .collection("chats")
                  .where("participants", arrayContains: user.uid)
                  .limit(chatListPageSize)
                  .snapshots(),
        builder: (context, snapshot) {
          final unreadCount = user == null
              ? 0
              : unreadChatCountForUser(snapshot.data, user.uid);

          return GlassPanel(
            radius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.isDark
                ? const Color(0xF21A1424)
                : AppColors.card.withValues(alpha: 0.94),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _NavButton(
                  icon: Icons.chat_bubble_outline,
                  label: "Sohbet",
                  onPressed: onChats,
                  badgeCount: unreadCount,
                ),
                _DiscoverNavButton(onPressed: onBrowse),
                _NavButton(
                  icon: Icons.person_outline,
                  label: "Profil",
                  onPressed: onProfile,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiscoverNavButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DiscoverNavButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const discoverColor = Color(0xFF25E6C8);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: discoverColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: discoverColor.withValues(alpha: 0.36),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: discoverColor.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.explore_rounded,
                  color: discoverColor,
                  size: 31,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Keşfet",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AccountDeletionService accountDeletionService =
      AccountDeletionService();

  PermissionStatus? notificationStatus;
  bool isSavingTheme = false;
  bool isRequestingNotification = false;
  bool isLoggingOut = false;
  bool isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    unawaited(loadNotificationStatus());
  }

  Future<void> loadNotificationStatus() async {
    try {
      final status = await Permission.notification.status;
      if (!mounted) {
        return;
      }

      setState(() {
        notificationStatus = status;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        notificationStatus = PermissionStatus.denied;
      });
    }
  }

  Future<void> saveTheme(AppThemeChoice choice) async {
    if (appThemeController.value == choice) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    appThemeController.value = choice;

    if (user == null) {
      showMessage("Oturum bulunamadı.");
      return;
    }

    setState(() {
      isSavingTheme = true;
    });

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        // Tema kullanici tercihidir; hesaba yazarsak telefon degisse bile ayni kalir.
        "themeMode": choice.firestoreValue,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      showMessage("Tema kaydedilemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSavingTheme = false;
        });
      }
    }
  }

  Future<void> requestNotificationPermission() async {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      isRequestingNotification = true;
    });

    try {
      final status = await Permission.notification.request();

      if (user != null) {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          // OS izninin son durumunu kaydediyoruz; asil izin yine telefon ayarlarinda durur.
          "notificationPermission": status.name,
          "notificationsUpdatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        notificationStatus = status;
      });

      if (status.isGranted) {
        showMessage("Bildirim izni açık.");
      } else if (status.isPermanentlyDenied || status.isRestricted) {
        await showNotificationSettingsDialog();
      } else {
        showMessage("Bildirim izni verilmedi.");
      }
    } catch (e) {
      showMessage("Bildirim izni alınamadı: $e");
    } finally {
      if (mounted) {
        setState(() {
          isRequestingNotification = false;
        });
      }
    }
  }

  Future<void> showNotificationSettingsDialog() async {
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            "Bildirim izni kapalı",
            style: TextStyle(color: AppColors.text),
          ),
          content: Text(
            "Telefon ayarlarından Fıldır bildirimlerini açman gerekiyor.",
            style: TextStyle(color: AppColors.softText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ayarları Aç"),
            ),
          ],
        );
      },
    );

    if (shouldOpenSettings == true) {
      await openAppSettings();
      await loadNotificationStatus();
    }
  }

  String notificationStatusText() {
    final status = notificationStatus;

    if (status == null) {
      return "Kontrol ediliyor";
    }

    if (status.isGranted) {
      return "Açık";
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return "Telefon ayarlarından açılmalı";
    }

    return "Kapalı";
  }

  Future<String?> askDeletionPassword() async {
    final passwordController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            "Şifreyi doğrula",
            style: TextStyle(color: AppColors.text),
          ),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            style: TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: "Hesap şifren"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, passwordController.text.trim()),
              child: const Text("Doğrula"),
            ),
          ],
        );
      },
    );

    passwordController.dispose();
    return password;
  }

  Future<void> deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            "Hesabı kalıcı olarak sil",
            style: TextStyle(color: AppColors.text),
          ),
          content: Text(
            "Profilin, ilanların, isteklerin ve gönderdiğin sohbet mesajları silinir. Bu işlem geri alınamaz.",
            style: TextStyle(color: AppColors.softText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Hesabı Sil"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final password = await askDeletionPassword();

    if (password == null || password.isEmpty) {
      return;
    }

    setState(() {
      isDeletingAccount = true;
    });

    try {
      await accountDeletionService.reauthenticateWithPassword(password);
      await accountDeletionService.deleteCurrentAccount();

      if (!mounted) {
        return;
      }

      showMessage("Hesabın silindi.");
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == "wrong-password" || e.code == "invalid-credential") {
        showMessage("Şifre hatalı. Tekrar dene.");
      } else if (e.code == "requires-recent-login") {
        showMessage("Güvenlik için tekrar giriş yapıp yeniden dene.");
      } else {
        showMessage(friendlyAuthError(e));
      }
    } catch (e) {
      showMessage("Hesap silinemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          isDeletingAccount = false;
        });
      }
    }
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text("Hesaptan çık", style: TextStyle(color: AppColors.text)),
          content: Text(
            "Bu cihazda oturumun kapatılacak. İstediğin zaman tekrar giriş yapabilirsin.",
            style: TextStyle(color: AppColors.softText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Çıkış Yap"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      isLoggingOut = true;
    });

    await FirebaseAuth.instance.signOut();
    loadedThemeUserId = null;

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = appThemeController.value;
    final notificationButtonText =
        notificationStatus?.isPermanentlyDenied == true ||
            notificationStatus?.isRestricted == true
        ? "Telefon Ayarlarını Aç"
        : "Bildirim İzni İste";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Ayarlar")),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassPanel(
                  radius: 28,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      appLogo(size: 58),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Uygulama ayarları",
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Tema, bildirim ve hesap işlemleri burada.",
                              style: TextStyle(
                                color: AppColors.softText,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: "Tema",
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeChoiceCard(
                              selected: selectedTheme == AppThemeChoice.light,
                              icon: Icons.light_mode_outlined,
                              title: "Beyaz",
                              subtitle: "Açık görünüm",
                              onTap: isSavingTheme
                                  ? null
                                  : () => saveTheme(AppThemeChoice.light),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ThemeChoiceCard(
                              selected: selectedTheme == AppThemeChoice.dark,
                              icon: Icons.dark_mode_outlined,
                              title: "Siyah",
                              subtitle: "Koyu görünüm",
                              onTap: isSavingTheme
                                  ? null
                                  : () => saveTheme(AppThemeChoice.dark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: "Bildirimler",
                  child: _SettingsActionTile(
                    icon: Icons.notifications_active_outlined,
                    title: "Bildirim izni",
                    subtitle: notificationStatusText(),
                    trailing: isRequestingNotification
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : Text(
                            notificationButtonText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                    onTap: isRequestingNotification
                        ? null
                        : requestNotificationPermission,
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: "Hesap",
                  child: Column(
                    children: [
                      _SettingsActionTile(
                        icon: Icons.logout_rounded,
                        title: "Hesaptan çık",
                        subtitle: "Bu cihazdaki oturumu kapat",
                        trailing: isLoggingOut
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : Icon(
                                Icons.chevron_right,
                                color: AppColors.softText,
                              ),
                        onTap: isLoggingOut || isDeletingAccount
                            ? null
                            : logout,
                      ),
                      Divider(height: 1, color: AppColors.border),
                      _SettingsActionTile(
                        icon: Icons.delete_outline,
                        iconColor: AppColors.danger,
                        title: "Hesabı sil",
                        subtitle: "Profil ve hesap verilerini kalıcı sil",
                        titleColor: AppColors.danger,
                        trailing: isDeletingAccount
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.danger,
                                ),
                              )
                            : Icon(
                                Icons.chevron_right,
                                color: AppColors.danger,
                              ),
                        onTap: isLoggingOut || isDeletingAccount
                            ? null
                            : deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ThemeChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.inputFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.accent : AppColors.softText),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsActionTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.softText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: trailing),
          ],
        ),
      ),
    );
  }
}

class IdentitySegmentedControl extends StatelessWidget {
  final bool isAnonymous;
  final ValueChanged<bool>? onChanged;

  const IdentitySegmentedControl({
    super.key,
    required this.isAnonymous,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _IdentitySegment(
            selected: isAnonymous,
            icon: Icons.visibility_off_outlined,
            title: "Anonim",
            subtitle: "Adın görünmez",
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
          const SizedBox(width: 8),
          _IdentitySegment(
            selected: !isAnonymous,
            icon: Icons.badge_outlined,
            title: "Kimlikli",
            subtitle: "Profilin görünür",
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
        ],
      ),
    );
  }
}

class _IdentitySegment extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _IdentitySegment({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? LinearGradient(colors: [AppColors.accent, Color(0xFFFFD166)])
                : null,
            color: selected ? null : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.26),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.backgroundSoft : AppColors.softText,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.backgroundSoft
                            : AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.backgroundSoft.withValues(alpha: 0.72)
                            : AppColors.softText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int badgeCount;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.softText;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 24),
                  if (badgeCount > 0)
                    Positioned(
                      right: -10,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.cardSolid,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 99 ? "99+" : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LegacyWelcomePage extends StatelessWidget {
  const LegacyWelcomePage({super.key});

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "Kullanıcı";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Merhaba, $userName",
                    style: TextStyle(color: AppColors.softText, fontSize: 15),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: logout,
                    icon: Icon(Icons.logout, color: AppColors.softText),
                  ),
                ],
              ),
              const SizedBox(height: 44),
              appLogo(),
              const SizedBox(height: 32),
              Text(
                "Fıldır",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Gördün. Konuşamadın. Belki o da seni arıyordur.",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Yakınındaki itirafları gör. Kendi karşılaşmanı bırak. Tam konumun karşı tarafa gösterilmez.",
                style: TextStyle(
                  color: AppColors.softText,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.accent,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "Sohbet sadece iki taraf da onay verirse açılır.",
                        style: TextStyle(
                          color: AppColors.softText,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text("Profilim"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IncomingRequestsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.style_outlined),
                  label: const Text("Gelen İstekleri Kaydır"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListPage()),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Sohbetler"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateEncounterPage(),
                      ),
                    );
                  },
                  style: mainButtonStyle(),
                  child: const Text(
                    "Karşılaşma Bırak",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BrowseEncountersPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    "Yakınımdaki İtiraflara Bak",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  "Tam konum paylaşılmaz. Yakınlık sadece listeleme için kullanılır.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.softText.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final formKey = GlobalKey<FormState>();
  final ImagePicker imagePicker = ImagePicker();
  final AccountDeletionService accountDeletionService =
      AccountDeletionService();
  final usernameController = TextEditingController();
  final nameController = TextEditingController();
  final birthDateController = TextEditingController();
  final genderController = TextEditingController();
  final bioController = TextEditingController();
  final List<LocalProfilePhoto> newPhotos = [];
  final List<String> photoUrls = [];

  bool isLoading = true;
  bool isSaving = false;
  bool isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    usernameController.dispose();
    nameController.dispose();
    birthDateController.dispose();
    genderController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    if (photoUrls.length + newPhotos.length >= 3) {
      showMessage("En fazla 3 fotoğraf ekleyebilirsin.");
      return;
    }

    try {
      final croppedPhoto = await pickAndCropProfilePhoto(
        context: context,
        imagePicker: imagePicker,
      );

      if (croppedPhoto == null || !mounted) {
        return;
      }

      setState(() {
        newPhotos.add(croppedPhoto);
      });
    } on TimeoutException {
      showMessage("Fotoğraf hazırlanırken çok uzun sürdü. Tekrar dene.");
    } catch (e) {
      showMessage("Fotoğraf seçilemedi: $e");
    }
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    // Ekran acilinca Firestore'daki profil bilgisini forma dolduruyoruz.
    final profile = await loadUserProfile(user);

    if (!mounted) {
      return;
    }

    usernameController.text = profile.username;
    nameController.text = profile.name;
    birthDateController.text = profile.birthDate == null
        ? ""
        : formatBirthDate(profile.birthDate!);
    genderController.text = profile.gender ?? "";
    bioController.text = profile.bio;
    photoUrls
      ..clear()
      ..addAll(profile.photoUrls);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Oturum bulunamadı. Tekrar giriş yap.");
      return;
    }

    if (photoUrls.isEmpty && newPhotos.isEmpty) {
      showMessage("En az 1 profil fotoğrafı bulunmalı.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      unawaited(
        // Auth profilindeki gorunen adi da guncelliyoruz ama asil kaynak Firestore.
        user
            .updateDisplayName(nameController.text.trim())
            .timeout(profileSaveTimeout)
            .catchError((_) {}),
      );
      final uploadedUrls = await prepareProfilePhotoSources(photos: newPhotos);
      final updatedPhotoUrls = [...photoUrls, ...uploadedUrls];

      // merge:true sadece verdigimiz alanlari degistirir, eski alanlari silmez.
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
            "uid": user.uid,
            "name": nameController.text.trim(),
            "displayName": nameController.text.trim(),
            "bio": bioController.text.trim(),
            "photoUrls": updatedPhotoUrls,
            "email": user.email,
            "updatedAt": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(profileSaveTimeout);

      if (!mounted) {
        return;
      }

      photoUrls
        ..clear()
        ..addAll(updatedPhotoUrls);
      newPhotos.clear();

      showMessage("Profil güncellendi.");
    } on TimeoutException {
      showMessage(
        "Profil kaydı çok uzun sürdü. İnternetini kontrol edip tekrar dene.",
      );
    } catch (e) {
      showMessage("Profil güncellenirken hata oluştu: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<String?> askDeletionPassword() async {
    final passwordController = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text("Sifreyi dogrula"),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            style: TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: "Hesap sifren"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgec"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, passwordController.text.trim()),
              child: const Text("Dogrula"),
            ),
          ],
        );
      },
    );

    passwordController.dispose();
    return password;
  }

  Future<void> deleteAccount() async {
    // Hesap silme geri alinmaz. Bu yuzden once onay, sonra sifre istiyoruz.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text("Hesabi kalici olarak sil"),
          content: const Text(
            "Profilin, ilanlarin, isteklerin ve gonderdigin sohbet mesajlari silinir. Guvenlik ve yasal yukumlulukler icin gerekli bazi rapor kayitlari saklanabilir.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgec"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Hesabi Sil"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final password = await askDeletionPassword();

    if (password == null || password.isEmpty) {
      return;
    }

    setState(() {
      isDeletingAccount = true;
    });

    try {
      // Firebase guvenlik icin "bu kisi gercekten hesabinin sahibi mi" diye tekrar sifre ister.
      await accountDeletionService.reauthenticateWithPassword(password);
      // Sifre dogruysa uygulamadaki ilgili verileri ve son olarak Auth hesabini sileriz.
      await accountDeletionService.deleteCurrentAccount();

      if (!mounted) {
        return;
      }

      showMessage("Hesabin silindi.");
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == "wrong-password" || e.code == "invalid-credential") {
        showMessage("Sifre hatali. Tekrar dene.");
      } else if (e.code == "requires-recent-login") {
        showMessage("Guvenlik icin tekrar giris yapip yeniden dene.");
      } else {
        showMessage(friendlyAuthError(e));
      }
    } catch (e) {
      showMessage("Hesap silinemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          isDeletingAccount = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text("Profilim"),
        actions: [
          IconButton(
            tooltip: "Ayarlar",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: usernameController,
                        readOnly: true,
                        style: TextStyle(color: AppColors.softText),
                        decoration: baseInputDecoration(
                          label: "Kullanıcı adı",
                          hint: "",
                          icon: Icons.alternate_email,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: nameController,
                        label: "Görünecek isim",
                        hint: "Profil adın",
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return "Ad çok kısa";
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: birthDateController,
                        readOnly: true,
                        style: TextStyle(color: AppColors.softText),
                        decoration: baseInputDecoration(
                          label: "Doğum tarihi",
                          hint: "",
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: genderController,
                        readOnly: true,
                        style: TextStyle(color: AppColors.softText),
                        decoration: baseInputDecoration(
                          label: "Cinsiyet",
                          hint: "",
                          icon: Icons.wc_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: bioController,
                        label: "Biografi",
                        hint: "Kendini birkaç cümleyle anlat",
                        icon: Icons.badge_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      ProfilePhotoPicker(
                        localPhotos: newPhotos,
                        photoUrls: photoUrls,
                        enabled: !isSaving,
                        onAddPhoto: pickPhoto,
                        onRemoveLocalPhoto: (index) {
                          setState(() {
                            newPhotos.removeAt(index);
                          });
                        },
                        onRemoveRemotePhoto: (index) {
                          setState(() {
                            photoUrls.removeAt(index);
                          });
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isSaving || isDeletingAccount
                              ? null
                              : saveProfile,
                          style: mainButtonStyle(),
                          child: isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Profili Kaydet",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: isSaving || isDeletingAccount
                              ? null
                              : deleteAccount,
                          icon: isDeletingAccount
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.danger,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          label: const Text("Hesabi Sil"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.45),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class MyEncountersPage extends StatelessWidget {
  const MyEncountersPage({super.key});

  String formatCreatedAt(Timestamp? timestamp) {
    if (timestamp == null) {
      return "Az önce";
    }

    final diff = DateTime.now().difference(timestamp.toDate());

    if (diff.inMinutes < 1) {
      return "Az önce";
    }

    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} dk önce";
    }

    if (diff.inHours < 24) {
      return "${diff.inHours} saat önce";
    }

    return "${diff.inDays} gün önce";
  }

  Widget buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader(BuildContext context, int count) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      color: AppColors.card.withValues(alpha: 0.88),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(Icons.auto_stories_outlined, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "İtiraflarım",
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  count == 0
                      ? "Henüz bıraktığın bir karşılaşma yok."
                      : "$count aktif itirafını buradan takip edebilirsin.",
                  style: TextStyle(
                    color: AppColors.softText,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    return GlassPanel(
      radius: 26,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.secondary, AppColors.accent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(Icons.edit_note, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            "İlk itirafını bırak",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Kaçırdığın anı kısa ve güvenli bir not gibi yaz. Burada daha sonra gelen ilgileri takip edebilirsin.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.softText,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateEncounterPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text("Yeni İtiraf Bırak"),
              style: mainButtonStyle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDetailLine({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? AppColors.secondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEncounterCard(BuildContext context, EncounterPost post) {
    final quote = post.note.trim().isNotEmpty
        ? post.note.trim()
        : post.description.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardSolid,
            AppColors.backgroundSoft,
            AppColors.violetDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      "${post.dateTimeText} · ${formatCreatedAt(post.createdAt)}",
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              buildChip(
                icon: Icons.favorite_border,
                label: "${post.requestCount}",
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildChip(
                icon: post.isAnonymous
                    ? Icons.visibility_off_outlined
                    : Icons.badge_outlined,
                label: post.isAnonymous ? "Anonim" : "Açık kimlik",
                color: const Color(0xFFF5B5CE),
              ),
              if (post.personAppearance.trim().isNotEmpty)
                buildChip(
                  icon: Icons.palette_outlined,
                  label: post.personAppearance,
                  color: AppColors.secondary,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '"$quote"',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                height: 1.42,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (post.note.trim().isNotEmpty)
            buildDetailLine(
              icon: Icons.person_search_outlined,
              text: post.description,
            ),
          buildDetailLine(icon: Icons.badge_outlined, text: post.personTraits),
          buildDetailLine(
            icon: Icons.directions_car_outlined,
            text: post.vehiclePlate,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IncomingRequestsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.style_outlined),
                  label: Text(
                    post.requestCount > 0 ? "İstekleri Gör" : "İstek Yok",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: post.requestCount > 0
                        ? AppColors.accent
                        : AppColors.softText,
                    side: BorderSide(
                      color: post.requestCount > 0
                          ? AppColors.accent.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text("İtiraflarım"),
        actions: [
          IconButton(
            tooltip: "Yeni itiraf",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateEncounterPage()),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: user == null
              ? Center(
                  child: Text(
                    "Önce giriş yapmalısın.",
                    style: TextStyle(color: AppColors.softText),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection("encounters")
                      .where("ownerId", isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            "İtirafların yüklenirken hata oluştu:\n${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.softText,
                              height: 1.45,
                            ),
                          ),
                        ),
                      );
                    }

                    final posts =
                        (snapshot.data?.docs ?? [])
                            .map(EncounterPost.fromDoc)
                            .toList()
                          ..sort((a, b) {
                            final aDate =
                                a.createdAt?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            final bDate =
                                b.createdAt?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            return bDate.compareTo(aDate);
                          });

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: posts.length + 2,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return buildHeader(context, posts.length);
                        }

                        if (posts.isEmpty) {
                          return buildEmptyState(context);
                        }

                        if (index == 1) {
                          return Row(
                            children: [
                              Text(
                                "Son paylaşımlar",
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              buildChip(
                                icon: Icons.lock_outline,
                                label: "Gizli takip",
                                color: const Color(0xFFF5B5CE),
                              ),
                            ],
                          );
                        }

                        return buildEncounterCard(context, posts[index - 2]);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class IncomingRequestsPage extends StatelessWidget {
  const IncomingRequestsPage({super.key});

  Future<void> decideRequest({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> requestDoc,
    required bool accepted,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(context, "Oturum bulunamadı.");
      return;
    }

    final data = requestDoc.data();
    final requesterId = (data["interestedUserId"] ?? "").toString();

    if (requesterId.isEmpty) {
      showMessage(context, "İstek bilgisi eksik.");
      return;
    }

    if (!accepted) {
      // Sola atma/reddetme: istegi silmiyoruz, durumunu rejected yapiyoruz.
      // Boylece ileride "bu istek ne oldu" sorusunun cevabi veride kalir.
      await requestDoc.reference.update({
        "status": "rejected",
        "decidedAt": FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      showMessage(context, "İstek reddedildi.");
      return;
    }

    final ownerProfile = await loadUserProfile(user);
    // Iki kullanici icin hep ayni chatId uretilir. Siralama bu yuzden onemli.
    final chatId = buildChatId(user.uid, requesterId);
    final chatOpenedAt = DateTime.now();
    final requesterName =
        (data["requesterName"] ?? data["interestedUserName"] ?? "Kullanıcı")
            .toString();

    // Kabul edilince sohbet belgesi acilir. Bundan sonra iki kisi mesajlasabilir.
    await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
      "chatId": chatId,
      "postId": data["postId"],
      "requestId": requestDoc.id,
      "participants": [user.uid, requesterId],
      "participantNames": {
        user.uid: ownerProfile.name,
        requesterId: requesterName,
      },
      "blockedBy": [],
      "unreadCounts": {user.uid: 0, requesterId: 0},
      // Ilk dakikalarda fotograf gondermeyi kilitleyerek kotuye kullanimi azaltiriz.
      "photoUnlockAt": Timestamp.fromDate(
        chatOpenedAt.add(chatPhotoLockDuration),
      ),
      "mediaPolicy": PremiumAccess.defaultChatPolicy(),
      "premiumContext": {
        "futurePaidPerksReady": true,
        "createdWithTier": PremiumAccess.freeTier,
      },
      "createdAt": FieldValue.serverTimestamp(),
      "lastMessage": "Sohbet açıldı.",
      "lastMessageAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Istege de "artik kabul edildi ve chat su" bilgisini yaziyoruz.
    await requestDoc.reference.update({
      "status": "accepted",
      "chatId": chatId,
      "decidedAt": FieldValue.serverTimestamp(),
    });

    if (!context.mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          otherUserId: requesterId,
          otherUserName: requesterName,
        ),
      ),
    );
  }

  void showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildRequestGuide() {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swipe_outlined, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                "İstek nasıl çalışır?",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            "1. Birisi itirafını sağa kaydırır.\n2. Burada sana kart olarak düşer.\n3. Sağa kaydırırsan kabul, sola kaydırırsan red.\n4. Kabul edersen sohbet otomatik açılır.",
            style: TextStyle(
              color: AppColors.softText,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRequestCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name =
        (data["requesterName"] ?? data["interestedUserName"] ?? "Kullanıcı")
            .toString();
    final age = data["requesterAge"];
    final bio = data["requesterBio"] ?? "Biografi henüz eklenmemiş.";

    return Dismissible(
      key: ValueKey(doc.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: Colors.green.withValues(alpha: 0.35),
        child: const Icon(Icons.check, color: Colors.white, size: 34),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.redAccent.withValues(alpha: 0.35),
        child: const Icon(Icons.close, color: Colors.white, size: 34),
      ),
      confirmDismiss: (direction) async {
        await decideRequest(
          context: context,
          requestDoc: doc,
          accepted: direction == DismissDirection.startToEnd,
        );
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    age is int ? "$name, $age" : name,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              bio,
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "İlgilendiği itiraf: ${data["postPlace"] ?? "Karşılaşma"}",
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => decideRequest(
                      context: context,
                      requestDoc: doc,
                      accepted: false,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text("Sola"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => decideRequest(
                      context: context,
                      requestDoc: doc,
                      accepted: true,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text("Sağa"),
                    style: mainButtonStyle(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text("Gelen İstekler"),
      ),
      body: user == null
          ? Center(
              child: Text(
                "Önce giriş yapmalısın.",
                style: TextStyle(color: AppColors.softText),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("interest_requests")
                  .where("postOwnerId", isEqualTo: user.uid)
                  .where("status", isEqualTo: "pending")
                  .limit(incomingRequestPageSize)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      buildRequestGuide(),
                      const SizedBox(height: 28),
                      Text(
                        "Henüz gelen istek yok.\nBirisi itirafını sağa kaydırdığında burada kart olarak görünecek.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.softText,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return buildRequestGuide();
                    }

                    return buildRequestCard(context, docs[index - 1]);
                  },
                );
              },
            ),
    );
  }
}

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text("Sohbetler"),
      ),
      body: user == null
          ? Center(
              child: Text(
                "Önce giriş yapmalısın.",
                style: TextStyle(color: AppColors.softText),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .where("participants", arrayContains: user.uid)
                  .limit(chatListPageSize)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "Henüz sohbet yok.",
                      style: TextStyle(color: AppColors.softText),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final participants = List<String>.from(
                      data["participants"] ?? [],
                    );
                    final otherId = participants.firstWhere(
                      (id) => id != user.uid,
                      orElse: () => "",
                    );
                    final names = Map<String, dynamic>.from(
                      data["participantNames"] ?? {},
                    );
                    final otherName = (names[otherId] ?? "Kullanıcı")
                        .toString();

                    return ListTile(
                      tileColor: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.chat_bubble_outline),
                      ),
                      title: Text(
                        otherName,
                        style: TextStyle(color: AppColors.text),
                      ),
                      subtitle: Text(
                        (data["lastMessage"] ?? "Sohbet açıldı.").toString(),
                        style: TextStyle(color: AppColors.softText),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: docs[index].id,
                              otherUserId: otherId,
                              otherUserName: otherName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class PhotoLockCountdown extends StatefulWidget {
  final DateTime unlockAt;
  final VoidCallback onDone;

  const PhotoLockCountdown({
    super.key,
    required this.unlockAt,
    required this.onDone,
  });

  @override
  State<PhotoLockCountdown> createState() => _PhotoLockCountdownState();
}

class _PhotoLockCountdownState extends State<PhotoLockCountdown> {
  late Timer timer;

  Duration get remaining {
    final diff = widget.unlockAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      if (remaining == Duration.zero) {
        timer.cancel();
        widget.onDone();
      }

      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PhotoLockCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.unlockAt != widget.unlockAt && !timer.isActive) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }

        if (remaining == Duration.zero) {
          timer.cancel();
          widget.onDone();
        }

        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "${remaining.inSeconds} sn",
      style: TextStyle(
        color: AppColors.softText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChatPageState extends State<ChatPage> {
  final messageController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  late final DocumentReference<Map<String, dynamic>> chatRef;
  late final CollectionReference<Map<String, dynamic>> messagesRef;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> chatStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream;
  Timer? recordingTimer;
  bool isSending = false;
  bool isRecordingVoice = false;
  int recordingSeconds = 0;
  String? lastAutoReadMessageId;

  @override
  void initState() {
    super.initState();
    chatRef = FirebaseFirestore.instance.collection("chats").doc(widget.chatId);
    messagesRef = chatRef.collection("messages");
    chatStream = chatRef.snapshots();
    messagesStream = messagesRef
        .orderBy("createdAt", descending: true)
        .limit(chatMessagePageSize)
        .snapshots();
    unawaited(markChatRead());
  }

  void startRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !isRecordingVoice) {
        return;
      }

      setState(() {
        recordingSeconds++;
      });

      if (recordingSeconds >= voiceRecordingMaxDuration.inSeconds) {
        // Ses kaydi cok uzamasin diye sure dolunca otomatik durduruyoruz.
        recordingTimer?.cancel();
        recordingTimer = null;
        unawaited(stopVoiceRecording());
      }
    });
  }

  @override
  void dispose() {
    recordingTimer?.cancel();
    if (isRecordingVoice) {
      unawaited(stopVoiceRecording(sendAfterStop: false));
    }
    messageController.dispose();
    super.dispose();
  }

  DateTime? photoUnlockDate(Map<String, dynamic> chatData) {
    // Yeni sohbetlerde kilit zamani photoUnlockAt alaninda tutulur.
    // Eski kayitlarda bu alan yoksa createdAt + sure hesabina geri duseriz.
    final unlockData = chatData["photoUnlockAt"];

    if (unlockData is Timestamp) {
      return unlockData.toDate();
    }

    final createdData = chatData["createdAt"];

    if (createdData is Timestamp) {
      return createdData.toDate().add(chatPhotoLockDuration);
    }

    return null;
  }

  Duration photoLockRemaining(Map<String, dynamic> chatData) {
    final unlockAt = photoUnlockDate(chatData);

    if (unlockAt == null) {
      return Duration.zero;
    }

    final remaining = unlockAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool canSendPhotos(Map<String, dynamic> chatData) {
    return photoLockRemaining(chatData) == Duration.zero;
  }

  Future<void> markChatRead() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    await chatRef
        .set({"unreadCounts.${user.uid}": 0}, SetOptions(merge: true))
        .catchError((_) {});
  }

  String lastMessagePreview(String type, String fallback) {
    switch (type) {
      case "image":
        return "Fotoğraf gönderildi.";
      case "voice":
        return "Ses kaydı gönderildi.";
      default:
        return fallback;
    }
  }

  Future<void> updateChatPreview(String lastMessage, User sender) {
    // Chat listesindeki son mesaj yazisi buradan guncellenir.
    return chatRef.set({
      "lastMessage": lastMessage,
      "lastMessageAt": FieldValue.serverTimestamp(),
      "lastSenderId": sender.uid,
      "unreadCounts.${sender.uid}": 0,
      "unreadCounts.${widget.otherUserId}": FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage(Map<String, dynamic> chatData) async {
    final user = FirebaseAuth.instance.currentUser;
    final text = messageController.text.trim();

    if (user == null || text.isEmpty) {
      return;
    }

    final blockedBy = List<String>.from(chatData["blockedBy"] ?? []);

    if (blockedBy.isNotEmpty) {
      // Biri engellediyse sohbet artik yazmaya kapali kabul ediliyor.
      showMessage("Bu sohbet engellendiği için mesaj gönderilemez.");
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      // Mesajlar chat belgesinin alt koleksiyonuna yazilir.
      // Boylece sohbet bilgisi ve mesajlar ayri ama bagli kalir.
      await messagesRef.add({
        "senderId": user.uid,
        "text": text,
        "type": "text",
        "createdAt": FieldValue.serverTimestamp(),
      });

      await updateChatPreview(text, user);

      if (!mounted) {
        return;
      }

      messageController.clear();
    } catch (e) {
      showMessage("Mesaj gönderilemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> sendPhotoMessage(Map<String, dynamic> chatData) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final blockedBy = List<String>.from(chatData["blockedBy"] ?? []);

    if (blockedBy.isNotEmpty) {
      showMessage("Bu sohbet engellendiği için fotoğraf gönderilemez.");
      return;
    }

    if (!canSendPhotos(chatData)) {
      // Fotograflar hemen acilmasin; once sohbet biraz "isinmis" olsun.
      showMessage("Fotoğraf göndermek için sayaç bitmeli.");
      return;
    }

    try {
      final photo = await pickAndCropProfilePhoto(
        context: context,
        imagePicker: imagePicker,
      );

      if (photo == null || !mounted) {
        return;
      }

      setState(() {
        isSending = true;
      });

      final photoSources = await prepareProfilePhotoSources(photos: [photo]);

      // Foto da mesaj gibi yazilir; farki type=image ve imageSource alanidir.
      await messagesRef.add({
        "senderId": user.uid,
        "type": "image",
        "imageSource": photoSources.single,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await updateChatPreview(lastMessagePreview("image", ""), user);
    } on TimeoutException {
      showMessage("Fotoğraf hazırlanırken çok uzun sürdü. Tekrar dene.");
    } catch (e) {
      showMessage("Fotoğraf gönderilemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> toggleVoiceRecording() async {
    if (isRecordingVoice) {
      await stopVoiceRecording();
      return;
    }

    await startVoiceRecording();
  }

  Future<void> startVoiceRecording() async {
    try {
      // Ses kaydi native tarafta baslar. Flutter burada sadece komut gonderir.
      await appMediaChannel.invokeMethod<void>("startVoiceRecording");

      if (!mounted) {
        return;
      }

      setState(() {
        isRecordingVoice = true;
        recordingSeconds = 0;
      });
      startRecordingTimer();
    } on MissingPluginException {
      showMessage("Ses kaydı bu cihazda desteklenmiyor.");
    } on PlatformException catch (e) {
      showMessage(e.message ?? "Ses kaydı başlatılamadı.");
    } catch (e) {
      showMessage("Ses kaydı başlatılamadı: $e");
    }
  }

  Future<void> stopVoiceRecording({bool sendAfterStop = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    final durationSeconds = recordingSeconds
        .clamp(1, voiceRecordingMaxDuration.inSeconds)
        .toInt();

    try {
      recordingTimer?.cancel();
      recordingTimer = null;
      // Native taraf kaydi durdurur ve bize base64/dataUrl olarak geri verir.
      final dataUrl = await appMediaChannel.invokeMethod<String>(
        "stopVoiceRecording",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isRecordingVoice = false;
        recordingSeconds = 0;
      });

      if (!sendAfterStop || user == null || dataUrl == null) {
        // Ekrandan cikarken durduruyorsak mesaj olarak gondermeyebiliriz.
        return;
      }

      // Ses de normal mesajdir; sadece tipi voice ve audioSource alani vardir.
      await messagesRef.add({
        "senderId": user.uid,
        "type": "voice",
        "audioSource": dataUrl,
        "durationSeconds": durationSeconds,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await updateChatPreview(lastMessagePreview("voice", ""), user);
    } on MissingPluginException {
      showMessage("Ses kaydı bu cihazda desteklenmiyor.");
    } on PlatformException catch (e) {
      showMessage(e.message ?? "Ses kaydı gönderilemedi.");
    } catch (e) {
      showMessage("Ses kaydı gönderilemedi: $e");
    } finally {
      recordingTimer?.cancel();
      recordingTimer = null;
      if (mounted) {
        setState(() {
          isRecordingVoice = false;
          recordingSeconds = 0;
        });
      }
    }
  }

  Future<void> playVoiceMessage(String dataUrl) async {
    try {
      await appMediaChannel.invokeMethod<void>("playVoiceData", {
        "dataUrl": dataUrl,
      });
    } on MissingPluginException {
      showMessage("Ses oynatma bu cihazda desteklenmiyor.");
    } on PlatformException catch (e) {
      showMessage(e.message ?? "Ses kaydı oynatılamadı.");
    } catch (e) {
      showMessage("Ses kaydı oynatılamadı: $e");
    }
  }

  Future<void> blockUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    // Engeli hem chat belgesine hem de blocks koleksiyonuna yaziyoruz.
    // Chat belgesi mesaj atmayi keser, blocks koleksiyonu listelerde filtreleme yapar.
    await chatRef.set({
      "blockedBy": FieldValue.arrayUnion([user.uid]),
      "blockedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection("blocks")
        .doc("${user.uid}_${widget.otherUserId}")
        .set({
          "blockerId": user.uid,
          "blockedUserId": widget.otherUserId,
          "chatId": widget.chatId,
          "createdAt": FieldValue.serverTimestamp(),
        });

    if (!mounted) {
      return;
    }

    showMessage("Kullanıcı engellendi.");
  }

  Future<void> reportUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final reasonController = TextEditingController();

    if (user == null) {
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text("Raporla"),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "Kısa bir sebep yaz"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, reasonController.text.trim()),
              child: const Text("Gönder"),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (!mounted || reason == null || reason.isEmpty) {
      return;
    }

    // Raporlar kullanicinin ekraninda gorunmez; moderasyon/inceleme icin Firestore'a gider.
    await FirebaseFirestore.instance.collection("reports").add({
      "reporterId": user.uid,
      "reportedUserId": widget.otherUserId,
      "chatId": widget.chatId,
      "reason": reason,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) {
      return;
    }

    showMessage("Rapor gönderildi.");
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildChatRulesBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: GlassPanel(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  color: AppColors.accent,
                ),
                SizedBox(width: 8),
                Text(
                  "Sohbet adımları",
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "1. Sohbet sadece iki taraf onaylayınca açılır.\n2. Önce mesajla tanış, acele özel bilgi isteme.\n3. Fotoğraf kilidi bitince fotoğraf gönderebilirsin.\n4. Rahatsız hissedersen raporla ya da engelle.",
              style: TextStyle(
                color: AppColors.softText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildChatLogoBackground() {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: 0.07,
          child: Transform.scale(scale: 2.4, child: appLogo()),
        ),
      ),
    );
  }

  Widget buildMessageBubble(Map<String, dynamic> data, bool isMine) {
    final type = (data["type"] ?? "text").toString();
    Widget child;

    if (type == "image") {
      final source = (data["imageSource"] ?? "").toString();
      child = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 190,
          height: 190,
          child: source.isEmpty
              ? const _PhotoTileMessage(
                  icon: Icons.broken_image_outlined,
                  text: "Fotoğraf yok",
                )
              : buildSavedProfilePhotoImage(source),
        ),
      );
    } else if (type == "voice") {
      final dataUrl = (data["audioSource"] ?? "").toString();
      final duration = data["durationSeconds"];
      child = OutlinedButton.icon(
        onPressed: dataUrl.isEmpty ? null : () => playVoiceMessage(dataUrl),
        icon: const Icon(Icons.play_arrow),
        label: Text(duration is int ? "Ses kaydı ${duration}s" : "Ses kaydı"),
        style: OutlinedButton.styleFrom(
          foregroundColor: isMine ? Colors.white : AppColors.accent,
          side: BorderSide(
            color: isMine
                ? Colors.white.withValues(alpha: 0.55)
                : AppColors.accent.withValues(alpha: 0.5),
          ),
        ),
      );
    } else {
      child = Text(
        (data["text"] ?? "").toString(),
        style: TextStyle(
          color: isMine ? Colors.white : AppColors.text,
          height: 1.35,
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(type == "image" ? 5 : 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }

  Widget buildComposer(Map<String, dynamic> chatData) {
    final blockedBy = List<String>.from(chatData["blockedBy"] ?? []);
    final isBlocked = blockedBy.isNotEmpty;
    final remaining = photoLockRemaining(chatData);
    final unlockAt = photoUnlockDate(chatData);
    final photosUnlocked = remaining == Duration.zero;
    final canInteract = !isBlocked && !isSending;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              enabled: !isBlocked && !isRecordingVoice,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: isBlocked
                    ? "Bu sohbet engellendi"
                    : isRecordingVoice
                    ? "Ses kaydı alınıyor..."
                    : "Mesaj yaz",
                hintStyle: TextStyle(color: AppColors.softText),
                filled: true,
                fillColor: AppColors.backgroundSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!photosUnlocked && unlockAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: PhotoLockCountdown(
                unlockAt: unlockAt,
                onDone: () {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
          if (!photosUnlocked && unlockAt == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                "0 sn",
                style: TextStyle(
                  color: AppColors.softText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            tooltip: photosUnlocked
                ? "Fotoğraf gönder"
                : "Fotoğraf kilidi: ${remaining.inSeconds} sn",
            onPressed: canInteract && photosUnlocked
                ? () => sendPhotoMessage(chatData)
                : null,
            icon: Icon(
              photosUnlocked ? Icons.photo_camera_outlined : Icons.lock_clock,
            ),
            color: photosUnlocked ? AppColors.secondary : AppColors.softText,
          ),
          IconButton(
            tooltip: isRecordingVoice ? "Ses kaydını gönder" : "Ses kaydı",
            onPressed: isBlocked ? null : toggleVoiceRecording,
            icon: Icon(isRecordingVoice ? Icons.stop_circle : Icons.mic),
            color: isRecordingVoice ? AppColors.danger : AppColors.accent,
          ),
          if (isRecordingVoice)
            Text(
              "${recordingSeconds}s",
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          IconButton(
            onPressed: isSending || isBlocked || isRecordingVoice
                ? null
                : () => sendMessage(chatData),
            icon: const Icon(Icons.send),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chatStream,
      builder: (context, chatSnapshot) {
        final chatData = chatSnapshot.data?.data() ?? {};

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.text,
            title: Text(widget.otherUserName),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "report") {
                    reportUser();
                  }

                  if (value == "block") {
                    blockUser();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: "report", child: Text("Raporla")),
                  PopupMenuItem(value: "block", child: Text("Engelle")),
                ],
              ),
            ],
          ),
          body: user == null
              ? Center(
                  child: Text(
                    "Önce giriş yapmalısın.",
                    style: TextStyle(color: AppColors.softText),
                  ),
                )
              : Column(
                  children: [
                    buildChatRulesBanner(),
                    Expanded(
                      child: Stack(
                        children: [
                          buildChatLogoBackground(),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: messagesStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];

                              if (docs.isNotEmpty) {
                                final latestDoc = docs.first;
                                final latestData = latestDoc.data();

                                if (latestDoc.id != lastAutoReadMessageId &&
                                    latestData["senderId"] != user.uid) {
                                  lastAutoReadMessageId = latestDoc.id;
                                  unawaited(markChatRead());
                                }
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                reverse: true,
                                cacheExtent: 420,
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data = docs[index].data();
                                  final isMine = data["senderId"] == user.uid;
                                  return buildMessageBubble(data, isMine);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    buildComposer(chatData),
                  ],
                ),
        );
      },
    );
  }
}

class CreateEncounterPage extends StatefulWidget {
  const CreateEncounterPage({super.key});

  @override
  State<CreateEncounterPage> createState() => _CreateEncounterPageState();
}

class _CreateEncounterPageState extends State<CreateEncounterPage> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController placeController = TextEditingController();
  final TextEditingController dateTimeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController vehiclePlateController = TextEditingController();
  final TextEditingController personTraitsController = TextEditingController();

  bool isSaving = false;
  bool isAnonymous = false;
  String? selectedPersonAppearance;

  static const List<String> personAppearanceOptions = [
    "Esmer",
    "Sarışın",
    "Kumral",
    "Kızıl",
    "Buğday tenli",
    "Açık tenli",
    "Hatırlamıyorum",
  ];

  @override
  void dispose() {
    placeController.dispose();
    dateTimeController.dispose();
    descriptionController.dispose();
    noteController.dispose();
    vehiclePlateController.dispose();
    personTraitsController.dispose();
    super.dispose();
  }

  Future<void> saveEncounter() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Oturum bulunamadı. Tekrar giriş yap.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // Ilan yayinlanirken kullanicinin o anki konumunu aliyoruz.
      // Bu konum, ilani sadece yakindaki kisilere gostermek icin kullaniliyor.
      final position = await getCurrentPositionSafely();

      if (!isLocationInAnkara(
        latitude: position.latitude,
        longitude: position.longitude,
      )) {
        showMessage(
          "Pilot bölge şimdilik Ankara. Ankara dışından itiraf bırakılamıyor.",
        );
        return;
      }

      if (!mounted) {
        return;
      }

      final ownerProfile = await loadUserProfile(user);
      final ownerName = isAnonymous ? "Anonim" : ownerProfile.name;

      await FirebaseFirestore.instance.collection("encounters").add({
        // Bu belge "karsilasma ilani"nin Firestore'daki kaydidir.
        "place": placeController.text.trim(),
        "dateTimeText": dateTimeController.text.trim(),
        "description": descriptionController.text.trim(),
        "note": noteController.text.trim(),
        "vehiclePlate": vehiclePlateController.text.trim(),
        "personAppearance": selectedPersonAppearance ?? "",
        "personTraits": personTraitsController.text.trim(),
        "requestCount": 0,
        "ownerId": user.uid,
        "ownerName": ownerName,
        // Anonim degilse ilan kartinda profil bilgisi gosterebilmek icin
        // kullanicinin adini, yasini ve fotografini ilanla beraber kaydediyoruz.
        if (!isAnonymous) "ownerEmail": user.email,
        if (!isAnonymous) "ownerAge": ownerProfile.age,
        if (!isAnonymous) "ownerPhotoUrls": ownerProfile.photoUrls,
        "isAnonymous": isAnonymous,
        // GeoPoint mesafe hesabi icin kullaniliyor; latitude/longitude da pratik okuma icin duruyor.
        "location": GeoPoint(position.latitude, position.longitude),
        "latitude": position.latitude,
        "longitude": position.longitude,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      showMessage("Karşılaşma ilanı oluşturuldu.");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BrowseEncountersPage()),
      );
    } catch (e) {
      showMessage(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text("İtiraf Bırak"),
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Nerede ve ne zaman gördün?",
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Tam adres verme. AVM, cadde, kafe veya genel bölge yazman yeterli. Konum sadece yakın kişilere göstermek için alınır.",
                    style: TextStyle(
                      color: AppColors.softText,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppTextField(
                    controller: placeController,
                    label: "Yer",
                    hint: "Örn: Ankara / Kızılay, bir kahveci",
                    icon: Icons.location_on_outlined,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: dateTimeController,
                    label: "Zaman",
                    hint: "Örn: Bugün 18:30 civarı",
                    icon: Icons.access_time,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: descriptionController,
                    label: "Kişiyi nasıl hatırlıyorsun?",
                    hint: "Örn: Mavi montlu, siyah çantalıydı.",
                    icon: Icons.person_search_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPersonAppearance,
                    dropdownColor: AppColors.cardSolid,
                    decoration: baseInputDecoration(
                      label: "Görünüm",
                      hint: "Ten/saç tonu seç",
                      icon: Icons.palette_outlined,
                    ),
                    items: personAppearanceOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setState(() {
                              selectedPersonAppearance = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: personTraitsController,
                    label: "Ayırt edici özellikler",
                    hint: "Örn: Gözlük, sakal, yeşil çanta, uzun boy",
                    icon: Icons.badge_outlined,
                    maxLines: 2,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: vehiclePlateController,
                    label: "Araç plakası (opsiyonel)",
                    hint: "Örn: 34 ABC 123",
                    icon: Icons.directions_car_outlined,
                    maxLines: 1,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: noteController,
                    label: "Kısa not",
                    hint: "Örn: Göz göze geldik ama konuşamadım.",
                    icon: Icons.edit_note,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  IdentitySegmentedControl(
                    isAnonymous: isAnonymous,
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setState(() {
                              isAnonymous = value;
                            });
                          },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveEncounter,
                      style: mainButtonStyle(),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "İlanı Yayınla",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Güvenlik için telefon, açık adres, okul sınıfı veya özel bilgi paylaşma.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.softText.withValues(alpha: 0.78),
                      fontSize: 12,
                      height: 1.4,
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

class BrowseEncountersPage extends StatefulWidget {
  const BrowseEncountersPage({super.key});

  @override
  State<BrowseEncountersPage> createState() => _BrowseEncountersPageState();
}

class _BrowseEncountersPageState extends State<BrowseEncountersPage> {
  late Future<Position> positionFuture;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> encountersStream;
  double radiusKm = 5;
  Set<String> blockedUserIds = {};
  Set<String> dismissedPostIds = {};
  bool isLoadingDismissedPosts = true;

  @override
  void initState() {
    super.initState();
    positionFuture = getCurrentPositionSafely();
    encountersStream = FirebaseFirestore.instance
        .collection("encounters")
        .orderBy("createdAt", descending: true)
        .limit(encounterFeedPageSize)
        .snapshots();
    unawaited(loadBlockedUsers());
    unawaited(loadDismissedPosts());
  }

  void refreshLocation() {
    // Kullanici konumunu yenilemek isterse Future'i bastan kuruyoruz.
    setState(() {
      positionFuture = getCurrentPositionSafely();
    });
    unawaited(loadBlockedUsers());
    unawaited(loadDismissedPosts());
  }

  Future<void> loadDismissedPosts() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoadingDismissedPosts = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      final data = doc.data();
      final rawIds = data?["dismissedEncounterIds"];

      if (!mounted) {
        return;
      }

      setState(() {
        dismissedPostIds = rawIds is List
            ? rawIds
                  .map((id) => id.toString())
                  .where((id) => id.isNotEmpty)
                  .toSet()
            : <String>{};
        isLoadingDismissedPosts = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoadingDismissedPosts = false;
        });
      }
    }
  }

  Future<void> rememberDismissedPost(String postId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || postId.isEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "dismissedEncounterIds": FieldValue.arrayUnion([postId]),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> loadBlockedUsers() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    // Engellenen kisilerin ilanlarini listede hic gostermemek icin UID listesi cekiyoruz.
    final snapshot = await FirebaseFirestore.instance
        .collection("blocks")
        .where("blockerId", isEqualTo: user.uid)
        .get();

    if (!mounted) {
      return;
    }

    setState(() {
      blockedUserIds = snapshot.docs
          .map((doc) => (doc.data()["blockedUserId"] ?? "").toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    });
  }

  Future<String?> askReportReason(String title) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(title),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            style: TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: "Kisa bir sebep yaz"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgec"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, reasonController.text.trim()),
              child: const Text("Gonder"),
            ),
          ],
        );
      },
    );

    reasonController.dispose();
    return reason;
  }

  Future<void> reportEncounterPost(EncounterPost post) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Once giris yapmalisin.");
      return;
    }

    final reason = await askReportReason("Ilani raporla");

    if (!mounted || reason == null || reason.isEmpty) {
      return;
    }

    // Ilan raporu da normal kullanici raporu gibi reports koleksiyonuna gider.
    await FirebaseFirestore.instance.collection("reports").add({
      "type": "encounter",
      "reporterId": user.uid,
      "reportedUserId": post.ownerId,
      "postId": post.id,
      "reason": reason,
      "createdAt": FieldValue.serverTimestamp(),
    });

    showMessage("Rapor gonderildi.");
  }

  Future<void> blockEncounterOwner(EncounterPost post) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Once giris yapmalisin.");
      return;
    }

    if (post.ownerId == user.uid) {
      showMessage("Kendi ilaninin sahibini engelleyemezsin.");
      return;
    }

    // Ilan sahibini engelleyince o kisinin ilanlarini bu ekranda filtreleyecegiz.
    await FirebaseFirestore.instance
        .collection("blocks")
        .doc("${user.uid}_${post.ownerId}")
        .set({
          "blockerId": user.uid,
          "blockedUserId": post.ownerId,
          "source": "encounter",
          "postId": post.id,
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) {
      return;
    }

    setState(() {
      blockedUserIds = {...blockedUserIds, post.ownerId};
    });
    showMessage("Kullanici engellendi.");
  }

  Future<bool> sendInterest(EncounterPost post) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Önce giriş yapmalısın.");
      return false;
    }

    if (post.ownerId == user.uid) {
      showMessage("Kendi ilanına istek gönderemezsin.");
      return false;
    }

    try {
      final profile = await loadUserProfile(user);

      if (!mounted) {
        return false;
      }

      final requestId = "${post.id}_${user.uid}";
      // Bir kullanici ayni ilana birden fazla bekleyen istek atamasin diye ID sabit.
      final requestRef = FirebaseFirestore.instance
          .collection("interest_requests")
          .doc(requestId);
      final existingRequest = await requestRef.get();
      final existingStatus = existingRequest.data()?["status"];

      if (!mounted) {
        return false;
      }

      if (existingStatus == "pending") {
        // Ayni ilana ikinci kez bekleyen istek acmayalim.
        showMessage("Bu itiraf için isteğin zaten beklemede.");
        return true;
      }

      if (existingStatus == "accepted") {
        showMessage("Bu itiraf için sohbet zaten açılmış.");
        return true;
      }

      await requestRef.set({
        // Ilan sahibinin gorecegi basvuru karti burada olusur.
        "postId": post.id,
        "postPlace": post.place,
        "postOwnerId": post.ownerId,
        "interestedUserId": user.uid,
        "interestedUserEmail": user.email,
        "interestedUserName": profile.name,
        ...profile.toRequestSnapshot(),
        "status": "pending",
        "chatId": null,
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!existingRequest.exists) {
        // Ilk defa istek atiliyorsa ilanin sayacini 1 arttirmayi deneriz.
        // Sayaç ikincil bilgi; izin/eski veri sorunu istegin kendisini basarisiz gostermesin.
        unawaited(
          FirebaseFirestore.instance
              .collection("encounters")
              .doc(post.id)
              .set({
                "requestCount": FieldValue.increment(1),
              }, SetOptions(merge: true))
              .catchError((_) {}),
        );
      }

      showMessage(
        "İstek gönderildi. İlan sahibi profilini sağa kaydırırsa sohbet açılacak.",
      );
      return true;
    } catch (e) {
      showMessage("İstek gönderilirken hata oluştu: $e");
      return false;
    }
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void openDiscoverPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget buildDiscoverShortcut({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDiscoverShortcuts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            buildDiscoverShortcut(
              icon: Icons.style_outlined,
              label: "İstekler",
              color: AppColors.secondary,
              onPressed: () => openDiscoverPage(const IncomingRequestsPage()),
            ),
            const SizedBox(width: 10),
            buildDiscoverShortcut(
              icon: Icons.add_location_alt_outlined,
              label: "İtiraf Bırak",
              color: const Color(0xFF25E6C8),
              onPressed: () => openDiscoverPage(const CreateEncounterPage()),
            ),
            const SizedBox(width: 10),
            buildDiscoverShortcut(
              icon: Icons.auto_stories_outlined,
              label: "İtiraflarım",
              color: AppColors.accent,
              onPressed: () => openDiscoverPage(const MyEncountersPage()),
            ),
          ],
        ),
      ),
    );
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()} m yakınında";
    }

    return "${(meters / 1000).toStringAsFixed(1)} km yakınında";
  }

  String formatCreatedAt(Timestamp? timestamp) {
    if (timestamp == null) {
      return "Az önce";
    }

    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      return "Az önce";
    }

    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} dk önce";
    }

    if (diff.inHours < 24) {
      return "${diff.inHours} saat önce";
    }

    return "${diff.inDays} gün önce";
  }

  List<EncounterWithDistance> filterNearbyPosts({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Position currentPosition,
  }) {
    final List<EncounterWithDistance> nearbyPosts = [];
    // Secilen yaricap her yerde ayni degil: Ankara icin 50 km'ye kadar izin var.
    final effectiveRadiusKm = effectiveRadiusKmForLocation(
      requestedRadiusKm: radiusKm,
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
    );

    for (final doc in docs) {
      final post = EncounterPost.fromDoc(doc);

      if (blockedUserIds.contains(post.ownerId)) {
        // Kullanici birini engellediyse onun ilanini hic listeye sokmuyoruz.
        continue;
      }

      // Firestore tum son ilanlari getirir; gercek mesafe filtresini burada uyguluyoruz.
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        post.location.latitude,
        post.location.longitude,
      );

      if (distance <= effectiveRadiusKm * 1000) {
        nearbyPosts.add(
          EncounterWithDistance(post: post, distanceMeters: distance),
        );
      }
    }

    nearbyPosts.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // En yakindaki ilan en ustte gorunsun diye sirali liste donuyoruz.
    return nearbyPosts;
  }

  List<EncounterWithDistance> availableSwipeItems(
    List<EncounterWithDistance> nearbyPosts,
  ) {
    final user = FirebaseAuth.instance.currentUser;

    return nearbyPosts
        .where((item) => !dismissedPostIds.contains(item.post.id))
        .where((item) => item.post.ownerId != user?.uid)
        .take(swipeDeckLookaheadCount)
        .toList(growable: false);
  }

  Widget buildRadiusSelector(Position currentPosition) {
    final inAnkara = isLocationInAnkara(
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
    );
    final radiusOptions = radiusOptionsForLocation(
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
    );
    final selectedRadius = effectiveRadiusKmForLocation(
      requestedRadiusKm: radiusKm,
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
    );

    // Kullanici burada "kac km cevreyi goreyim" secimini yapar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.radar, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                inAnkara
                    ? "Gösterilecek mesafe (Ankara için en fazla 50 km)"
                    : "Gösterilecek mesafe",
                style: TextStyle(color: AppColors.softText, fontSize: 14),
              ),
            ),
            DropdownButton<double>(
              value: selectedRadius,
              dropdownColor: AppColors.cardSolid,
              underline: const SizedBox(),
              items: radiusOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text("${option.toInt()} km"),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  radiusKm = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> confirmSwipe({
    required DismissDirection direction,
    required EncounterPost post,
  }) async {
    if (direction == DismissDirection.endToStart) {
      return true;
    }

    if (direction == DismissDirection.startToEnd) {
      return sendInterest(post);
    }

    return false;
  }

  void markPostDismissed(EncounterPost post, DismissDirection direction) {
    final wasAlreadyDismissed = dismissedPostIds.contains(post.id);

    setState(() {
      dismissedPostIds = {...dismissedPostIds, post.id};
    });

    if (!wasAlreadyDismissed) {
      unawaited(rememberDismissedPost(post.id).catchError((_) {}));
    }

    if (direction == DismissDirection.endToStart) {
      showMessage("İtiraf geçildi.");
    }
  }

  Future<void> actOnEncounter({
    required EncounterPost post,
    required DismissDirection direction,
  }) async {
    final shouldDismiss = await confirmSwipe(direction: direction, post: post);

    if (!mounted || !shouldDismiss) {
      return;
    }

    markPostDismissed(post, direction);
  }

  Widget buildEncounterActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color foreground,
    bool primary = false,
  }) {
    final size = primary ? 62.0 : 48.0;

    return SizedBox.square(
      dimension: size,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: primary ? 30 : 23),
        color: foreground,
        style: IconButton.styleFrom(
          backgroundColor: primary
              ? AppColors.accent
              : AppColors.cardSolid.withValues(alpha: 0.76),
          side: BorderSide(
            color: primary
                ? AppColors.accent.withValues(alpha: 0.80)
                : AppColors.border,
          ),
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget buildEncounterActions(EncounterWithDistance item) {
    final post = item.post;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildEncounterActionButton(
                icon: Icons.close,
                foreground: AppColors.softText,
                onPressed: () => unawaited(
                  actOnEncounter(
                    post: post,
                    direction: DismissDirection.endToStart,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              buildEncounterActionButton(
                icon: Icons.favorite,
                foreground: Colors.white,
                primary: true,
                onPressed: () => unawaited(
                  actOnEncounter(
                    post: post,
                    direction: DismissDirection.startToEnd,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              buildEncounterActionButton(
                icon: Icons.chat_bubble_outline,
                foreground: AppColors.softText,
                onPressed: () => unawaited(
                  actOnEncounter(
                    post: post,
                    direction: DismissDirection.startToEnd,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              buildPostChip(
                icon: Icons.lock_outline,
                label: "Gizli eşleşme",
                color: const Color(0xFFF5B5CE),
              ),
              buildPostChip(
                icon: Icons.location_on_outlined,
                label: formatDistance(item.distanceMeters),
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDismissBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.softText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color anonymousAvatarColor(String seed) {
    final colors = [
      AppColors.secondary,
      AppColors.violet,
      Color(0xFFFFB000),
      Color(0xFF7A2CB8),
      Color(0xFF0F8F43),
      Color(0xFFFF7A2B),
    ];

    final hash = seed.codeUnits.fold<int>(
      0,
      (value, codeUnit) => value + codeUnit,
    );
    return colors[hash % colors.length];
  }

  Widget buildPostOwnerAvatar(EncounterPost post, {double size = 58}) {
    // Anonim ilanlarda gercek fotograf yok: uygulamanin goz ikonunu
    // ilan id'sinden gelen farkli bir renkle avatar gibi kullaniyoruz.
    if (post.isAnonymous) {
      return appLogo(size: size, color: anonymousAvatarColor(post.id));
    }

    if (post.ownerPhotoUrls.isEmpty) {
      return appLogo(size: size, color: AppColors.secondary);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: buildSavedProfilePhotoImage(post.ownerPhotoUrls.first),
    );
  }

  String ownerDisplayName(EncounterPost post) {
    if (post.isAnonymous) {
      return "Anonim";
    }

    if (post.ownerAge == null) {
      return post.ownerName;
    }

    return "${post.ownerName}, ${post.ownerAge}";
  }

  Widget buildOwnerIdentityBlock(EncounterPost post) {
    return Row(
      children: [
        buildPostOwnerAvatar(post, size: 58),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ownerDisplayName(post),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.isAnonymous ? "Kimliğini gizli paylaştı" : "Açık kimlik",
                style: TextStyle(
                  color: AppColors.softText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildSwipeEncounterCard(EncounterWithDistance item) {
    final post = item.post;
    final quote = post.note.trim().isNotEmpty
        ? post.note.trim()
        : post.description.trim();
    final identityLabel = post.isAnonymous
        ? "ANONİM İTİRAF"
        : ownerDisplayName(post).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.violet,
            AppColors.backgroundSoft,
            AppColors.violetDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1AFF4D93), Color(0x33120D1A)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 6,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.softText),
                color: AppColors.cardSolid,
                onSelected: (value) {
                  if (value == "report") {
                    reportEncounterPost(post);
                  }

                  if (value == "block") {
                    blockEncounterOwner(post);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: "report", child: Text("İlanı raporla")),
                  PopupMenuItem(
                    value: "block",
                    child: Text("Kullanıcıyı engelle"),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5B5CE).withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 42),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildPostChip(
                        icon: post.isAnonymous
                            ? Icons.visibility_off_outlined
                            : Icons.badge_outlined,
                        label: post.isAnonymous ? "Anonim" : "Açık kimlik",
                        color: const Color(0xFFF5B5CE),
                      ),
                      buildPostChip(
                        icon: Icons.favorite_border,
                        label: "${post.requestCount} istek",
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Text(
                    identityLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF5B5CE),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '"$quote"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      height: 1.28,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.softText,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "KAYDIR VEYA KALBE DOKUN",
                    style: TextStyle(
                      color: AppColors.softText.withValues(alpha: 0.74),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: AppColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.place,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              "${formatDistance(item.distanceMeters)} · ${formatCreatedAt(post.createdAt)}",
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildDetailRow(
                        icon: Icons.access_time,
                        title: "Ne zaman?",
                        value: post.dateTimeText,
                      ),
                      buildDetailRow(
                        icon: Icons.person_search_outlined,
                        title: "Kişiyi nasıl hatırlıyor?",
                        value: post.description,
                      ),
                      buildDetailRow(
                        icon: Icons.palette_outlined,
                        title: "Görünüm",
                        value: post.personAppearance,
                      ),
                      buildDetailRow(
                        icon: Icons.badge_outlined,
                        title: "Ayırt edici özellikler",
                        value: post.personTraits,
                      ),
                      buildDetailRow(
                        icon: Icons.directions_car_outlined,
                        title: "Araç plakası",
                        value: post.vehiclePlate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      "Sağa kaydırırsan istek gider. Sola kaydırırsan bu itirafı geçersin.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.softText,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSwipeDeck(List<EncounterWithDistance> cards) {
    final currentItem = cards.first;
    final post = currentItem.post;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Dismissible(
              key: ValueKey("encounter_swipe_${post.id}"),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) =>
                  confirmSwipe(direction: direction, post: post),
              onDismissed: (direction) => markPostDismissed(post, direction),
              background: buildDismissBackground(
                alignment: Alignment.centerLeft,
                color: AppColors.accent,
                icon: Icons.favorite,
                label: "İstek gönder",
              ),
              secondaryBackground: buildDismissBackground(
                alignment: Alignment.centerRight,
                color: AppColors.danger,
                icon: Icons.close,
                label: "Geç",
              ),
              child: RepaintBoundary(
                child: SizedBox.expand(
                  child: buildSwipeEncounterCard(currentItem),
                ),
              ),
            ),
          ),
        ),
        buildEncounterActions(currentItem),
      ],
    );
  }

  Widget buildInterestButton(EncounterPost post) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return OutlinedButton.icon(
        onPressed: () {
          unawaited(sendInterest(post).then((_) {}));
        },
        icon: const Icon(Icons.visibility_outlined),
        label: const Text("Bu ben olabilirim"),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    if (post.ownerId == user.uid) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.person_outline),
        label: const Text("Kendi ilanın"),
      );
    }

    final requestId = "${post.id}_${user.uid}";

    // Butonun yazisi canli degisir: beklemede, kabul edildi veya tekrar gonder.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("interest_requests")
          .doc(requestId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = data?["status"]?.toString();

        if (status == "pending") {
          return OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_top),
            label: const Text("Match Bekleniyor"),
          );
        }

        if (status == "accepted") {
          final chatId =
              (data?["chatId"] ?? buildChatId(post.ownerId, user.uid))
                  .toString();

          return ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    chatId: chatId,
                    otherUserId: post.ownerId,
                    otherUserName: post.ownerName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text("Sohbete Git"),
          );
        }

        return OutlinedButton.icon(
          onPressed: () {
            unawaited(sendInterest(post).then((_) {}));
          },
          icon: const Icon(Icons.visibility_outlined),
          label: Text(
            status == "rejected" ? "Tekrar İstek Gönder" : "Bu ben olabilirim",
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget buildPostChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: chipColor, size: 15),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chipColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEncounterCard(EncounterWithDistance item) {
    final post = item.post;
    final currentUser = FirebaseAuth.instance.currentUser;
    final chips = [
      if (post.personAppearance.isNotEmpty)
        buildPostChip(
          icon: Icons.palette_outlined,
          label: post.personAppearance,
        ),
      if (post.personTraits.isNotEmpty)
        buildPostChip(icon: Icons.badge_outlined, label: post.personTraits),
      if (post.vehiclePlate.isNotEmpty)
        buildPostChip(
          icon: Icons.directions_car_outlined,
          label: post.vehiclePlate,
        ),
      buildPostChip(
        icon: Icons.favorite_border,
        label: "${post.requestCount} istek",
        color: AppColors.accent,
      ),
    ];

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.place,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (currentUser != null && post.ownerId != currentUser.uid)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.softText),
                  onSelected: (value) {
                    if (value == "report") {
                      reportEncounterPost(post);
                    }

                    if (value == "block") {
                      blockEncounterOwner(post);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: "report",
                      child: Text("Ilani raporla"),
                    ),
                    PopupMenuItem(
                      value: "block",
                      child: Text("Kullaniciyi engelle"),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${post.dateTimeText} • ${formatCreatedAt(post.createdAt)}",
            style: TextStyle(color: AppColors.softText, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDistance(item.distanceMeters),
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (post.isAnonymous)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        color: AppColors.accent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Anonim",
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.description,
            style: TextStyle(color: AppColors.text, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            post.note,
            style: TextStyle(
              color: AppColors.softText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: buildInterestButton(post)),
        ],
      ),
    );
  }

  Widget buildErrorView(Object error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, color: AppColors.accent, size: 56),
          const SizedBox(height: 18),
          Text(
            error.toString().replaceAll("Exception: ", ""),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.softText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: refreshLocation,
            child: const Text("Tekrar Dene"),
          ),
        ],
      ),
    );
  }

  Widget buildPilotRegionView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GlassPanel(
          radius: 28,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.location_city_outlined,
                  color: AppColors.accent,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Pilot bölge Ankara",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Şimdilik keşif ve itiraf bırakma akışı sadece Ankara içinde açık. Diğer şehirleri sonra ekleyeceğiz.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.softText,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: refreshLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text("Konumu tekrar kontrol et"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPostsList(Position currentPosition) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Firestore stream'i initState icinde sabitlenir; kart kaydirirken yeniden baglanmaz.
      stream: encountersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "İlanlar yüklenirken hata oluştu:\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.softText),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final nearbyPosts = filterNearbyPosts(
          docs: docs,
          currentPosition: currentPosition,
        );

        if (isLoadingDismissedPosts) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        final cards = availableSwipeItems(nearbyPosts);

        if (cards.isEmpty) {
          return _EmptyEncounterSearch(
            radiusSelector: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildDiscoverShortcuts(),
                buildRadiusSelector(currentPosition),
              ],
            ),
          );
        }

        return Column(
          children: [
            buildDiscoverShortcuts(),
            buildRadiusSelector(currentPosition),
            Expanded(child: buildSwipeDeck(cards)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text("Yakınımdaki İtiraflar"),
        actions: [
          IconButton(
            onPressed: refreshLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: FutureBuilder<Position>(
            future: positionFuture,
            builder: (context, positionSnapshot) {
              if (positionSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }

              if (positionSnapshot.hasError) {
                return buildErrorView(positionSnapshot.error!);
              }

              final currentPosition = positionSnapshot.data!;

              if (!isLocationInAnkara(
                latitude: currentPosition.latitude,
                longitude: currentPosition.longitude,
              )) {
                return buildPilotRegionView();
              }

              return buildPostsList(currentPosition);
            },
          ),
        ),
      ),
    );
  }
}
