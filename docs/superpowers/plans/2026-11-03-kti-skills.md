# Skills & Subagents KTI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambah 3 skill + 3 subagent untuk workflow KTI Indonesia (makalah, laporan, skripsi, jurnal) dengan aturan wajib: referensi nyata, verifiable, dan open access.

**Architecture:** Skill markdown di `skills/<name>/SKILL.md` (auto-discover via `~/.agents/skills/`), agent markdown di `agents/<name>.md` (via `~/.config/opencode/agents/`), keduanya dikopi `setup.ps1` (sudah ada, tidak diubah). Validator Python stdlib murni di `scripts/validate-skills` memaksa kontrak frontmatter + aturan open access secara mekanis. Tidak ada perubahan `opencode.jsonc`.

**Tech Stack:** Markdown skills/agents (opencode format), Node stdlib (`node`, `assert`, `fs`), OpenAlex/Crossref API via webfetch untuk verifikasi referensi.

**Spec:** `docs/superpowers/specs/2026-11-03-kti-skills-design.md`

## Global Constraints

- Folder = name; `name` lowercase-hyphen (academic-writing, academic-research, academic-review); `description` ≤ 1024 char, third person, diawali "Use when", front-load keyword Indonesia: makalah, laporan, skripsi, KTI, jurnal, daftar pustaka, sitasi.
- Bahasa konten skill: Indonesia (istilah teknis boleh English).
- Subagent: `mode: subagent`; `academic-researcher` & `academic-reviewer` → `edit: deny`; `academic-writer` → edit allow.
- Aturan anti-fabrikasi + open-access-only (user requirement, verbatim dari spec): semua referensi harus nyata & verifiable (DOI valid); full text harus bisa diakses siapa saja tanpa akun institut/tanpa bayar; paywalled → jangan dipakai atau flag ke user.
- Tanpa dependency baru; tanpa konfigurasi baru; tanpa command baru.
- Tidak ada commit kecuali user minta.

## Review Focus

1. API riset tak terjangkau (offline/rate-limit) → subagent harus balik "tidak terverifikasi", bukan menebak DOI. Dipin oleh smoke test anti-fabrikasi (Task 2).
2. Paper paywalled lolos ke daftar pustaka → skill wajib cek link full-text gratis sebelum lolos; dipin oleh test "open access" di validator (Task 1/2).
3. Skill tidak trigger untuk permintaan bahasa Indonesia → validator mensyaratkan keyword "makalah"/"daftar pustaka" di description (Task 1).
4. Frontmatter invalid (opencode diam-diam skip skill) → validator cek name match folder, description ≥ 40 char & ≤ 1024, `mode: subagent` (Task 1).
5. Format sitasi tidak konsisten (APA 7 campur gaya lain) → aturan APA 7 ada di body skill `academic-review` (bagian 3); smoke test Task 6 memverifikasi format output rubrik, bukan pin mekanis validator.

---

### Task 1: Validator kontrak skills & agents

**Files:**
- Create: `scripts/validate-skills`

**Interfaces:**
- Produces: `python scripts/validate-skills` → exit 0 bila semua kontrak valid; exit 1 dengan daftar pelanggaran. Konstanta kontrak di dalam `scripts/`: `EXPECTED_SKILLS = ['academic-writing', 'academic-research', 'academic-review']`, `EXPECTED_AGENTS = [{ file: 'academic-researcher.md', edit: 'deny' }, { file: 'academic-writer.md', edit: 'allow' }, { file: 'academic-reviewer.md', edit: 'deny' }]` (jalur dari root repo: `skills/`, `agents/`).

- [ ] **Step 1: Write the failing check (script)**

`scripts/validate-skills` (Python 3, stdlib saja — `re`, `sys`, `pathlib`):
- Untuk tiap skill di `EXPECTED_SKILLS`: `skills/<dir>/SKILL.md` ada; frontmatter antara dua `---` mengandung `name: <dir>` (persis = nama folder), `description:` dengan panjang 40–1024 char; description mengandung kata `makalah` dan (untuk academic-research & academic-writing) `daftar pustaka`.
- Untuk tiap skill: `academic-research` body mengandung `OpenAlex` dan `open access` (case-insensitive) — pin aturan open access.
- Untuk tiap agent di `EXPECTED_AGENTS`: `agents/<file>` ada; frontmatter mengandung `mode: subagent`, blok `permission` dengan `edit: <nilai sesuai konstanta>`, dan `description:` ≥ 40 char.
- Untuk `academic-researcher.md`: body mengandung `open access` (case-insensitive).
- Satu `assert` per aturan, pesan menyebut file & aturan yang gagal.

- [ ] **Step 2: Run, verify it fails (RED)**

Run: `python scripts/validate-skills`
Expected: FAIL — "skills/academic-writing/SKILL.md: file tidak ada" (atau setara).

---

### Task 2: Skill `academic-research` (inti anti-fabrikasi + open access)

**Files:**
- Create: `skills/academic-research/SKILL.md`

