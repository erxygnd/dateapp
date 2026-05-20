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
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const MyDatingApp());
}

class MyDatingApp extends StatelessWidget {
  const MyDatingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piyasa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const StartupPage(),
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
                        "Piyasa",
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
                  const LinearProgressIndicator(
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.95, -1),
          radius: 1.1,
          colors: [Color(0x3322C55E), Color(0x00FFFFFF)],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, 1),
            radius: 1,
            colors: [Color(0x2686EFAC), Color(0x00FFFFFF)],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppColors.background,
                AppColors.backgroundSoft,
              ],
            ),
          ),
          child: child,
        ),
      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppColors.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F14532D),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingPage();
        }

        if (snapshot.hasData) {
          return const WelcomePage();
        }

        return const LoginPage();
      },
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
    );
  }
}

Future<Position> getCurrentPositionSafely() async {
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    throw Exception("Konum servisi kapalı. Lütfen telefon konumunu aç.");
  }

  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
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
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}

String friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case "invalid-email":
      return "E-posta formatı hatalı.";
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
      style: const TextStyle(color: AppColors.text),
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
      style: const TextStyle(color: AppColors.text),
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
  return value.trim().toLowerCase();
}

bool isValidUsername(String value) {
  return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value.trim());
}

final Map<String, ImageProvider<Object>> profilePhotoImageProviderCache = {};
final Map<String, Uint8List?> embeddedProfilePhotoBytesCache = {};

Future<List<String>> prepareProfilePhotoSources({
  required List<LocalProfilePhoto> photos,
}) async {
  return photos.map((photo) => photo.toDataUrl()).toList();
}

bool isEmbeddedProfilePhoto(String source) {
  return source.startsWith(profilePhotoDataPrefix);
}

Uint8List? embeddedProfilePhotoBytes(String source) {
  if (embeddedProfilePhotoBytesCache.containsKey(source)) {
    return embeddedProfilePhotoBytesCache[source];
  }

  if (!isEmbeddedProfilePhoto(source)) {
    embeddedProfilePhotoBytesCache[source] = null;
    return null;
  }

  try {
    final bytes = base64Decode(source.substring(profilePhotoDataPrefix.length));
    embeddedProfilePhotoBytesCache[source] = bytes;
    return bytes;
  } on FormatException {
    embeddedProfilePhotoBytesCache[source] = null;
    return null;
  }
}

