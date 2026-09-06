# Ringkasan Hasil Pengujian Tugas 2 — Amdahl's Law

**Tim:** Desain Aplikasi Big Data (Semester 5)
**Penanggung jawab (Lead Engineer: Server & Load Balancer):** Nadhifa Sakha Tri Yasmin
**Basis pekerjaan:** Tugas 1 (server.js single node, Little's Law)

---

## 1. Arsitektur yang Diuji

- **Node server:** 3 instance Node.js identik (`server.js` reuse dari Tugas 1, port dipilih via env `PORT`):
  - Node 1 → `localhost:3001`
  - Node 2 → `localhost:3002`
  - Node 3 → `localhost:3003`
- **Load Balancer:** Nginx (Docker `nginx:alpine`) di `localhost:8080`, directive `upstream` dengan **round-robin default**.
- **Beban uji:** file statis `file-10mb.bin` (10,485,760 byte), sama persis di ketiga skenario.
- **Tool beban:** k6 v2.2.0 — 50 VUs, durasi 20 s, **parameter identik** untuk semua skenario.
  - Skrip: `test_amdahl.js` (reusable, hanya upstream config nginx yang di-switch antar skenario: `nginx/nginx-scenario-{A,B,C}.conf`).

| Skenario | Node aktif di upstream Nginx | Config Nginx dipakai |
|----------|------------------------------|----------------------|
| A (1 node) | `:3001` | `nginx-scenario-A.conf` |
| B (2 node) | `:3001`, `:3002` | `nginx-scenario-B.conf` |
| C (3 node) | `:3001`, `:3002`, `:3003` | `nginx-scenario-C.conf` |

> Catatan kewajaran: pada tiap skenario **hanya node yang terdaftar di upstream yang hidup** (`start-servers.ps1` memastikan sisanya dimatikan), supaya tidak ada proses ekstra yang mencuri CPU/RAM. Tidak ada request yang gagal di semua skenario (`http_req_failed = 0`, `checks = 100%`).

---

## 2. Hasil Pengukuran (dari `k6-summary.json` tiap skenario)

| Metrik | A — 1 Node | B — 2 Node | C — 3 Node |
|---------------------------|------------|------------|------------|
| **Throughput (req/s)** | **2.43** | **2.33** | **2.32** |
| **Latency avg (s)** | 18.33 | 18.50 | 18.51 |
| Latency p90 (s) | 30.67 | 27.45 | 25.02 |
| **Latency p95 (s)** | 31.26 | 28.66 | 25.26 |
| **Latency p99 (s)** | 31.65 | 29.17 | 26.28 |
| Iterasi (request) selesai | 77 | 71 | 65 |
| **Data transferred (MB)** | 772 | 712 | 652 |
| Request gagal | 0 | 0 | 0 |

---

## 3. Interpretasi & Bukti Amdahl's Law

**Kecepatan (Speedup) dihitung dari throughput:**

```
S(2) = T(1 node) / T(2 node) = 2.43 / 2.33 = 1.04×
S(3) = T(1 node) / T(3 node) = 2.43 / 2.32 = 1.05×
```

**Apa yang terlihat:**

1. **Throughput nyaris tidak berubah** walau jumlah pemroses dinaikkan 3× lipat (2.43 → 2.32 req/s, speedup ±1.05×). Ini bukan kebetulan — sistem dibatasi oleh **porsi serial** (fraction serial `1-p`): Nginx sebagai **gerbang masuk tunggal yang berurutan** + resource **satu mesin** (CPU/RAM/memori) yang dipakai bersama semua node.
2. **Latency rata-rata mendatar** (18.33 → 18.51 s) — memperbanyak node tidak mempercepat penyelesaian satu request besar (file 10 MB harus mengalir utuh melewati Nginx → node → kembali).
3. Efek paralel yang nyata hanya terlihat pada **latency ekor (p95/p99)**: makin banyak node makin pendek antrean di tiap node (31.26 → 28.66 → 25.26 s). Paralelisme meredakan *queueing*, tapi tidak menaikkan total kapasitas karena gatekeeper (Nginx) dan mesinnya tetap satu.

**Matematika pembatas (untuk laporan Anggota 2):**

```
Amdahl: Speedup(N) = 1 / ( (1 − p) + p / N )
```

Dengan data di atas, porsi paralel teramati `p ≈ 0.07` — artinya hanya ~7% sistem ini dapat diparalelkan secara efektif; ±93% berupa porsi serial (bingkai `(1-p)`). Konsekuensinya, bahkan untuk `N → ∞`:

```
Speedup maks = 1 / (1 − p) ≈ 1 / 0.93 ≈ 1.08×
```

→ **Batas mutlak** peningkatan performa sistem ini sangat rendah karena bottleneck serialnya dominan — persis prediksi Amdahl's Law.

---

## 4. File Bukti & Struktur Hasil

```
tugas-2-amdahl-law/
├── server.js                    # 1 file untuk semua node (PORT via env)
├── start-servers.ps1            # start/stop node1..3 (3001..3003)
├── run-scenario.ps1             # otomasi: atur node → ganti config nginx → k6 run → simpan hasil
├── test_amdahl.js               # skrip k6 (50 VU, 20 s, file-10mb.bin)
├── nginx/
│   ├── nginx-scenario-A.conf    # upstream 1 node
│   ├── nginx-scenario-B.conf    # upstream 2 node
│   └── nginx-scenario-C.conf    # upstream 3 node
└── results/
    ├── skenario-1node/  → k6-summary.json + nginx-access.log (+ screenshot.png)
    ├── skenario-2node/  → k6-summary.json + nginx-access.log (+ screenshot.png)
    └── skenario-3node/  → k6-summary.json + nginx-access.log (+ screenshot.png)
```

Setiap `nginx-access.log` memakai format yang mencantumkan `$upstream_addr`, sehingga distribusi round-robin antar node dapat diverifikasi:

| Skenario | Distribusi request ke node (dari access log) |
|----------|----------------------------------------------|
| A (1 node) | 100% → `:3001` |
| B (2 node) | bergantian `:3001` ↔ `:3002` |
| C (3 node) | bergantian `:3001` ↔ `:3002` ↔ `:3003` |

---

## 5. Cara Mereplikasi

```powershell
# 1) Pastikan 3 node server jalan
.\start-servers.ps1 -Node all        # lalu cek: .\start-servers.ps1 -Status

# 2) Jalankan uji per skenario (otomatis atur node + swap config nginx + k6)
.\run-scenario.ps1 -Scenario A       # → results\skenario-1node\
.\run-scenario.ps1 -Scenario B       # → results\skenario-2node\
.\run-scenario.ps1 -Scenario C       # → results\skenario-3node\
```

> Output k6 tampil berwarna langsung di konsol; setelah run selesai script berhenti sejenak supaya dapat di-screenshot (`Win+Shift+S`) ke `results\<skenario>\screenshot.png`.

---

## 6. Lampiran: Data Mentah per Skenario

| Skenario | Throughput req/s | Latency avg s | Latency p95 s | Latency p99 s | Iterasi | Data MB | Gagal |
|----------|-----------------|---------------|---------------|---------------|---------|---------|-------|
| A | 2.43 | 18.33 | 31.26 | 31.65 | 77 | 772 | 0 |
| B | 2.33 | 18.50 | 28.66 | 29.17 | 71 | 712 | 0 |
| C | 2.32 | 18.51 | 25.26 | 26.28 | 65 | 652 | 0 |