**Interfaces:**
- Consumes: tidak ada.
- Produces: skill nama `academic-research`; section skill: (1) alur riset literatur, (2) API open access + endpoint contoh, (3) format sitasi APA 7 + BibTeX, (4) matriks sintesis, (5) aturan jangan-fabrikasi. Dipakai Task 5 (agent academic-researcher) dan smoke test Task 6.

- [ ] **Step 1: Baseline (RED) — subagent tanpa skill**

Dispatch `task`/`general` dengan prompt: "Cari 3 referensi tentang machine learning pertanian untuk daftar pustaka KTI, format APA 7." TANPA menyertakan skill apa pun. Dokumentasikan verbatim apakah DOI berkarang / sumber paywalled (verifikasi cepat 1–2 DOI via `https://api.crossref.org/works/<doi>` atau OpenAlex `https://api.openalex.org/works?filter=doi:...`). Catat hasil di catatan task, bukan file.

- [ ] **Step 2: Write skill (GREEN) dengan frontmatter pin ini**

```yaml
---
name: academic-research
description: Use when a KTI/makalah/skripsi/jurnal needs literature research — cari referensi, daftar pustaka, sitasi APA 7, BibTeX, literature review. Enforces real, verifiable, OPEN ACCESS-ONLY references (no paywall, no fabricated DOI) via OpenAlex, Crossref, Semantic Scholar, DOAJ, arXiv, Garuda. Triggers on "cari referensi", "daftar pustaka", "sitasi", "review literatur".
---
```

Body (Indonesia) mencakup dan WAJIB memuat aturan:
1. **Anti-fabrikasi**: setiap referensi harus diverifikasi via API (contoh endpoint: `https://api.openalex.org/works?search=...&filter=is_oa:true`, `https://api.doaj.org/api/search/articles/...`, `https://api.semanticscholar.org/graph/v1/paper/search?openAccessPdf=`, `https://export.arxiv.org/api/query`) sebelum masuk draft; API gagal → tulis "tidak terverifikasi", JANGAN menebak.
2. **Open access only**: hanya sumber dengan full-text bebas (is_oa, PDF publik, Garuda kemdikbud, `.ac.id`/`.go.id`); paywalled → jangan dipakai atau titik-flag ke user.
3. Alur riset: definisikan pertanyaan riset → kata kunci (ID+EN) → search OA → screening (relevansi, retracted check) → matriks sintesis (kolom: sumber, temuan, metode, gap).
4. Sitasi: contoh APA 7 in-text (Penulis, tahun) & contoh entri daftar pustaka + padanan BibTeX (`@article`).
5. Cek utang sitasi: setiap klaim faktual di draft hook ke sumber.

- [ ] **Step 3: Re-run baseline scenario DENGAN skill**

Skenario sama, konten `SKILL.md` di-paste ke prompt subagent. Expected: subagent memanggil API OA, mengembalikan referensi ber-DOI yang memang resolve, tidak ada yang paywalled. Parent verifikasi 1–2 DOI.

- [ ] **Step 4: Run validator skill ini**

Run: `python scripts/validate-skills`
Expected: academic-research lolos (task lain masih merah, boleh).

---

### Task 3: Skill `academic-writing`

**Files:**
- Create: `skills/academic-writing/SKILL.md`

**Interfaces:**
- Consumes: convention nama file/folder dari Task 1.
- Produces: skill `academic-writing` dengan panduan mencari sumber mengarah ke `academic-research`.

- [ ] **Step 1: Write skill**

Frontmatter pin:

```yaml
---
name: academic-writing
description: Use when the user asks for help writing Indonesian academic documents — KTI, makalah, laporan, skripsi, proposal, tesis, artikel jurnal — dari outline/BAB, struktur IMRaD vs BAB, bahasa akademik (EYD, kalimat efektif, hedging), drafting per seksi, sampai ekspor DOCX/PDF via pandoc. Triggers on "nulis makalah", "bantu skripsi", "bikin laporan", "draft jurnal".
---
```

Body (Indonesia): (1) peta jenis dokumen → struktur (makalah/laporan: BAB; skripsi/tesis: BAB; artikel jurnal: IMRaD/Abstrak-ID-EN); (2) aturan bahasa akademik & EYD, hedging, hindari kata ganti orang-1; (3) proses drafting per seksi + prompt-anda ke user (tujuan, kampus/template, panjang); (4) setiap klaim faktual harus punya sumber dari `academic-research` — tanpa sumber terverifikasi, tandai `[SITASI?]`; (5) ekspor `pandoc <file>.md -o <file>.docx` / `-o pdf` (tanpa LaTeX; fallback docx→pdf via Word kalau ada); (6) jumlah kata per jenis.

- [ ] **Step 2: Run validator**

Run: `python scripts/validate-skills`
Expected: academic-writing lolos.

---

### Task 4: Skill `academic-review`

**Files:**
- Create: `skills/academic-review/SKILL.md`

**Interfaces:**
- Consumes: convention Task 1.
- Produces: format output review: tabel temuan (lokasi, masalah, severity, saran fix) + skor rubrik 1–5.

- [ ] **Step 1: Write skill**

Frontmatter pin:

