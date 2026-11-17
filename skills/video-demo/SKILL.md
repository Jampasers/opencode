---
name: video-demo
description: Use when the user asks for a demo video, product video, walkthrough, screencast, tutorial video, screen recording of an app or of a URL, hero or landing-page footage, app screenshots for a website, "show off this feature", "record a demo of <url>", or wants to add, re-film, re-narrate, or fix a demo scene — for web apps filmed from a repo or a live URL, with visible cursor, natural pacing, and professional feel.
origin: merged from video-demo, ui-demo
---

# Video Demo

`scripts/demo` films a web app and writes `demo-out/` into that project's workspace: per scene an mp4 with voice-over, a poster, retina stills, plus `full-tour.mp4`, `manifest.json` and `index.html`. All local. The engine runs from this skill; nothing is installed into the app being filmed. When recording without the engine, use the hand-rolled Playwright recipe at the end.

## Non-negotiables

Each of these cost a run or a user's patience.

1. **A pinned build, never a dev server.** Its module graph belongs to whoever is editing source. Copy it somewhere private and verify its API base by reading the bundle. A URL with no repo behind it is `site` mode; a URL on localhost is a dev server and is never filmed.
2. **In `build` mode, mock every request in-process and pin the clock.** A corpus gets published, and a real account publishes real people's addresses. `site` mode trades both away knowingly: public pages only.
3. **Own your port and output directory.** The studio refuses to adopt a server it did not start. Never `pkill` by pattern.
4. **1080p60 video, 2x stills.** They are separate settings. 4K video judders because throughput is a fixed pixels-per-second budget.
5. **Do the gesture, then narrate while pushed in on the result.** One subject per line. Never narrate before the subject exists. Where the app has its own timer — an undo window, a toast — the gesture goes inside it and the words after, or the film shows a feature that does not work.
6. **One scene, then stop and ask** (step 8). It caught four defects before twenty-six more scenes were filmed.
7. **Read the PNG, every time.** A scene that passes while framing the wrong thing is a failure, and only an eye on the still catches it.
8. **Nothing is final until they say so.** Any note about the words, the framing, the pace, what is covered or the voice is a re-film, not a negotiation: change it and film it again. They cannot see what you can, so "too long", "zoom in more" and "stop zooming so much" are all complete instructions, and a scene is cheap to shoot twice.

## Workflow

