# Pengujian Sistem: Pembuktian Little's Law & Amdahl's Law

Repositori ini berisi implementasi dan hasil pengujian performa server API statis untuk membuktikan Little's Law (Single Node) dan Amdahl's Law (Multi-Node dengan Load Balancer Nginx).

---

## Anggota Kelompok
1. Stefani Ayudya Prasetyo - L02240
2. Jimly Syahbatin - L0224033
3. Nadhifa Sakha Tri Yasmin - L0224036
4. Kayla Maharani Muzakki - L02240

---

## Prasyarat & Test Environment
* Runtime API: Node.js
* Alat Test: k6 (v2.2.0)
* Load Balancer: Nginx (untuk Tugas 2)
* OS Pengujian: Windows 10 / 11

---

## 📁 Struktur Repositori
```text
├── tugas-1-little-law/
│   ├── server.js          # API server port 3001
│   ├── test_little.js     # Test script k6
│   └── results/           
├── tugas-2-amdahl-law/
└── README.md
```

---

## Cara menjalankan tugas 1:
1. Pastikan Node.js dan k6 sudah terinstall
3. Jalankan 4 perintah berikut di PowerShell untuk membuat 4 file dummy
```powershell
$f = New-Object Byte[] 1024; (New-Object Random).NextBytes($f); [IO.File]::WriteAllBytes("file-1kb.bin", $f)
$f = New-Object Byte[] 102400; (New-Object Random).NextBytes($f); [IO.File]::WriteAllBytes("file-100kb.bin", $f)
$f = New-Object Byte[] 1048576; (New-Object Random).NextBytes($f); [IO.File]::WriteAllBytes("file-1mb.bin", $f)
$f = New-Object Byte[] 10485760; (New-Object Random).NextBytes($f); [IO.File]::WriteAllBytes("file-10mb.bin", $f)
```
2. Sesuaikan konstanta FILE pada server.js sesuai dengan file yang ingin dipakai
3. Run server dengan mengetik perintah "node server.js" pada terminal
4. Jalankan perintah "k6 run test_little.js" pada window terminal baru