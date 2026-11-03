---
name: academic-research
description: Use when a KTI/makalah/skripsi/jurnal needs literature research — cari referensi, daftar pustaka, sitasi APA 7, BibTeX, literature review. Enforces real, verifiable, OPEN ACCESS-ONLY references (no paywall, no fabricated DOI) via OpenAlex, Crossref, Semantic Scholar, DOAJ, arXiv, Garuda. Triggers on "cari referensi", "daftar pustaka", "sitasi", "review literatur".
---

# Academic Research (KTI Indonesia)

## Aturan Besi

1. **Nol fabrikasi.** Setiap referensi harus nyata dan bisa diverifikasi lewat
   API/DOI sebelum masuk draft. Jangan pernah menebak judul, tahun, volume,
   halaman, atau DOI dari ingatan. Kalau tidak bisa diverifikasi: tulis
   `[TIDAK TERVERIFIKASI]` dan jangan pakai sebagai rujukan.
2. **Open access only.** Full text harus bisa dibuka siapa saja: tanpa akun
   institusi, tanpa langganan, tanpa bayar. Sumber paywalled → jangan dipakai
   (atau tandai `[PAYWALL]` dan tanya user apakah punya akses legal).
3. **Sumber yang dibaca, bukan yang terlihat keren.** Prioritaskan rujukan
   yang isinya benar-benar diambil (abstrak minimal), bukan sekadar metadata.
4. **API mati/rate-limit?** Laporkan apa adanya: "pencarian gagal, referensi
   tidak terverifikasi". Jangan isi kekosongan dengan tebakan.

## Alur Riset

1. **Rumuskan pertanyaan** — pecah topik jadi 2–4 klaim yang butuh rujukan.
2. **Kata kunci** — susun padanan Indonesia + Inggris (istilah akademik
   sering lebih banyak tersedia dalam EN).
3. **Cari di sumber OA** (endpoint di bawah), filter `is_oa` / `openAccessPdf`.
4. **Screening** — baca abstrak; buang yang tidak relevan, retracted, atau
   predatorik; cek tahun (utamakan 5–10 tahun terakhir kecuali klasik).
5. **Verifikasi** — pastikan DOI resolve dan ada link full-text gratis.
6. **Sintesis** — isi matriks (bawah), bukan sekadar daftar.
7. **Sitasi** — format APA 7; sertakan BibTeX bila diminta.

## Endpoint Open Access (contoh siap pakai)

```bash
# OpenAlex — filter open access, cari judul/abstrak (paling cepat)
# https://api.openalex.org/works?search=KATA+KUNCI&filter=is_oa:true&per-page=10
node -e "fetch('https://api.openalex.org/works?search=machine%20learning%20pertanian&filter=is_oa:true&per-page=5').then(r=>r.json()).then(d=>d.results.forEach(w=>console.log(w.title,'|',w.publication_year,'|',w.doi,'|',(w.best_oa_location&&w.best_oa_location.pdf_url)||'no pdf')))"

# Crossref — verifikasi DOI (404 = DOI tidak ada / jangan dipakai)
# https://api.crossref.org/works/10.3390/s18082674

# Semantic Scholar — cari paper + PDF OA
# https://api.semanticscholar.org/graph/v1/paper/search?query=KATA+KUNCI&fields=title,year,externalIds,openAccessPdf&limit=5

# DOAJ — jurnal OA terindeks (bagus untuk cek kualitas jurnal)
# https://api.doaj.org/api/search/articles/KATA+KUNCI

# arXiv — preprint (fisika/CS/math; bukan peer-review, tandai jenisnya)
# https://export.arxiv.org/api/query?search_query=all:KATA+KUNCI&max_results=5

# Garuda (Kemdikbud) — artikel jurnal Indonesia, akses via web search
# https://garuda.kemdikbud.go.id/ → firecrawl/webfetch "site:garuda.kemdikbud.go.id KATA KUNCI"
```

Jurnal Indonesia sering juga punya PDF bebas di domain `.ac.id` / `.go.id` /
e-journal kampus: cek link sebelum menyatakannya OA.

## Verifikasi Wajib Sebelum Menulis Referensi

1. DOI resolve di Crossref/OpenAlex — kalau tidak: buang.
2. Ada URL full-text gratis (`pdf_url`, `oa_url`, atau PDF resmi) — kalau
   tidak: jangan dipakai sebagai referensi inti.
3. Metadata cocok dengan klaim yang dikutip (judul, tahun, penulis).
4. Bukan retracted (OpenAlex `is_retracted`, atau cek di situs jurnal).
5. **OpenAlex kadang salah flag** `is_oa` (record duplikat/stale) padahal
   jurnalnya gold OA (MDPI, Frontiers, PLOS…). Kalau `best_oa_location.pdf_url`
   atau PMC link menunjuk full-text bebas jurnal yang memang OA, percayai
   link-nya; bila masih ragu, buka link-nya sendiri sebelum menutup kesimpulan.

## Format Sitasi APA 7

- In-text: `(Kamilaris & Prenafeta-Boldú, 2018)` / `Kamilaris dan Prenafeta-Boldú (2018)` di prosa Bahasa Indonesia.
- Daftar pustaka: `Penulis, A. B., & Penulis, C. (Tahun). Judul artikel. Nama Jurnal, Volume(Nomor), halaman. https://doi.org/xxxx`
- BibTeX:

```bibtex
@article{kamilaris2018deep,
  title   = {Deep learning in agriculture: A survey},
  author  = {Kamilaris, Andreas and Prenafeta-Boldu, Francesc X.},
  journal = {Computers and Electronics in Agriculture},
  volume  = {147},
  pages   = {70--90},
  year    = {2018},
  doi     = {10.1016/j.compag.2018.02.016}
}
```

Sumber OA saja tidak cukup: kalau sitasi in-text dibuat, pastikan entri daftar
pustaka memakai data hasil verifikasi, bukan hafalan.

## Matriks Sintesis

| Sumber (APA) | Jenis | Metode | Temuan kunci | Relevansi ke argumen | Akses |
| --- | --- | --- | --- | --- | --- |
| Liakos et al. (2018) | Review | Tinjauan 40+ studi ML | ML unggul untuk prediksi hasil panen | Dasar klaim adopsi ML | OA (MDPI) |

Satu baris per sumber; kolom "Akses" wajib: `OA` + link, atau `PAYWALL`.

## Checklist Akhir

- [ ] Tidak ada referensi tanpa hasil pencarian/verifikasi API.
- [ ] Semua entri punya DOI/URL yang resolve.
- [ ] Semua entri punya full-text gratis (kalau tidak → flag ke user).
- [ ] In-text ↔ daftar pustaka konsisten, format APA 7 seragam.
- [ ] Matriks sintesis terisi, bukan cuma daftar.
- [ ] Laporan jujur bila ada pencarian yang gagal.