1. **Pick the mode from what you were given. Do not ask.** An http(s) URL on a public host is `site`, workspace `~/.video-demo/<host>/`. A URL on localhost or a private address is a dev server: find the repo behind it and treat the request as that repo. No URL means the repo you are in, so walk up and look for a web app (a `package.json` with a build script beside a Vite, React Router, Next, Astro, SvelteKit or Remix config). Exactly one is `build`; several, ask which; none, ask for a URL or a path. A workspace whose `.origin` already names this repo is reused, not scaffolded again. Say the mode and the workspace path in one line and carry on.
2. `scripts/doctor.sh`, then **set yourself up before asking anything else of the user.** They installed a skill; they did not sign up to run three scripts. Say what is missing in one line, say what you propose to install and roughly how big it is, and run it once they agree. `scripts/install.sh` covers the engine and Chromium (about 250MB) and installs ffmpeg too where a package manager allows it; `scripts/install-voice.sh` is the voice (~350MB), and filming silent is a fine answer if they would rather not. Never install anything without asking, and never hand them a doctor report to interpret. Two things it will not do, and nor should you: upgrade their Node, because which tool owns it is theirs to know, and run `sudo`, because a password prompt in a script nobody is watching just hangs. In both cases the script prints the one command and you pass it on.
3. **Discover, writing nothing.** `site`: open the URL and read it, for what the page is for, the three things worth showing, and what is stable enough to point at. If it lands on a sign-in, stop: a signed-in app is filmed from its repo, so ask for that or for a public URL. `build`: the build command copied verbatim out of `package.json`; the output directory from the framework's config; any absolute API host in `.env*` (it goes in `build.forbid`); the key the theme boot script reads; an existing fixture API or MSW handlers; `data-testid` density; routes with no credential.
4. `scripts/scaffold.mjs <appRoot>`, or `scripts/scaffold.mjs --site <url>`. Neither writes anything into the app.
5. **Fill in the workspace's `demo.config.ts`.** A required field still unknown means discovery is not done. [config.md](references/config.md)
6. **`build` only: write `mock.ts` and `seed/`.** Reuse the repo's own data fixtures where it has them, but never a file that imports `@playwright/test`: two copies in one run is an error Playwright refuses, and it fails the whole corpus rather than the one scene that did it. Then `DEMO_VOICE=0 scripts/demo --grep smoke`. Reuse the repo's fixture API if it has one ([mocking.md](references/mocking.md)). Read the still: signed in, seeded data, right theme, no login page. Read the capture line. Fix until both are right, then write `demo/ui.ts` with only what the smoke run proved.
7. **Film what they asked for, at the scope they asked for it.** A named feature is one scene: write it, film it, hand it over. Do not answer "record the search on the home page" with a ten-scene proposal, and do not quietly widen the ask because the product has more in it. Only when the request is the whole product do you **propose 6 to 10 scenes**, each a title and a one-line blurb in tour order, and ask which to film first.
8. **STOP.** Film that one scene with voice. Verify the spoken count matches the `say` calls, nothing overran, the rate held. Read every still. Give the user the mp4 path and ask about the writing's register, the zoom scale, the pacing and the voice. **Write nothing else until they answer.**
9. Then batches of three or four via `--grep`; the manifest merges. Read the stills after every batch. `DEMO_BUILD=0 scripts/demo` skips the rebuild while iterating on a scene — twenty seconds instead of four minutes; drop it for the run that produces the corpus.
10. Full run with `DEMO_TRACE_FRAMES=1`, then `scripts/gaps.mjs` and open `demo-out/index.html`. Report the capture table and any slow clips.

## A scene

```ts
scene('tasks', { title: 'Your to-dos, beside your calendar', blurb: '...' },
  async ({ actor, page, shot }) => {
    await actor.click(page.getByRole('radio', { name: 'Today' }));
    await actor.settle();
    await actor.spotlight(
      row('Send Sam the feedback'),
      'And this one is from yesterday that I never got to, so it is flagged.',
      { scale: 1.8, stay: true }
    );
    await shot('overdue');
    await actor.unfocus();
  });
```

`spotlight` takes the narration mark, then moves camera and cursor over the line's opening words. Scale by subject: panel ~1.4, row ~1.7, single control ~2. A line about the whole screen gets a plain `say` and no zoom. `unfocus` is a hint rather than a movement: the camera only comes out when something needs it wide, so consecutive beats about the same region glide instead of bouncing. [scenes.md](references/scenes.md) · [narration.md](references/narration.md)

## Never

Subtitles in the engine path (the voice is the channel; the manual path below uses subtitles instead). Cloud TTS (the film is of private data). Playwright's `recordVideo` in the engine path (no control of rate, size or start; the recorder replaces it — the manual path below uses it). 4K as a default. Music, intro cards or cross-fades. Scenes generated from a route crawl: a scene is choreography with a point. Retries: a retried scene is a different film.

## Also

[capture.md](references/capture.md) before changing any capture number. [runs.md](references/runs.md) for builds, isolation and the manifest. [troubleshooting.md](references/troubleshooting.md) when a run dies or a shot looks wrong. The engine runs from this skill, so a fix to `engine/` reaches every project on the machine at once: edit it there, and nothing needs propagating.

## Manual Playwright Recording (no engine)

Hand-rolled alternative: one self-contained Playwright script with `recordVideo`, an injected cursor overlay, and a subtitle bar. Every demo goes through three phases — **Discover → Rehearse → Record**. Never skip straight to recording.

### Phase 1: Discover

