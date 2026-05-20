# Piyasa Store Release Notlari

## Google Play

0. Internal test hazirliklari ve politika checklist'i icin `PLAY_INTERNAL_TEST_CHECKLIST.md` dosyasini takip et.
1. Firebase Console'da Android uygulamasi icin paket adini `com.piyasa.app` olarak ekle.
2. Yeni `google-services.json` dosyasini `android/app/google-services.json` uzerine koy.
   FlutterFire CLI kullaniyorsan:

   ```powershell
   flutterfire configure --project=eros-dateapp --platforms=android,ios --android-package-name=com.piyasa.app --ios-bundle-id=com.piyasa.app
   ```

3. Upload keystore bu makinada `android/upload-keystore.jks` olarak olusturuldu. Yeni key gerekirse:

   ```powershell
   keytool -genkey -v -keystore android/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

4. `android/key.properties` bu makinada olusturuldu ve `.gitignore` icinde tutuluyor. Keystore'u yedekle; kaybolursa ayni upload key ile yeni surum imzalayamazsin.
5. App bundle al:

   ```powershell
   flutter build appbundle --release
   ```

6. Cikti: `build/app/outputs/bundle/release/app-release.aab`

## App Store

1. Apple Developer hesabinda bundle ID olarak `com.piyasa.app` olustur.
2. Firebase Console'da iOS uygulamasi icin bundle ID'yi `com.piyasa.app` olarak ekle.
3. Gerekirse yeni `GoogleService-Info.plist` dosyasini Xcode'da `ios/Runner` hedefinin icine ekle.
4. macOS/Xcode uzerinden signing team sec, Archive al ve App Store Connect'e yukle.

## Magaza Formlari

- Konum, fotograf arsivi ve mikrofon izinleri uygulama icinde kullaniliyor.
- Uygulama hesap, profil fotografi, konum, sohbet metni ve ses kaydi verileri topluyor.
- Uygulama yetiskinlere yonelik tanisma amacli oldugu icin yas siniri ve guvenlik/moderasyon aciklamalari magaza formlarinda net yazilmali.
- Privacy Policy URL: `https://<firebase-hosting-domain>/privacy-policy.html`
- Account deletion URL: `https://<firebase-hosting-domain>/account-deletion.html`
- Child Safety Standards URL: `https://<firebase-hosting-domain>/child-safety.html`
- Community Guidelines URL: `https://<firebase-hosting-domain>/community-guidelines.html`
