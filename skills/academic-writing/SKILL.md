---
name: academic-writing
description: Use when writing or structuring Indonesian academic documents — KTI, makalah, laporan, skripsi, proposal, tesis, artikel jurnal — dari outline/BAB, struktur IMRaD vs BAB, bahasa akademik (EYD, kalimat efektif, hedging), drafting per seksi, sitasi & daftar pustaka APA 7, sampai ekspor DOCX/PDF via pandoc. Triggers on "nulis makalah", "bantu skripsi", "bikin laporan", "draft jurnal".
---

# Academic Writing (KTI Indonesia)

Pasangan wajib: `academic-research` (cari & verifikasi referensi) dan
`academic-review` (review rubrik sebelum diserahkan).

## 1. Peta Jenis Dokumen → Struktur

| Jenis | Struktur baku |
| --- | --- |
| **Makalah** | Judul → Abstrak (opsional) → Pendahuluan (latar belakang, rumusan masalah, tujuan) → Pembahasan → Penutup (kesimpulan, saran) → Daftar Pustaka |
| **Laporan praktikum/penelitian** | BAB I Pendahuluan → BAB II Tinjauan Pustaka → BAB III Metode → BAB IV Hasil dan Pembahasan → BAB V Penutup → Daftar Pustaka → Lampiran |
| **Proposal skripsi/tesis** | BAB I Pendahuluan → BAB II Tinjauan Pustaka → BAB III Metode Penelitian → Daftar Pustaka (tanpa hasil) |
| **Skripsi/tesis** | BAB I–V (sama seperti laporan) + Lampiran |
| **Artikel jurnal** | Abstrak (ID + EN, 150–250 kata, memuat tujuan-metode-hasil-kesimpulan) → Pendahuluan → Metode → Hasil dan Pembahasan → Kesimpulan → Daftar Pustaka |

Kalau kampus memberi template/panduan, template kampus menang. Tanyakan file
template sebelum menulis.

## 2. Bahasa Akademik

- **EYD/PUEBI**: "di" sebagai kata depan dipisah, "di-" sebagai awalan
  disambung; "praktik" (bukan "praktek"); "analisis" (bukan "analisa");
  "metode" bukan "metoda".
- **Kalimat efektif**: satu gagasan per kalimat, maksimal ±25 kata, hindari
  kalimat pasif berlapis dan kata mubazir ("sangat", "sangatlah", "di mana"
  sebagai penghubung).
- **Hedging**: klaim didukung bukti — "menunjukkan", "mengindikasikan",
  "cenderung", "berpotensi"; hindari "terbukti mutlak" tanpa data.
- **Orang pertama**: hindari "saya"; "penulis" atau bentuk impersonal.
  "Kami" hanya untuk penelitian tim.
- **Konsistensi istilah**: pilih satu istilah (mis. "machine learning" atau
  "pembelajaran mesin"), jangan campur.
- **Paragraf**: 1 gagasan utama, 5–10 kalimat; kalimat topik di awal.

## 3. Proses Menulis

1. **Tanya dulu** (singkat): jenis dokumen, institusi/template, panjang
   (halaman/kata), bahasa, deadline, data yang sudah ada.
2. **Outline** — susun kerangka per BAB/seksi; minta persetujuan user
   sebelum menulis penuh. Outline untuk dokumen panjang (>10 halaman) wajib.
3. **Draft per seksi** — tulis satu seksi per iterasi; jangan menulis 5 BAB
   sekaligus tanpa dicek.
4. **Sitasi** — setiap klaim faktual/angka/kebijakan butuh sumber dari
   `academic-research`. Tidak ada sumber terverifikasi → tandai `[SITASI?]`,
   jangan dikarang.
5. **Review** — jalankan `academic-review` sebelum menyerahkan.
6. **Ekspor** (bagian 5).

Aturan mutlak: **tidak ada referensi karangan**. Referensi hanya dari hasil
`academic-research` yang sudah diverifikasi (DOI resolve + full-text OA).

## 4. Sitasi dan Daftar Pustaka

- Gaya default: **APA 7**. In-text: `(Liakos et al., 2018)`; dua penulis
  `(A & B, 2021)`; di prosa Indonesia: "Liakos dkk. (2018)".
- Entri daftar pustaka: `Penulis, A. B., & Penulis, C. (Tahun). Judul. Nama Jurnal, Volume(Nomor), halaman. https://doi.org/...`
- Urut alfabetis, hanging indent 0,5 inci, DOI sebagai URL utuh.
- Sitasi in-text dan entri daftar pustaka harus 1:1 — dicek oleh
  `academic-review`.

## 5. Ekspor DOCX/PDF (pandoc)

**Gaya visual default = polos total.** Times New Roman 12pt, spasi 1,5, teks
hitam (tanpa biru/aksen warna), heading hitam bold. Jangan pernah pakai style
default pandoc/Word apa adanya. Warna, font dekoratif, atau tema khusus hanya
kalau user minta eksplisit — dan tanyakan dulu detailnya.

```bash
# Markdown -> DOCX. Prioritas: template kampus > reference-polos (bawaan skill ini)
pandoc naskah.md -o naskah.docx --reference-doc=template-kampus.docx
pandoc naskah.md -o naskah.docx --reference-doc="$env:USERPROFILE\.agents\skills\academic-writing\reference-polos.docx"

# HTML (kalau user minta preview/browser): CSS hitam-putih minimal,
# heading bold hitam, tanpa warna aksen, font serif akademik

# DOCX -> PDF: buka di Word/LibreOffice, Save as PDF (mesin ini tanpa LaTeX)
# PDF langsung dari pandoc hanya jika ada pdf-engine (tidak ada di mesin ini)

# Hitung kata (PowerShell)
(pandoc naskah.md -t plain | Measure-Object -Word).Words
```

Headings markdown (`#`, `##`) menjadi Heading 1/2 di DOCX — atur penomoran
BAB lewat template kampus atau tulis manual ("BAB I PENDAHULUAN").

## 6. Checklist Akhir Naskah

- [ ] Struktur sesuai jenis dokumen + template kampus.
- [ ] Abstrak memuat tujuan, metode, hasil, kesimpulan (untuk jurnal).
- [ ] Setiap klaim faktual punya sitasi; tidak ada `[SITASI?]` tersisa.
- [ ] Semua referensi terverifikasi & open access (`academic-research`).
- [ ] Format APA 7 konsisten; in-text ↔ daftar pustaka 1:1.
- [ ] Bahasa: EYD, kalimat efektif, istilah konsisten.
- [ ] Sudah di-review dengan `academic-review` dan revisi diterapkan.