```yaml
---
name: academic-review
description: Use when reviewing, checking, or revising Indonesian academic documents (KTI, makalah, laporan, skripsi, jurnal) — rubrik review per BAB/seksi, konsistensi sitasi dengan daftar pustaka, cek metodologi, cek referensi open-access & verifiable, heuristik parafrase/similarity. Triggers on "review makalah", "cek daftar pustaka", "revisi skripsi", "periksa jurnal".
---
```

Body (Indonesia): (1) rubrik 6 dimensi skor 1–5 (argumentasi, metodologi, sitasi, bahasa/EYD, struktur, konsistensi format); (2) checklist konsistensi: setiap sitasi in-text ada di daftar pustaka & sebaliknya, format APA 7 seragam, tahun/nama cocok dengan sumber (verifikasi via API bila diragu); (3) cek tipe sumber (open access, kalau tidak → flag); (4) heuristik similarity lokal (bidang frasa ≥ 7 kata sama berturutan vs sumber → tampilkan); (5) output: tabel temuan prioritas + daftar revisi. Format output fix: verbatim tabel.

- [ ] **Step 2: Run validator**

Run: `python scripts/validate-skills`
Expected: ketiga skill lolos; agent masih merah.

---

### Task 5: Subagent riset-tulis-review

**Files:**
- Create: `agents/academic-researcher.md`
- Create: `agents/academic-writer.md`
- Create: `agents/academic-reviewer.md`

**Interfaces:**
- Consumes: kontrak validator Task 1 (mode/permission).
- Produces: 3 subagent yang bisa dipanggil parent-tool `task` dengan prompt brief; output terstruktur (researcher: daftar referensi terverifikasi + ringkasan; output reviewer: tabel temuan+skor).

- [ ] **Step 1: Write 3 agent files**

Common frontmatter (via YAML):

`agents/academic-researcher.md`:
```yaml
---
description: Mencari & memverifikasi literatur open access untuk KTI — temukan referensi nyata via OpenAlex/Crossref/DOAJ/Semantic Scholar/arXiv/Garuda, verifikasi full-text bebas, balas rujukan APA 7. Mode riset saja, tidak mengedit file.
mode: subagent
permission:
  edit: deny
  bash: ask
---
```
 Body: role + prinsip (carilah hanya open access; verifikasi tiap DOI; API gagal → laporkan tidak terverifikasi; jangan pernah mencari referensi yang tidak diverifikasi) + format balasan (tabel: APA 7, DOI/URL, jenis akses, temuan singkat, gap).

`agents/academic-writer.md`: sama bentuk; `edit: allow`; body: tulis seksi dari brief + sumber terverifikasi dari academic-research; tanpa klaim tanpa sitasi; gaya akademik EYD; flag `[SITASI?]` bila sumber kurang.

`agents/academic-reviewer.md`: `edit: deny`; body: review independen memakai format output rubrik dari `academic-review`; jangan menulis ulang; verdict + tabel temuan.

- [ ] **Step 2: Run validator**

Run: `python scripts/validate-skills`
Expected: PASS semua (exit 0).

---

### Task 6: Pasang live + smoke test aplikasi (writing & review)

**Files:**
- Modify: tidak ada file repo; menyalin ke lokasi global.

- [ ] **Step 1: Copy via setup yang sudah ada**

Run PowerShell (subset setup.ps1):
`Copy-Item ".\skills\*" "$env:USERPROFILE\.agents\skills\" -Recurse -Force`
`Copy-Item ".\agents\*" "$env:USERPROFILE\.config\opencode\agents\" -Recurse -Force`
Expected: output sukses, exit 0.

- [ ] **Step 2: Smoke test aplikasi (writing + review)**

Dispatch `task`/`general` dengan konten skill academic-writing + academic-review di-paste, prompt: "Review draf berikut (2 paragraf) dengan format rubrik dari skill ini" — lampirkan 2 paragraf draf contoh di dalam prompt. Expected: output format tabel rubrik (lokasi/masalah/severity/saran). Kalau tidak sesuai format, perbaiki wording skill body dan ulang sekali.

- [ ] **Step 3: Lint all + final check**

Run: `python scripts/validate-skills`
Expected: exit 0.

- [ ] **Step 4: Commit (hanya jika user minta)**

```bash
git add skills/academic-* agents/academic-* scripts/validate-skills docs/
git commit -m "config: add KTI academic skills + subagents (open-access enforcement)"
```

---

## Self-Review

- Spec coverage: 3 skill + 3 agent + open-access/anti-fabrikasi + ekspor pandoc + validator — semua ada task; non-goals (Zotero, Turnitin, LaTeX) tidak dibangun.
- Step scan: tiap langkah satu aksi/checkable; frontmatter dipin verbatim; validator concretely assert-based.
- Type consistency: nama skill/agent konsisten di konstanta, frontmatter, dan bahasa prompt Task 6.
- Review Focus: 3 dari 5 failure mode dipin mekanis oleh validator; 1 (anti-fabrikasi) dipin lewat smoke test subagent Task 2; 1 (APA 7) dipin lewat body skill + smoke test Task 6.
- Proportion: panjang plan ≈ spec; konten body skill didescribe, tidak ditulis penuh (yang menentukan only frontmatter + struktur aturan wajib).
