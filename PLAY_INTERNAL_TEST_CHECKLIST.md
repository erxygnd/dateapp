# Piyasa Google Play Internal Test Checklist

Son guncelleme: 18 Mayis 2026

## Hazirlanan Teknik Parcalar

- Firestore rules: `firestore.rules`
- Storage rules hazirlik dosyasi: `storage.rules` (Firebase Storage bucket baslatilinca `firebase.json` icine eklenebilir)
- Firebase Hosting ayari: `firebase.json`
- Privacy Policy: `web/privacy-policy.html`
- Account deletion web page: `web/account-deletion.html`
- Child Safety Standards: `web/child-safety.html`
- Community Guidelines: `web/community-guidelines.html`
- Uygulama ici hesap silme: Profilim > Hesabi Sil
- Uygulama ici UGC guvenligi: ilan raporlama, ilan sahibi engelleme, sohbet raporlama, sohbet engelleme

## Play Console URL Alanlari

Firebase Hosting deploy sonrasi asagidaki URL'leri Play Console'da kullan:

- Privacy Policy URL: `https://<firebase-hosting-domain>/privacy-policy.html`
- Account deletion URL: `https://<firebase-hosting-domain>/account-deletion.html`
- Child Safety Standards URL: `https://<firebase-hosting-domain>/child-safety.html`
- Community Guidelines URL: `https://<firebase-hosting-domain>/community-guidelines.html`

Not: Sayfalarda gecici iletisim adresi `support@piyasa.app`. Gercek destek e-postan farkliysa web sayfalarinda ve store formlarinda ayni adresle degistir.

## Firebase Deploy Sirasi

```powershell
flutter build web --release
firebase deploy --only firestore:rules,hosting
```

## Android Internal Test Build

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Yuklenecek dosya:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Play Console Internal Test Adimlari

1. Test and release > Testing > Internal testing ekranina git.
2. Yeni release olustur.
3. `app-release.aab` dosyasini yukle.
4. Tester listesi olustur ve Gmail/Workspace adreslerini ekle.
5. Release notes alanina kisa not yaz:
   `Piyasa internal test: hesap, profil, konumlu ilan, rapor/engel, sohbet ve hesap silme akislari test ediliyor.`
6. Release'i internal test kanalina yayinla.
7. Opt-in linkini testerlarla paylas.

## Data Safety Formu Icin Toplanan Veri Tipleri

- Personal info: name, email address, user IDs, age/date of birth, gender, profile bio
- Location: precise location while using the app
- Photos and videos: profile and chat photos
- Audio: voice messages
- Messages: in-app chat messages
- App activity / user-generated content: encounter posts, reports, blocks

Kullanim amaclari:

- App functionality
- Account management
- Safety, security, fraud prevention
- Developer communications / support

## App Content / Policy Notlari

- Hedef kitle: 18+
- Kategori: Dating veya Social/Dating kapsaminda degerlendirilecek
- UGC var: ilanlar, profil icerigi, sohbet icerigi
- Raporlama ve engelleme var: ilan, kullanici, sohbet
- Account deletion var: uygulama ici ve web kaynakli talep
- Child Safety Standards var: CSAE/CSAM yasagi, in-app report, child safety contact

## Closed Testing Hatirlatmasi

Google Play kisisel geliştirici hesabi 13 Kasim 2023 sonrasi acildiysa production erisimi icin kapali testte en az 12 tester'in 14 gun boyunca opt-in kalmasi gerekir. Internal test teknik dogrulama icindir; production kilidini acmak icin gerekli surec closed testing kanalinda isler.

## Resmi Politika Referanslari

- Testing requirements: https://support.google.com/googleplay/android-developer/answer/14151465
- Account deletion requirements: https://support.google.com/googleplay/android-developer/answer/13327111
- Data safety form: https://support.google.com/googleplay/android-developer/answer/10787469
- User Generated Content policy: https://support.google.com/googleplay/android-developer/answer/9876937
- Child Safety Standards: https://support.google.com/googleplay/android-developer/answer/14747720
