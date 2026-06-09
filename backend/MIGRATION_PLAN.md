# Backend Migration Plan

Amaç: Flutter uygulamasını bozmadan Firebase bağımlılığını kademeli azaltmak.

## 1. Backend Temeli

- ASP.NET Core REST API
- PostgreSQL schema ve EF Core migrations
- Health endpointleri
- Docker ile lokal PostgreSQL/Redis

Durum: başlatıldı.

## 2. Auth

- Register
- Login
- JWT access token
- Refresh token
- Logout
- Password hash

Bu adım tamamlanana kadar Flutter giriş ekranı Firebase ile kalabilir.

## 3. Profil

- Kullanıcı profili
- Fotoğraf saklama stratejisi
- Yaş, kullanıcı adı, görünür profil bilgileri

Önce API endpointleri yazılacak, sonra Flutter profil ekranı API'ye bağlanacak.

## 4. İtiraf / İlan Akışı

- İlan oluşturma
- Yakındaki ilanları listeleme
- Ankara pilot bölge kontrolü
- Kullanıcının kendi ilanları

Bu adımda Firestore `encounters` koleksiyonu backend'e taşınır.

## 5. İstekler

- İstek gönderme
- Kabul / red
- Aynı ilana ikinci istek engeli
- İstek sayacı

Bu adımda izin/transaction kuralları backend tarafında garanti edilir.

## 6. Sohbet

- Chat oluşturma
- Mesaj gönderme
- Okunmamış mesaj sayacı
- İlk etap REST polling, sonra gerekirse SignalR

Sohbet için gerçek zamanlılık gerekirse SignalR Redis backplane ile büyütülebilir.

## 7. Firebase Kapatma

- Auth taşındıktan sonra FirebaseAuth kaldırılır
- Firestore okuma/yazma bitince Firestore bağımlılığı kaldırılır
- Storage kullanılmıyorsa paketlerden çıkarılır
