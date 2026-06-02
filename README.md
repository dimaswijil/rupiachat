# 📱 RupiaChat - Flutter Mobile Client

Selamat datang di repositori **RupiaChat Mobile Client**. Ini adalah aplikasi *frontend* resmi untuk ekosistem RupiaChat, dibangun dengan framework **Flutter** berkinerja tinggi. Aplikasi ini didesain berinteraksi langsung dengan REST API & WebSockets dari backend RupiaChat.

## 🏗️ Arsitektur Klien (Client Architecture)

RupiaChat menggunakan pola **Layered Architecture** dengan fokus penuh pada pemisahan state, UI, dan komunikasi server.

*   **State Management:** Menggunakan **`ValueNotifier`** murni untuk menjamin performa optimal dan reaktif tanpa pustaka eksternal pihak ketiga (misalnya `themeColorNotifier` untuk mengontrol perubahan warna primer dinamis).
*   **Service Layer:** Pemanggilan API REST di-handle oleh library **Dio**, sementara *event* Real-Time (seperti notifikasi pesan baru) ditangani melalui class Service terenkapsulasi yang mengubah payload **Pusher WebSocket** menjadi **Dart Stream**.

## ✨ Fitur Utama (Core Features)

1.  **💬 Obrolan & Kolaborasi Real-Time**
    *   Komunikasi cepat 1-on-1 dan Grup.
    *   Mendukung *Typing Indicators* dan *Read Receipts* via event Pusher.
    *   Pengiriman *Voice Notes* (.m4a), Dokumen PDF, dan Gambar Resolusi Tinggi (terintegrasi dengan bucket penyimpanan Supabase).
2.  **📞 VoIP & Video Call Native**
    *   Terkoneksi dengan **Agora RTC** untuk panggilan video/suara mulus berlatensi rendah.
    *   Terkoneksi dengan **Firebase Cloud Messaging (FCM)** dan modul native **`flutter_callkit_incoming`** sehingga perangkat dapat menerima panggilan interaktif (Heads-Up) bahkan jika aplikasi tidak sedang aktif (background/terminated).
3.  **💳 Dompet Digital & Payment Gateway**
    *   Dompet saldo internal yang aman, sinkron dengan TiDB Cloud.
    *   Kemampuan isi saldo (Top-up) otomatis terhubung ke sistem **Xendit**.
    *   Konversi *live* pergerakan USD ke IDR.
4.  **👑 Toko Fitur Premium (In-App Store)**
    *   Konsep modul premium: Buka fitur-fitur eksklusif menggunakan saldo dompet (`isFeatureUnlocked`).
5.  **🎨 Tema Pro Dinamis (Pro-User Palette Mutator)**
    *   Kustomisasi warna antarmuka aplikasi secara instan (*real-time*) di-*render* ke UI melalui `ValueListenableBuilder`.

## 🛠️ Panduan Menjalankan Aplikasi (Running Locally)

1.  Pastikan **Flutter SDK** terinstal.
2.  Instal dependensi:
    ```bash
    flutter pub get
    ```
3.  Sesuaikan *environment variables* atau file konfigurasi kunci API (Firebase `google-services.json`/`GoogleService-Info.plist`, kunci Agora, URL Base REST API, dsb).
4.  Jalankan aplikasi (Gunakan emulator atau perangkat fisik Android/iOS):
    ```bash
    flutter run
    ```
