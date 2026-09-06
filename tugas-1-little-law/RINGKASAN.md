# Ringkasan Hasil Pengujian Tugas 1: Little's Law

## 1. Tujuan

Membuktikan teori Little's Law ($L = \lambda \times W$) pada server web statis Node.js (Single Node) menggunakan beban (Virtual Users/VU) yang mensimulasikan antrean pelanggan dalam sebuah sistem.

- **$L$** = Jumlah rata-rata pelanggan dalam sistem (dalam pengujian ini dikunci pada **50 VU**)
- **$\lambda$ (Lambda)** = Tingkat kedatangan/penyelesaian rata-rata (diwakili oleh metrik **Throughput** / *req per second*)
- **$W$** = Waktu rata-rata yang dihabiskan dalam sistem (diwakili oleh metrik **Latency Avg** dalam satuan detik)

---

## 2. Tabel Rekapitulasi Data dan Perhitungan

Berdasarkan hasil pengujian dengan `k6` menggunakan 50 Virtual Users selama 20 detik, berikut adalah pembuktian perkalian Throughput dan Latency:

| Skenario Ukuran File | Jumlah Pelanggan / VU ($L$) | Throughput / req per detik ($\lambda$) | Latency Avg ($W$) | Perhitungan$\lambda \times W$ (Bukti Little's Law) |               |                                             |
| -------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ------------- | ------------------------------------------- |
| **1 KB**       | 50                                                                                             | 5087.22                                              | 0.00974 detik | $5087.22 \times 0.00974 = \mathbf{49.55}$ |
| **100 KB**     | 50                                                                                             | 3320.04                                              | 0.01493 detik | $3320.04 \times 0.01493 = \mathbf{49.56}$ |
| **1 MB**       | 50                                                                                             | 1005.06                                              | 0.04943 detik | $1005.06 \times 0.04943 = \mathbf{49.68}$ |
| **10 MB**      | 50                                                                                             | 142.78                                               | 0.34703 detik | $142.78 \times 0.34703 = \mathbf{49.55}$  |

*Catatan: Konversi Latency rata-rata diubah dari milidetik / ms menjadi detik / s*

---

## 3. Kesimpulan Analisis

Dari tabel di atas, dapat dilihat bahwa hasil perkalian antara **Throughput ($\lambda$)** dan **Latency ($W$)** di semua skenario uji beban file selalu stabil menghasilkan angka di kisaran **~49.5**.

Angka ini sangat mendekati nilai konstanta *Virtual Users* yang disimulasikan sebagai jumlah pelanggan, yaitu **50**. Adanya sedikit selisih (sekitar ~0.5) wajar terjadi dalam skenario *benchmark* jaringan karena adanya latensi tambahan di level protokol (TCP/OS).

Dengan demikian, data riil dari sistem Node.js ini **berhasil membuktikan** secara akurat berlakunya teori sistem antrean antrean **Little's Law**.