You cannot script what you have not seen: fields may be `<input>` not `<textarea>`, dropdowns may be custom components not `<select>`, and comment boxes may support `@mentions` or `#tags`. Assumptions break recordings silently. Navigate to each page in the flow and dump its interactive elements:

```javascript
// Run this for each page in the flow BEFORE writing the demo script
const fields = await page.evaluate(() => {
  const els = [];
  document.querySelectorAll('input, select, textarea, button, [contenteditable]').forEach(el => {
    if (el.offsetParent !== null) {
      els.push({
        tag: el.tagName,
        type: el.type || '',
        name: el.name || '',
        placeholder: el.placeholder || '',
        text: el.textContent?.trim().substring(0, 40) || '',
        contentEditable: el.contentEditable === 'true',
        role: el.getAttribute('role') || '',
      });
    }
  });
  return els;
});
console.log(JSON.stringify(fields, null, 2));
```

What to look for:

- **Form fields** — `<select>`, `<input>`, custom dropdowns, or comboboxes?
- **Select options** — dump option values AND text; placeholders often have `value="0"` or `value=""`. Skip options whose text includes "Select" or whose value is `"0"`.
- **Rich text** — does the comment box support `@mentions`, `#tags`, markdown, or emoji? Check placeholder text.
- **Required fields** — check `required`, `*` in labels, and try submitting empty to see validation errors.
- **Dynamic content** — fields that appear after others are filled.
- **Button labels** — exact text such as `Submit`, `Submit Request`, or `Send`.
- **Table column headers** — for table-driven modals, map each `input[type="number"]` to its column header instead of assuming all numeric inputs mean the same thing.

Output: a field map per page, used to write correct selectors. Example:

```text
/purchase-requests/new:
  - Budget Code: <select> (first select on page, 4 options)
  - Desired Delivery: <input type="date">
  - Context: <textarea> (not input)
  - Submit: <button> text="Submit"

/purchase-requests/N (detail):
  - Comment: <input placeholder="Type a message..."> supports @user and #PR tags
  - Send: <button> text="Send" (disabled until input has content)
```

### Phase 2: Rehearse

Run through all steps without recording. Verify every selector resolves — silent selector failures are the main reason demo recordings break. Use `ensureVisible`, a wrapper that logs and fails loudly:

```javascript
async function ensureVisible(page, locator, label) {
  const el = typeof locator === 'string' ? page.locator(locator).first() : locator;
  const visible = await el.isVisible().catch(() => false);
  if (!visible) {
    const msg = `REHEARSAL FAIL: "${label}" not found - selector: ${typeof locator === 'string' ? locator : '(locator object)'}`;
    console.error(msg);
    const found = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('button, input, select, textarea, a'))
        .filter(el => el.offsetParent !== null)
        .map(el => `${el.tagName}[${el.type || ''}] "${el.textContent?.trim().substring(0, 30)}"`)
        .join('\n  ');
    });
    console.error('  Visible elements:\n  ' + found);
    return false;
  }
  console.log(`REHEARSAL OK: "${label}"`);
  return true;
}
```

Drive rehearsal from label/selector pairs and fail the run when any is missing:

```javascript
const steps = [
  { label: 'Login email field', selector: '#email' },
  { label: 'Login submit', selector: 'button[type="submit"]' },
  { label: 'New Request button', selector: 'button:has-text("New Request")' },
  { label: 'Budget Code select', selector: 'select' },
  { label: 'Delivery date', selector: 'input[type="date"]:visible' },
  { label: 'Description field', selector: 'textarea:visible' },
  { label: 'Add Item button', selector: 'button:has-text("Add Item")' },
  { label: 'Submit button', selector: 'button:has-text("Submit")' },
];

let allOk = true;
for (const step of steps) {
  if (!await ensureVisible(page, step.selector, step.label)) {
    allOk = false;
  }
}
if (!allOk) {
  console.error('REHEARSAL FAILED - fix selectors before recording');
  process.exit(1);
}
console.log('REHEARSAL PASSED - all selectors verified');
```

