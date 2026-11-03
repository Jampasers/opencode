---
name: academic-review
description: Use when reviewing, checking, or revising Indonesian academic documents (KTI, makalah, laporan, skripsi, jurnal) — rubrik review per BAB/seksi, konsistensi sitasi dengan daftar pustaka, cek metodologi, cek referensi open-access & verifiable, heuristik parafrase/similarity. Triggers on "review makalah", "cek daftar pustaka", "revisi skripsi", "periksa jurnal".
---

# Academic Review (KTI Indonesia)

Review ≠ menulis ulang. Reviewer hanya memberi temuan + saran; penulis yang
memutuskan.

## 1. Prosedur

1. Baca naskah utuh dulu, jangan komentar per kalimat di awal.
2. Nilai 6 dimensi di bawah (skor 1–5), kumpulkan temuan dengan **lokasi
   konkret** (BAB/seksi/paragraf/kutipan singkat).
3. Jalankan checklist konsistensi sitasi & heuristik similarity.
4. Keluarkan output **persis format bagian 4** (tabel temuan + skor +
   verdict), lalu daftar revisi prioritas.

## 2. Rubrik (skor 1–5)

| Dimensi | 5 | 3 | 1 |
| --- | --- | --- | --- |
| Argumentasi | Alur klaim→bukti konsisten, kontra-argumen dibahas | Argumen jalan tapi ada klaim tanpa dukungan | Klaim melompat, tanpa data |
| Metodologi | Metode sesuai rumusan masalah, prosedur dapat direplikasi | Metode disebut tapi detail kurang | Metode tidak relevan/abu-abu |
| Sitasi & referensi | APA 7 konsisten, semua rujukan terverifikasi & OA | Ada inkonsistensi kecil / 1–2 rujukan tidak dicek | Rujukan tak jelas / tidak terverifikasi |
| Bahasa (EYD) | EYD benar, kalimat efektif, istilah konsisten | Salah ejaan/kalimat berkala tapi terbaca | Banyak pelanggaran yang mengganggu makna |
| Struktur | Lengkap sesuai jenis dokumen, proporsional | Ada bagian kurang/timpang porsi | Struktur tidak sesuai kaidah |
| Konsistensi format | Margin, penomoran, heading, tabel seragam | Sedikit variasi | Format campur aduk |

## 3. Cek Sitasi & Referensi (wajib)

- Setiap sitasi in-text ada entri daftar pustaka — dan sebaliknya (1:1).
- Format APA 7 seragam (urutan penulis, tahun, italic, DOI).
- Nama + tahun di in-text cocok dengan entri; jika ragu, verifikasi metadata
  via API (`https://api.crossref.org/works/<doi>`, OpenAlex `doi:`).
- **Referensi open access**: bila entri paywalled/tidak ada link gratis,
  tandai sebagai temuan — aturan proyek: rujukan harus diakses siapa saja.
- Cek retracted (OpenAlex `is_retracted`) untuk rujukan utama.

## 4. Heuristik Similarity (tanpa Turnitin)

- Frasa ≥7 kata identik berturutan dengan sumber → tandai.
- Paragraf dengan struktur + istilah hampir identik → indikasi copy-paste.
- Parafrase dangkal (hanya ganti sinonim) → saran parafrase ulang + sitasi.
- Laporkan sebagai **indikasi**, bukan vonis plagiarisme; sarankan cek resmi
  bila perlu.

## 5. Format Output (verbatim)

**Verdict:** [Siap / Siap dengan revisi / Perlu revisi besar]

| Lokasi | Masalah | Severity | Saran |
| --- | --- | --- | --- |
| BAB II hal. 5 | Sitasi (Sari, 2019) tidak ada di daftar pustaka | Kritis | Tambah entri APA 7 |
| BAB IV hal. 12 | Rujukan IEEE paywalled | Mayor | Ganti dengan sumber OA |

**Skor rubrik:**

| Dimensi | Skor (1–5) | Catatan |
| --- | --- | --- |
| Argumentasi | 4 | |
| Metodologi | 3 | Detail sampling kurang |
| Sitasi & referensi | 2 | 3 rujukan tak terverifikasi |
| Bahasa (EYD) | 4 | |
| Struktur | 5 | |
| Konsistensi format | 4 | |

**Revisi prioritas (urut):** 1) … 2) … 3) …

Severity: **Kritis** = membatalkan keabsahan (rujukan tidak ada/dikarang,
data tanpa sumber); **Mayor** = melemahkan substansi; **Minor** = kosmetik.
