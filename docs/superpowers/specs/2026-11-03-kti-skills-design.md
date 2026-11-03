# Design: Skills & Subagents KTI (Akademik Indonesia)

Tanggal: 2026-11-03
Status: menunggu approval

## Intent

Menambah kemampuan opencode untuk mengerjakan dokumen akademik Indonesia (KTI):
makalah, laporan, skripsi/proposal, artikel jurnal. Alur end-to-end:
riset literatur → draft → review/revisi → ekspor DOCX/PDF.

## Goals

- Skill auto-load saat user minta bantuan menulis makalah/laporan/jurnal/KTI.
- Struktur per jenis dokumen (BAB vs IMRaD), sitasi APA 7, daftar pustaka, EYD.
- Subagent untuk delegasi: riset literatur, penulisan seksi, review rubrik.
- Output: Markdown → DOCX/PDF via pandoc (tersedia di mesin). LaTeX/Typst
  tidak dipakai (tidak terinstall).

## Non-goals

- Cek plagiarisme berbayar (Turnitin/iThenticate). Hanya heuristik similarity
  lokal + self-plagiarism check.
- Integrasi Zotero/Mendeley API (belum terinstall). Output BibTeX saja.
- Menulis skripsi penuh otomatis; ini workflow asisten, bukan ghostwriter.

## Anti-goals

- Fabrikasi sitasi. **Aturan wajib: semua referensi harus nyata & verifiable**
  (DOI valid via Crossref/OpenAlex, tidak boleh dikarang).
- **Referensi harus open access**: full text bisa diakses siapa saja tanpa
  akun institut, tanpa bayar. Paywalled → jangan dipakai, atau flag ke user.
  Sumber preferensi: OpenAlex/Semantic Scholar filter `is_oa=true`, DOAJ,
  arXiv, PubMed Central, Google Scholar (link PDF gratis), Garuda Kemdikbud,
  PDF dari `.go.id`/`.ac.id`/preprint repo.
- Template fill-in-the-blank raksasa / bloat.

## Pendekatan yang dipertimbangkan

- A. **3 skill umbrella + 3 subagent** (dipilih): `academic-writing`,
  `academic-research`, `academic-review` + `academic-researcher`,
  `academic-writer`, `academic-reviewer`. Paling sedikit file, alur jelas.
- B. Banyak skill sempit (latex, docx, citation, struktur, bahasa):
  fragmentasi + overlap besar, maintenance mahal.
- C. Satu mega-skill tanpa subagent: context bloat, tidak bisa delegasi
  paralel, review tidak independen.

## Isi (keputusan)

Skills → `~/.agents/skills/` (source: `skills/`):

1. `academic-writing` — workflow & struktur per jenis KTI (laporan, makalah,
   skripsi/proposal, artikel jurnal), bahasa akademik ID (EYD, kalimat
   efektif, hedging), drafting per seksi, ekspor pandoc md→docx/pdf,
   word count.
2. `academic-research` — pencarian literatur (OpenAlex, Crossref, Semantic
   Scholar, DOAJ, arXiv, Garuda, Google Scholar via firecrawl/webfetch),
   **filter open access (is_oa) + verifikasi link full text bisa dibuka
   bebas**, screening + matriks sintesis, APA 7 in-text & daftar pustaka,
   BibTeX, cek retraction/metadata, larangan fabrikasi sitasi.
3. `academic-review` — rubrik review per bagian, checklist metodologi,
   konsistensi sitasi ↔ daftar pustaka, heuristik similarity, daftar
   revisi terprioritas.

Agents → `~/.config/opencode/agents/` (source: `agents/`):

1. `academic-researcher` — subagent, edit: deny. Cari + verifikasi sumber,
   kembalikan sintesis + metadata sitasi.
2. `academic-writer` — subagent, edit: allow. Tulis seksi berdasarkan brief
   + sumber terverifikasi.
3. `academic-reviewer` — subagent, edit: deny. Review independen + skor
   rubrik; tidak menulis ulang.

Tidak ada command `/kti` dulu (YAGNI — subagent dipanggil via task tool).

## Yang diserahkan ke builder

- Detail wording checklist & contoh.
- Skenario uji deskriptif untuk subagent (baseline tanpa skill vs dengan
  skill) — dilakukan saat menulis skill.

## Verifikasi

- Cek frontmatter semua skill & agent valid (name/description/mode).
- Copy via `setup.ps1` ke lokasi global sukses.
- Satu script check kecil di `scripts/validate-skills` (Python, stdlib) untuk
  validasi frontmatter. Parity dengan implementasi awal (Node) diverifikasi
  lewat suite sementara terhadap fixtures (CRLF, BOM, batas panjang UTF-16,
  dsb) lalu suite sementara dihapus.
