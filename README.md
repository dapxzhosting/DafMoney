# 💰 DafMoney - Aplikasi Catatan Keuangan Pribadi

**DafMoney** adalah aplikasi pencatat keuangan pribadi modern berbasis Android & iOS yang dibangun menggunakan **Flutter**, **Riverpod**, dan **Firebase**. Aplikasi ini dirancang untuk membantu Anda mengelola arus kas (pemasukan dan pengeluaran), menetapkan anggaran bulanan, menganalisis statistik keuangan melalui grafik interaktif, serta menjaga keamanan data transaksi Anda.

---

## 🌟 Fitur Utama

### 🔐 1. Otentikasi & Manajemen Akun
* **Pendaftaran & Login:** Mendukung registrasi akun baru berbasis Email & Password.
* **Verifikasi Email:** Fitur pengamanan verifikasi email sebelum dapat mengakses fitur utama.
* **Lupa Kata Sandi:** Fitur reset password otomatis via link email.
* **Manajemen Profil:** Ubah nama profil, perbarui kata sandi, hingga hapus akun permanen.

### 📊 2. Dashboard Interaktif
* **Ringkasan Keuangan:** Menampilkan Total Pemasukan, Total Pengeluaran, dan Saldo Bersih secara *realtime*.
* **Grafik Tren Harian:** Visualisasi grafik garis (*Line Chart*) arus kas harian.
* **Diagram Donat Kategori:** Distribusi pengeluaran per kategori secara intuitif (*Donut Chart*).
* **Transaksi Terbaru:** Daftar riwayat transaksi terakhir yang dapat diakses dengan cepat.

### 💸 3. Pencatatan Transaksi
* **Pencatatan Cepat:** Tambah, ubah, dan hapus transaksi Pemasukan atau Pengeluaran.
* **Format Mata Uang Rupiah:** Input dan tampilan otomatis terformat dalam Rupiah (`Rp`).
* **Detail Transaksi:** Kelompokkan transaksi berdasarkan Kategori, Tanggal, dan Catatan tambahan.
* **Filter Bulanan:** Navigasi riwayat transaksi berdasarkan bulan dan tahun.

### 🎯 4. Manajemen Anggaran (Budgeting)
* **Batas Pengeluaran Bulanan:** Tentukan batas anggaran per kategori pengeluaran per bulan.
* **Progres Penggunaan:** Indikator visual (*Progress Bar*) persentase anggaran yang telah terpakai.
* **Peringatan Overbudget:** Indikasi warna otomatis saat pengeluaran mendekati atau melebihi limit.
* **Salin Anggaran:** Fitur praktis untuk menyalin struktur anggaran dari bulan sebelumnya.

### 🏷️ 5. Kelola Kategori Transaksi
* **Kategori Bawaan:** Otomatis terisi saat pengguna baru mendaftar (Makanan, Gaji, Transportasi, dll.).
* **Kategori Kustom:** Tambah dan sesuaikan nama kategori, jenis (Pemasukan/Pengeluaran), warna, dan ikon.

### 📈 6. Laporan & Analisis Statistik
* **Laporan Bulanan:** Rekap perbandingan pemasukan dan pengeluaran.
* **Diagram Batang Bulanan:** Visualisasi riwayat keuangan antar bulan (*Bar Chart*).
* **Rasio Tabungan:** Analisis persentase tabungan terhadap total pemasukan.

### ⚙️ 7. Pengaturan & Kustomisasi
* **Saldo Awal (*Initial Balance*):** Atur saldo awal akun sebelum pencatatan dimulai.
* **Tema Aplikasi:** Dukungan Tema Terang (*Light Mode*), Tema Gelap (*Dark Mode*), atau Ikuti Sistem.
* **Manajemen Data:** Opsi reset semua data transaksi atau hapus akun pengguna.

---

## 🛠️ Teknologi & Library