When rehearsal fails: read the visible-element dump, find the correct selector, update the script, re-run. Only proceed when every selector passes.

### Phase 3: Record

#### Storytelling flow

Plan the video as a story. Follow user-specified order, or default to:

- **Entry** — login or navigate to the starting point
- **Context** — pan the surroundings so viewers orient themselves
- **Action** — perform the main workflow steps
- **Variation** — show a secondary feature such as settings, theme, or localization
- **Result** — show the outcome, confirmation, or new state

#### Pacing

- After login: `4s`
- After navigation: `3s`
- After clicking a button: `2s`
- Between major steps: `1.5-2s`
- After the final action: `3s`
- Typing delay: `25-40ms` per character

#### Cursor overlay

Inject an SVG arrow cursor that follows mouse movements; re-inject it after every navigation because the overlay is destroyed on navigate:

```javascript
async function injectCursor(page) {
  await page.evaluate(() => {
    if (document.getElementById('demo-cursor')) return;
    const cursor = document.createElement('div');
    cursor.id = 'demo-cursor';
    cursor.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M5 3L19 12L12 13L9 20L5 3Z" fill="white" stroke="black" stroke-width="1.5" stroke-linejoin="round"/>
    </svg>`;
    cursor.style.cssText = `
      position: fixed; z-index: 999999; pointer-events: none;
      width: 24px; height: 24px;
      transition: left 0.1s, top 0.1s;
      filter: drop-shadow(1px 1px 2px rgba(0,0,0,0.3));
    `;
    cursor.style.left = '0px';
    cursor.style.top = '0px';
    document.body.appendChild(cursor);
    document.addEventListener('mousemove', (e) => {
      cursor.style.left = e.clientX + 'px';
      cursor.style.top = e.clientY + 'px';
    });
  });
}
```

#### Mouse movement

Never teleport the cursor — move to the target before clicking:

```javascript
async function moveAndClick(page, locator, label, opts = {}) {
  const { postClickDelay = 800, ...clickOpts } = opts;
  const el = typeof locator === 'string' ? page.locator(locator).first() : locator;
  const visible = await el.isVisible().catch(() => false);
  if (!visible) {
    console.error(`WARNING: moveAndClick skipped - "${label}" not visible`);
    return false;
  }
  try {
    await el.scrollIntoViewIfNeeded();
    await page.waitForTimeout(300);
    const box = await el.boundingBox();
    if (box) {
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 10 });
      await page.waitForTimeout(400);
    }
    await el.click(clickOpts);
  } catch (e) {
    console.error(`WARNING: moveAndClick failed on "${label}": ${e.message}`);
    return false;
  }
  await page.waitForTimeout(postClickDelay);
  return true;
}
```

Every call should include a descriptive `label` for debugging.

#### Typing

Type visibly, not instant-fill:

```javascript
async function typeSlowly(page, locator, text, label, charDelay = 35) {
  const el = typeof locator === 'string' ? page.locator(locator).first() : locator;
  const visible = await el.isVisible().catch(() => false);
  if (!visible) {
    console.error(`WARNING: typeSlowly skipped - "${label}" not visible`);
    return false;
  }
  await moveAndClick(page, el, label);
  await el.fill('');
  await el.pressSequentially(text, { delay: charDelay });
  await page.waitForTimeout(500);
  return true;
}
```

#### Scrolling

Use smooth scroll instead of jumps:

```javascript
await page.evaluate(() => window.scrollTo({ top: 400, behavior: 'smooth' }));
await page.waitForTimeout(1500);
```

#### Dashboard panning

On a dashboard or overview page, sweep the cursor across key elements:

```javascript
async function panElements(page, selector, maxCount = 6) {
  const elements = await page.locator(selector).all();
  for (let i = 0; i < Math.min(elements.length, maxCount); i++) {
    try {
      const box = await elements[i].boundingBox();
      if (box && box.y < 700) {
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 8 });
        await page.waitForTimeout(600);
      }
    } catch (e) {
      console.warn(`WARNING: panElements skipped element ${i} (selector: "${selector}"): ${e.message}`);
    }
  }
}
```

#### Subtitles

In this path the subtitle bar is the narration channel; the engine path uses voice-over instead. Inject a fixed bar at the bottom of the viewport:

```javascript
async function injectSubtitleBar(page) {
  await page.evaluate(() => {
    if (document.getElementById('demo-subtitle')) return;
    const bar = document.createElement('div');
    bar.id = 'demo-subtitle';
    bar.style.cssText = `
      position: fixed; bottom: 0; left: 0; right: 0; z-index: 999998;
      text-align: center; padding: 12px 24px;
      background: rgba(0, 0, 0, 0.75);
      color: white; font-family: -apple-system, "Segoe UI", sans-serif;
      font-size: 16px; font-weight: 500; letter-spacing: 0.3px;
      transition: opacity 0.3s;
      pointer-events: none;
    `;
    bar.textContent = '';
    bar.style.opacity = '0';
    document.body.appendChild(bar);
  });
}

