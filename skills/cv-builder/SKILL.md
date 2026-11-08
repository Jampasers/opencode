---
name: cv-builder
description: Use when the user asks to create, update, atau revisi CV/resume/daftar kerja — lamaran kerja, magang, beasiswa, fresh graduate atau berpengalaman, bahasa Indonesia atau Inggris. Triggers "bikin CV", "bikin resume", "daftar kerja", "CV saya", "lamaran", "update CV".
---

# CV Builder (PDF + DOCX + HTML, ATS-safe)

## Aturan Besi

1. **Nol fabrikasi.** Semua isi (tanggal, angka, skill, kontak) hanya dari brief
   user. Info kurang → isi placeholder `[ISI: ...]` berwarna merah, lalu
   laporkan daftar placeholder di akhir. Jangan karang pengalaman/metric.
2. **Satu bahasa** sesuai brief (ID atau EN), konsisten dari atas ke bawah.
   Istilah teknis boleh tetap EN. Bahasa campur = langsung perbaiki.
3. **Anti-slop.** Dilarang: "passionate", "berdedikasi tinggi", "hard worker",
   "cepat belajar", "tf work under pressure". Bullet pengalaman = kata kerja +
   objek konkret + angka (hanya angka yang user kasih).
4. **ATS-safe.** Satu kolom; tanpa tabel, foto, ikon, skill-bar, teks dalam
   gambar; heading standar (Pengalaman/Education/Skills); teks selectable.
5. **Panjang**: fresh graduate / < 5 tahun = 1 halaman. Maks 2 halaman.
   Kalau lebih: potong entri lama/tidak relevan, JANGAN perkecil font < 9.5pt.

## Deliverables (wajib 3 file, satu sumber)

Semua dari satu `cv.html`. Jangan bikin versi terpisah manual.

```bash
# PDF — Chrome headless (konfirmasi path Chrome dulu; fallback: msedge --headless=new)
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --no-first-run --print-to-pdf="<dir>\cv.pdf" "file:///<dir>/cv.html"

# DOCX — pandoc dari HTML yang sama (tampilan rustic tapi isi/kata tetap utuh, aman ATS)
pandoc <dir>\cv.html -o <dir>\cv.docx
```

## Alur

1. **Brief.** Butuh minimal: kontak, target posisi, pendidikan, pengalaman,
   skill. Kalau user bilang "langsung jadi", jangan bertanya — asumsikan
   wajar, catat asumsi + placeholder di laporan akhir.
2. **Isi template.** Salin `template.html` (folder skill ini) ke folder kerja
   user sebagai `cv.html`, ganti kontennya. Struktur: header → ringkasan (≤3
   kalimat) → pengalaman → pendidikan → skills. Fresh graduate boleh taruh
   proyek/organisasi di Pengalaman.
3. **Generate** `cv.pdf` + `cv.docx` di folder yang sama.
4. **Verifikasi sebelum bilang selesai:**
   - 3 file ada: `Test-Path cv.html,cv.pdf,cv.docx`
   - page count: `node -e "const s=require('fs').readFileSync('cv.pdf','latin1');console.log('pages:',(s.match(/\/Type\s*\/Page[^s]/g)||[]).length)"`
   - sisa placeholder: grep `\[ISI:` di cv.html → wajib dilaporkan ke user
   - visual: buka `file:///<dir>/cv.html` di Playwright/browser → screenshot →
     cek alignment, tidak ada teks kepotong.
5. **Laporkan** file yang jadi + daftar `[ISI:]` yang harus diisi manual.

## Kesalahan Umum

| Situasi | Jangan | Lakukan |
|---|---|---|
| Kontak belum dikasih | Isi email hayalan | Placeholder `[ISI: email]`, laporkan |
| "Buru-buru, 1 file aja" | Skip DOCX/PDF | Tetap 3 file; cepat karena template |
| Konten mepet 2 halaman | Font 8pt, margin 5mm | Buang entri paling lama |
| User minta warna-warni/2 kolom | Ikut langsung | Ingatkan risiko ATS; kalau tetap mau, buat `fancy.html` terpisah, PDF utama tetap ATS-safe |
| User minta sertakan skill yang tidak pernah disebut | Tambahkan "biar keren" | Tanyakan; kalau tak dijawab, jangan masukkan |

## Batas

Skill ini TIDAK untuk surat lamaran, portfolio website, atau LinkedIn profile —
kerjakan manual tanpa skill, atau minta skill baru dibuat.
