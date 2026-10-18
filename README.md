# DafMoney - Tahap 2 (Autentikasi, jalur A: tautan verifikasi Firebase)

## Cara pasang
1. Ekstrak zip ini DI ATAS folder proyek `dafmoney/` (timpa file yang sama).
   Struktur path sudah sama dengan proyek (lib/..., firestore.rules).
2. (Opsional) Hapus dependensi yang tidak dipakai lagi:
   flutter pub remove cloud_functions
3. flutter pub get && flutter run

## Setup Firebase (sekali saja)
1. Buat proyek di console.firebase.google.com
2. Authentication > Get started > aktifkan Email/Password
3. Firestore Database > Create database > Production, lokasi asia-southeast2
4. Authentication > Templates > ubah bahasa ke Indonesia dan sesuaikan nama pengirim
   (untuk Verifikasi email dan Reset kata sandi)
5. Hubungkan app: flutterfire configure  (menghasilkan lib/firebase_options.dart)
6. Deploy aturan keamanan:
   firebase init firestore   (jika belum ada firebase.json)
   firebase deploy --only firestore:rules

## Checklist pengujian
- [ ] Daftar akun baru -> masuk ke halaman Verifikasi Email
- [ ] Email tiba (cek spam) -> klik tautan -> kembali ke app -> otomatis ke Beranda
- [ ] Keluar (tab Pengaturan) lalu masuk lagi -> langsung ke Beranda
- [ ] Masuk dengan kata sandi salah -> pesan error yang jelas
- [ ] Lupa kata sandi -> email reset tiba -> setel sandi baru -> bisa masuk
- [ ] Firebase Console > Firestore: dokumen users/{uid} terbentuk
- [ ] Tutup app saat belum verifikasi, buka lagi -> tetap di halaman Verifikasi

---
## Setup awal proyek (dari Tahap 1)
1. flutter create --org com.daf --project-name dafmoney dafmoney
2. Salin isi zip ini ke folder dafmoney/ (timpa lib/, tambahkan firestore.rules)
3. Tambahkan dependensi:
   flutter pub add flutter_riverpod go_router firebase_core firebase_auth \
     cloud_firestore shared_preferences intl fl_chart \
     google_fonts flutter_animate equatable
   flutter pub add flutter_localizations --sdk=flutter
4. Android: minSdk 23+ ; iOS: platform :ios, '13.0'
5. flutterfire configure (membuat lib/firebase_options.dart)