Widget buildSavedProfilePhotoImage(String source) {
  final cachedProvider = profilePhotoImageProviderCache[source];

  if (cachedProvider != null) {
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
  profilePhotoImageProviderCache[source] = provider;

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
        const Text(
          "Profil fotoğrafları",
          style: TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
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
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.text,
                    ),
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
          Text(
            text,
            style: const TextStyle(color: AppColors.softText, fontSize: 12),
          ),
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
                          child: const Center(
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
                  const Text(
                    "Piyasa",
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Hesabına giriş yap",
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
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

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: isPasswordHidden,
                    style: const TextStyle(color: AppColors.text),
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
                      const Text(
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
      final firestore = FirebaseFirestore.instance;
      final usernameRef = firestore.collection("usernames").doc(usernameLower);
      final existingUsername = await usernameRef.get();

      if (!mounted) {
        return;
      }

      if (existingUsername.exists) {
        showMessage("Bu kullanıcı adı alınmış.");
        return;
      }

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final user = credential.user!;
      try {
        await usernameRef.set({
          "uid": user.uid,
          "username": username,
          "usernameLower": usernameLower,
          "email": emailController.text.trim(),
          "createdAt": FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        await user.delete();
        showMessage("Bu kullanici adi az once alindi. Baska bir ad dene.");
        return;
      }

      final photoUrls = await prepareProfilePhotoSources(
        photos: selectedPhotos,
      );

      unawaited(
        user
            .updateDisplayName(displayNameController.text.trim())
            .timeout(profileSaveTimeout)
            .catchError((_) {}),
      );

      await firestore
          .collection("users")
          .doc(user.uid)
          .set({
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
            "photoUrls": photoUrls,
            "photoUploadPending": false,
            "premium": PremiumAccess.defaultUserState(),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          })
          .timeout(profileSaveTimeout);

      if (mounted) {
        Navigator.pop(context);
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
                const Text(
                  "Yeni hesap oluştur",
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
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
                  style: const TextStyle(color: AppColors.text),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "E-posta boş bırakılamaz";
                    }

                    if (!value.contains("@")) {
                      return "Geçerli bir e-posta gir";
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: isPasswordHidden,
                  style: const TextStyle(color: AppColors.text),
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
                    hint: "En az 6 karakter",
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
                  style: const TextStyle(color: AppColors.text),
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
                      const Expanded(
                        child: Text(
                          "18 yaşından büyük olduğumu, açık adres/telefon gibi özel bilgiler paylaşmayacağımı ve karşılıklı onay olmadan iletişim kuramayacağımı kabul ediyorum.",
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
                    const Text(
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

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

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
        onProfile: () => openPage(context, const ProfilePage()),
        onRequests: () => openPage(context, const IncomingRequestsPage()),
        onChats: () => openPage(context, const ChatListPage()),
        onBrowse: () => openPage(context, const BrowseEncountersPage()),
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
                    const Expanded(
                      child: Text(
                        "Piyasa",
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.logout_rounded,
                      onPressed: logout,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  "Merhaba, $userName",
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Şehrin içinde yarım kalan anları bul.",
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 33,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
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
                                children: const [
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
                              const Text(
                                "Bugün bir bakış yarım kaldıysa, şehir onu unutmaz.",
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
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
                        openPage(context, const BrowseEncountersPage()),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text("Yakındaki İtirafları Keşfet"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
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

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: AppColors.text,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.cardSolid,
            side: const BorderSide(color: AppColors.border),
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
        color: AppColors.cardSolid,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumBottomNav extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onRequests;
  final VoidCallback onChats;
  final VoidCallback onBrowse;

  const PremiumBottomNav({
    super.key,
    required this.onProfile,
    required this.onRequests,
    required this.onChats,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: GlassPanel(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: AppColors.backgroundSoft.withValues(alpha: 0.78),
        child: Row(
          children: [
            _NavButton(
              icon: Icons.account_circle_outlined,
              label: "Profil",
              onPressed: onProfile,
            ),
            _NavButton(
              icon: Icons.style_outlined,
              label: "İstek",
              onPressed: onRequests,
            ),
            _NavButton(
              icon: Icons.chat_bubble_outline,
              label: "Sohbet",
              onPressed: onChats,
            ),
            _NavButton(
              icon: Icons.explore_outlined,
              label: "Keşfet",
              onPressed: onBrowse,
              active: true,
            ),
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
                ? const LinearGradient(
                    colors: [AppColors.accent, Color(0xFFFFD166)],
                  )
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
  final bool active;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.softText;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
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
                    style: const TextStyle(
                      color: AppColors.softText,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: logout,
                    icon: const Icon(Icons.logout, color: AppColors.softText),
                  ),
                ],
              ),
              const SizedBox(height: 44),
              appLogo(),
              const SizedBox(height: 32),
              const Text(
                "Piyasa",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Gördün. Konuşamadın. Belki o da seni arıyordur.",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
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
                child: const Row(
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
                    side: const BorderSide(color: AppColors.border),
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
                    side: const BorderSide(color: AppColors.border),
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
                    side: const BorderSide(color: AppColors.border),
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
        user
            .updateDisplayName(nameController.text.trim())
            .timeout(profileSaveTimeout)
            .catchError((_) {}),
      );
      final uploadedUrls = await prepareProfilePhotoSources(photos: newPhotos);
      final updatedPhotoUrls = [...photoUrls, ...uploadedUrls];

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
            style: const TextStyle(color: AppColors.text),
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
      await accountDeletionService.reauthenticateWithPassword(password);
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
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: usernameController,
                        readOnly: true,
                        style: const TextStyle(color: AppColors.softText),
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
                        style: const TextStyle(color: AppColors.softText),
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
                        style: const TextStyle(color: AppColors.softText),
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
                              ? const SizedBox(
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
    final chatId = buildChatId(user.uid, requesterId);
    final chatOpenedAt = DateTime.now();
    final requesterName =
        (data["requesterName"] ?? data["interestedUserName"] ?? "Kullanıcı")
            .toString();

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
                const CircleAvatar(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    age is int ? "$name, $age" : name,
                    style: const TextStyle(
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
              style: const TextStyle(
                color: AppColors.softText,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "İlgilendiği itiraf: ${data["postPlace"] ?? "Karşılaşma"}",
              style: const TextStyle(
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
          ? const Center(
              child: Text(
                "Önce giriş yapmalısın.",
                style: TextStyle(color: AppColors.softText),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("interest_requests")
                  .where("postOwnerId", isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final docs = (snapshot.data?.docs ?? [])
                    .where((doc) => doc.data()["status"] == "pending")
                    .toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Henüz gelen istek yok.\nBirisi “Bu ben olabilirim” dediğinde burada kart olarak görünecek.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.softText,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return buildRequestCard(context, docs[index]);
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
          ? const Center(
              child: Text(
                "Önce giriş yapmalısın.",
                style: TextStyle(color: AppColors.softText),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .where("participants", arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
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
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.chat_bubble_outline),
                      ),
                      title: Text(
                        otherName,
                        style: const TextStyle(color: AppColors.text),
                      ),
                      subtitle: Text(
                        (data["lastMessage"] ?? "Sohbet açıldı.").toString(),
                        style: const TextStyle(color: AppColors.softText),
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
      style: const TextStyle(
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
  Timer? chatTimer;
  bool isSending = false;
  bool isRecordingVoice = false;
  int recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    chatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !isRecordingVoice) {
        return;
      }

      recordingSeconds++;

      if (recordingSeconds >= voiceRecordingMaxDuration.inSeconds) {
        isRecordingVoice = false;
        unawaited(stopVoiceRecording());
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    chatTimer?.cancel();
    if (isRecordingVoice) {
      unawaited(stopVoiceRecording(sendAfterStop: false));
    }
    messageController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get messagesRef => FirebaseFirestore
      .instance
      .collection("chats")
      .doc(widget.chatId)
      .collection("messages");

  DateTime? photoUnlockDate(Map<String, dynamic> chatData) {
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

  Future<void> updateChatPreview(String lastMessage) {
    return FirebaseFirestore.instance
        .collection("chats")
        .doc(widget.chatId)
        .set({
          "lastMessage": lastMessage,
          "lastMessageAt": FieldValue.serverTimestamp(),
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
      showMessage("Bu sohbet engellendiği için mesaj gönderilemez.");
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      await messagesRef.add({
        "senderId": user.uid,
        "text": text,
        "type": "text",
        "createdAt": FieldValue.serverTimestamp(),
      });

      await updateChatPreview(text);

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

      await messagesRef.add({
        "senderId": user.uid,
        "type": "image",
        "imageSource": photoSources.single,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await updateChatPreview(lastMessagePreview("image", ""));
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
      await appMediaChannel.invokeMethod<void>("startVoiceRecording");

      if (!mounted) {
        return;
      }

      setState(() {
        isRecordingVoice = true;
        recordingSeconds = 0;
      });
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
        return;
      }

      await messagesRef.add({
        "senderId": user.uid,
        "type": "voice",
        "audioSource": dataUrl,
        "durationSeconds": durationSeconds,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await updateChatPreview(lastMessagePreview("voice", ""));
    } on MissingPluginException {
      showMessage("Ses kaydı bu cihazda desteklenmiyor.");
    } on PlatformException catch (e) {
      showMessage(e.message ?? "Ses kaydı gönderilemedi.");
    } catch (e) {
      showMessage("Ses kaydı gönderilemedi: $e");
    } finally {
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

    await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).set(
      {
        "blockedBy": FieldValue.arrayUnion([user.uid]),
        "blockedAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

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
        child: const Column(
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
                  "Sohbet kuralları",
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Kibar ol. Israr etme. Telefon, açık adres veya özel bilgi isteme. Rahatsız hissedersen raporla ya da engelle.",
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
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              enabled: !isBlocked && !isRecordingVoice,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: isBlocked
                    ? "Bu sohbet engellendi"
                    : isRecordingVoice
                    ? "Ses kaydı alınıyor..."
                    : "Mesaj yaz",
                hintStyle: const TextStyle(color: AppColors.softText),
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
              child: const Text(
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
              style: const TextStyle(
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
      stream: FirebaseFirestore.instance
          .collection("chats")
          .doc(widget.chatId)
          .snapshots(),
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
              ? const Center(
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
                            stream: messagesRef
                                .orderBy("createdAt")
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
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
      final position = await getCurrentPositionSafely();

      if (!mounted) {
        return;
      }

      final ownerName = isAnonymous
          ? "Anonim"
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : "Kullanıcı");

      await FirebaseFirestore.instance.collection("encounters").add({
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
        if (!isAnonymous) "ownerEmail": user.email,
        "isAnonymous": isAnonymous,
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
        title: const Text("Karşılaşma Bırak"),
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const Align(
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
                  const Text(
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
  double radiusKm = 5;
  Set<String> blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    positionFuture = getCurrentPositionSafely();
    unawaited(loadBlockedUsers());
  }

  void refreshLocation() {
    setState(() {
      positionFuture = getCurrentPositionSafely();
    });
    unawaited(loadBlockedUsers());
  }

  Future<void> loadBlockedUsers() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

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
            style: const TextStyle(color: AppColors.text),
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

  Future<void> sendInterest(EncounterPost post) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Önce giriş yapmalısın.");
      return;
    }

    if (post.ownerId == user.uid) {
      showMessage("Kendi ilanına istek gönderemezsin.");
      return;
    }

    try {
      final profile = await loadUserProfile(user);

      if (!mounted) {
        return;
      }

      final requestId = "${post.id}_${user.uid}";
      final requestRef = FirebaseFirestore.instance
          .collection("interest_requests")
          .doc(requestId);
      final existingRequest = await requestRef.get();
      final existingStatus = existingRequest.data()?["status"];

      if (!mounted) {
        return;
      }

      if (existingStatus == "pending") {
        showMessage("Bu itiraf için isteğin zaten beklemede.");
        return;
      }

      if (existingStatus == "accepted") {
        showMessage("Bu itiraf için sohbet zaten açılmış.");
        return;
      }

      await requestRef.set({
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
        await FirebaseFirestore.instance
            .collection("encounters")
            .doc(post.id)
            .set({
              "requestCount": FieldValue.increment(1),
            }, SetOptions(merge: true));
      }

      showMessage(
        "İstek gönderildi. İlan sahibi profilini sağa kaydırırsa sohbet açılacak.",
      );
    } catch (e) {
      showMessage("İstek gönderilirken hata oluştu: $e");
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
    final effectiveRadiusKm = effectiveRadiusKmForLocation(
      requestedRadiusKm: radiusKm,
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
    );

    for (final doc in docs) {
      final post = EncounterPost.fromDoc(doc);

      if (blockedUserIds.contains(post.ownerId)) {
        continue;
      }

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

    return nearbyPosts;
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.radar, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                inAnkara
                    ? "Gösterilecek mesafe (Ankara için en fazla 50 km)"
                    : "Gösterilecek mesafe",
                style: const TextStyle(color: AppColors.softText, fontSize: 14),
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

  Widget buildInterestButton(EncounterPost post) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return OutlinedButton.icon(
        onPressed: () => sendInterest(post),
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
          onPressed: () => sendInterest(post),
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
    Color color = AppColors.secondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
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
              const Icon(Icons.location_on_outlined, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  post.place,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (currentUser != null && post.ownerId != currentUser.uid)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.softText),
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
            style: const TextStyle(color: AppColors.softText, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDistance(item.distanceMeters),
                  style: const TextStyle(
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
                  child: const Row(
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
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            post.note,
            style: const TextStyle(
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
          const Icon(
            Icons.location_off_outlined,
            color: AppColors.accent,
            size: 56,
          ),
          const SizedBox(height: 18),
          Text(
            error.toString().replaceAll("Exception: ", ""),
            textAlign: TextAlign.center,
            style: const TextStyle(
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

  Widget buildPostsList(Position currentPosition) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("encounters")
          .orderBy("createdAt", descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
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
                style: const TextStyle(color: AppColors.softText),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final nearbyPosts = filterNearbyPosts(
          docs: docs,
          currentPosition: currentPosition,
        );

        if (nearbyPosts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Yakınında henüz itiraf yok.\nİlk karşılaşmayı sen bırak.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.softText,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: nearbyPosts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return buildEncounterCard(nearbyPosts[index]);
          },
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
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }

              if (positionSnapshot.hasError) {
                return buildErrorView(positionSnapshot.error!);
              }

              final currentPosition = positionSnapshot.data!;

              return Column(
                children: [
                  buildRadiusSelector(currentPosition),
                  Expanded(child: buildPostsList(currentPosition)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}