# Fildir Backend

Flutter uygulamasini kirmadan yeni backend burada gelistirilecek.

## Hedef Mimari

- ASP.NET Core REST API
- PostgreSQL ana veritabani
- JWT access token
- Refresh token icin Redis veya PostgreSQL destekli oturum katmani
- Firebase'den kademeli gecis

## Lokal Calistirma

Docker Desktop kuruluysa:

```powershell
cd backend
copy .env.example .env
docker compose up -d
dotnet tool restore
dotnet tool run dotnet-ef database update --project src/Fildir.Infrastructure/Fildir.Infrastructure.csproj --startup-project src/Fildir.Api/Fildir.Api.csproj
dotnet run --project src/Fildir.Api/Fildir.Api.csproj
```

Health endpoint:

```text
http://localhost:5170/api/health
http://localhost:5170/api/health/db
```

Auth endpointleri:

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
```

`/api/auth/me` icin `Authorization: Bearer <accessToken>` header'i gerekir.
Refresh token veritabaninda hash'li saklanir ve refresh isteginde rotate edilir.

Profil endpointleri:

```text
GET /api/profile/me
PUT /api/profile/me
```

Profil endpointleri de `Authorization: Bearer <accessToken>` ister.
Profilde display name, dogum tarihi, yas, cinsiyet, bio, telefon, sehir ve
en fazla 3 fotograf kaynagi tutulur.

Ilan/itiraf endpointleri:

```text
POST   /api/encounters
GET    /api/encounters?latitude=39.9334&longitude=32.8597&radiusKm=5&limit=40
GET    /api/encounters/mine
GET    /api/encounters/{id}
DELETE /api/encounters/{id}
```

Ilan olusturma ve listeleme de token ister. Pilot bolge kontrolu backend'de
Ankara merkezli 85 km cember ile yapilir. Listeleme, kullanicinin konumuna gore
izinli yaricap icindeki ilanlari dondurur.

Istek/eslesme endpointleri:

```text
POST /api/encounters/{encounterId}/requests
GET  /api/encounter-requests/incoming?status=Pending
GET  /api/encounter-requests/outgoing
GET  /api/encounter-requests/{id}
POST /api/encounter-requests/{id}/accept
POST /api/encounter-requests/{id}/reject
```

Bir kullanici kendi ilanina istek atamaz. Ayni ilana ayni kullanicidan ikinci
bekleyen istek acilmaz. Kabul edilince chat kaydi transaction icinde olusturulur
ve request `Accepted` durumuna gecer.

Chat endpointleri:

```text
GET  /api/chats
GET  /api/chats/{id}
GET  /api/chats/{id}/messages?limit=80
POST /api/chats/{id}/messages
POST /api/chats/{id}/read
```

Mesaj tipleri `Text`, `Photo`, `Voice` olarak gelir. Photo/Voice icin `content`
alaninda data-url veya ileride kullanilacak medya URL'si tasinir. Okunmamis
sayac, `ReadAt` bos olan ve karsi taraftan gelen mesajlardan hesaplanir.

Docker yoksa once Docker Desktop kur veya lokal PostgreSQL kurup
`src/Fildir.Api/appsettings.Development.json` icindeki connection string'i ona gore duzenle.

Yeni migration uretmek icin:

```powershell
dotnet tool run dotnet-ef migrations add MigrationAdi --project src/Fildir.Infrastructure/Fildir.Infrastructure.csproj --startup-project src/Fildir.Api/Fildir.Api.csproj --output-dir Persistence/Migrations
```

## Gecis Sirasi

1. Auth: register/login/JWT/refresh token
2. Profile: kullanici profil ve fotograflari
3. Encounter posts: itiraf/ilan akisi
4. Requests: eslesme/istek sistemi
5. Chats: mesajlar ve okunmamis sayaclari
6. Firebase bagimliligini kademeli azaltma