async function showSubtitle(page, text) {
  await page.evaluate((t) => {
    const bar = document.getElementById('demo-subtitle');
    if (!bar) return;
    if (t) {
      bar.textContent = t;
      bar.style.opacity = '1';
    } else {
      bar.style.opacity = '0';
    }
  }, text);
  if (text) await page.waitForTimeout(800);
}
```

Call `injectSubtitleBar` alongside `injectCursor` after every navigation. Keep text short (ideally under 60 characters), use `Step N - Action` format, and clear the bar during long pauses where the UI speaks for itself:

```javascript
await showSubtitle(page, 'Step 1 - Logging in');
await showSubtitle(page, 'Step 2 - Dashboard overview');
await showSubtitle(page, '');
```

#### Recording wiring

Record in a `recordVideo` context, then copy the randomly named file to a stable output name:

```javascript
const context = await browser.newContext({
  recordVideo: { dir: VIDEO_DIR, size: { width: 1280, height: 720 } },
  viewport: { width: 1280, height: 720 }
});
// ... run the flow, injecting overlays after each navigation ...
await context.close();
const src = await page.video().path();
fs.copyFileSync(src, path.join(VIDEO_DIR, OUTPUT_NAME));
```

Run rehearsal and recording as two modes of the same script:

```bash
node demo-script.cjs --rehearse   # verify selectors only
node demo-script.cjs              # record
```

### Checklist Before Recording

- [ ] Discovery phase completed
- [ ] Rehearsal passes with all selectors OK
- [ ] Headless mode enabled; resolution set to `1280x720`
- [ ] Cursor and subtitle overlays re-injected after every navigation
- [ ] `showSubtitle(page, 'Step N - ...')` used at major transitions
- [ ] `moveAndClick` used for all clicks with descriptive labels
- [ ] `typeSlowly` used for visible input
- [ ] No silent catches; helpers log warnings
- [ ] Smooth scrolling used for content reveal
- [ ] Key pauses are visible to a human viewer
- [ ] Flow matches the requested story order

### Common Pitfalls

1. Cursor disappears after navigation — re-inject it.
2. Video is too fast — add pauses.
3. Cursor is a dot instead of an arrow — use the SVG overlay.
4. Cursor teleports — move before clicking.
5. Select dropdowns look wrong — show the move, then pick the option.
6. Modals feel abrupt — add a read pause before confirming.
7. Video file path is random — copy it to a stable output name.
8. Selector failures are swallowed — never use silent catch blocks.
9. Field types were assumed — discover them first.
10. Features were assumed — inspect the actual UI before scripting.
11. Placeholder select values look real — watch for `"0"` and `"Select..."`.
12. Popups create separate videos — capture popup pages explicitly and merge later if needed.