* **Framework:** [Flutter](https://flutter.dev) (Dart SDK >= 3.13.5)
* **State Management:** [Flutter Riverpod](https://riverpod.dev)
* **Navigasi & Routing:** [GoRouter](https://pub.dev/packages/go_router)
* **Backend & Database:** [Firebase Authentication](https://firebase.google.com/docs/auth) & [Cloud Firestore](https://firebase.google.com/docs/firestore)
* **Grafik & Visualisasi:** [FL Chart](https://pub.dev/packages/fl_chart)
* **Animasi & Desain:** [Flutter Animate](https://pub.dev/packages/flutter_animate), [Google Fonts](https://pub.dev/packages/google_fonts), Material Design 3
* **Penyimpanan Lokal:** `shared_preferences`

---

## 📁 Struktur Proyek

```text
lib/
├── app.dart                   # Root MaterialApp & konfigurasi tema/lokalisasi
├── firebase_options.dart      # Konfigurasi Firebase otomatis dari CLI
├── main.dart                  # Entry point aplikasi & inisialisasi layanan
├── core/                      # Modul bersama (constants, theme, router, widgets, utils)
│   ├── constants/             # Konstanta global aplikasi
│   ├── error/                 # Penanganan exception & error
│   ├── providers/             # Riverpod providers global (Firebase, Session, Prefs)
│   ├── router/                # Konfigurasi GoRouter & proteksi rute
│   ├── theme/                 # Skema warna & tema (Light & Dark)
│   ├── utils/                 # Formatter tanggal, angka, validator
│   └── widgets/               # Reusable UI widgets (Charts, Buttons, Dialogs)
└── features/                  # Modul fitur berbasis arsitektur Feature-First
    ├── auth/                  # Login, Register, Verify Email, Reset Password
    ├── budgets/               # Manajemen Anggaran Bulanan
    ├── categories/            # Pengelolaan Kategori Transaksi
    ├── dashboard/             # Halaman Utama / Beranda & Grafik
    ├── reports/               # Laporan Statistik & Analisis
    ├── settings/              # Pengaturan Profil, Tema, & Saldo Awal
    ├── splash/                # Halaman Splash Screen
    └── transactions/          # Pencatatan Transaksi (Pemasukan/Pengeluaran)
```

---

## 🚀 Panduan Setup & Instalasi

### 1. Prasyarat
Pastikan komputer Anda sudah terinstall:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi `>= 3.13.5`)
* [Android Studio](https://developer.android.com/studio) / VS Code
* Akun [Firebase](https://console.firebase.google.com/)

### 2. Clone Repositori
```bash
git clone https://github.com/dapxzhosting/DafMoney.git
cd DafMoney
```

### 3. Install Dependensi
```bash
flutter pub get
```

### 4. Konfigurasi Firebase
Aplikasi ini membutuhkan Firebase Authentication dan Cloud Firestore.

1. Buat project baru di [Firebase Console](https://console.firebase.google.com/).
2. Aktifkan **Authentication** dengan metode **Email/Password**.
3. Aktifkan **Cloud Firestore Database**.
4. Hubungkan project dengan Flutter menggunakan [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. Untuk Android, unduh file `google-services.json` dari Firebase Console dan letakkan di direktori:
   `android/app/google-services.json`

### 5. Jalankan Aplikasi
* **Mode Debug:**
  ```bash
  flutter run
  ```
* **Build APK Release:**
  ```bash
  flutter build apk
  ```

---

## 🔧 Troubleshooting & FAQ

### ❓ 1. Aplikasi Force Close / Crash saat dibuka pada Release APK
* **Penyebab:** Izin akses Internet belum terdaftar pada `AndroidManifest.xml` rilis.
* **Solusi:** Pastikan tag berikut ada di file `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```

### ❓ 2. Stuck di Halaman Splash / Logo
* **Penyebab:** Aplikasi tidak dapat terhubung ke Firebase atau file `google-services.json` belum sesuai.
* **Solusi:**
  1. Pastikan koneksi internet pada perangkat aktif.
  2. Periksa kembali konfigurasi `google-services.json` di folder `android/app/`.
  3. Cek log error asli dengan menghubungkan HP via USB dan jalankan:
     ```bash
     flutter run --release
     ```

### ❓ 3. Build Error `immutable workspace` pada Gradle
* **Penyebab:** Cache transform Gradle corrupt atau terganggu oleh antivirus saat build.
* **Solusi:** Bersihkan cache Flutter dan Gradle dengan perintah:
  ```bash
  cd android
  gradlew --stop
  cd ..
  flutter clean
  flutter pub get
  ```
  Hapus juga folder `.gradle/caches` jika diperlukan, lalu coba build ulang.

### ❓ 4. Email Verifikasi Tidak Diterima
* **Penyebab:** Email masuk ke folder *Spam* atau limit pengiriman email Firebase terlampaui.
* **Solusi:** Periksa folder *Spam/Junk* pada email Anda atau gunakan tombol **Kirim Ulang Email** pada halaman verifikasi.

---

## 📜 Aturan Keamanan Firestore (Security Rules)

Pastikan file `firestore.rules` di Firebase Console Anda dikonfigurasi agar pengguna hanya dapat membaca dan menulis data miliknya sendiri:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

---

## 📄 Lisensi

Proyek ini dibuat untuk keperluan *Open Source*. Bebas digunakan, dimodifikasi, dan dikembangkan kembali.
