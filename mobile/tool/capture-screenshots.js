// Play Store screenshot capture driver.
//
// Walks the StudyFlow Flutter web build (served by capture-screenshots.sh)
// at a real phone viewport and saves 1080×1920 PNGs to ../screenshots/play-store.
//
// Viewport math: Chrome screenshot pixels = CSS px × deviceScaleFactor.
// 360 × 3 = 1080, 640 × 3 = 1920 — a true phone layout, exactly the Play
// Store phone screenshot size. Don't change one without the other.
//
// Usage: node capture-screenshots.js <base-url> [--dark]

const { chromium } = require('playwright-core');
const fs = require('node:fs');
const path = require('node:path');

const BASE = process.argv[2];
const DARK = process.argv.includes('--dark');
const OUT = path.join(__dirname, '..', 'screenshots', 'play-store');
const NOTEBOOK_ID = 'nb-cell-bio';

const SHOTS = [
  {
    name: '01-signup',
    url: '/signup',
    // Capture builds boot signed OUT, so the auth pages are reachable.
    waitFor: ['Name', 'Create account'],
  },
  {
    name: '02-login',
    url: '/login',
    waitFor: ['Email', 'Log in'],
  },
  {
    name: '03-home',
    url: '/home',
    waitFor: ['WELCOME BACK', 'CONTINUE STUDYING'],
  },
  {
    name: '04-notebooks',
    url: '/notebooks',
    waitFor: ['Sample: Cell Biology — Unit 2', 'Sample: VLSI Unit 3'],
  },
  {
    name: '05-study-space',
    url: `/notebooks/${NOTEBOOK_ID}`,
    waitFor: ['STUDY SPACE', 'Sample: Cell Biology — Unit 2'],
  },
  {
    name: '06-ask-ai',
    url: `/notebooks/${NOTEBOOK_ID}`,
    waitFor: ['STUDY SPACE', 'Sample: Cell Biology — Unit 2'],
    clickTab: 'Ask AI',
    afterTab: ['Ask your notebook'],
    askQuestion: 'What is photosynthesis?',
  },
  {
    name: '07-flashcards',
    url: '/flashcards/fc-photosynthesis',
    waitFor: ['What does a CMOS inverter consist of?'],
  },
  {
    name: '08-quiz',
    url: '/quizzes/qz-photosynthesis',
    waitFor: ['QUIZ SESSION', 'Where does the light-dependent reaction take place?'],
  },
  {
    name: '09-audio',
    url: '/audio',
    waitFor: ['Sample: Cell Biology Study Podcast', 'Sample: VLSI Unit 3 Deep Dive'],
  },
  {
    name: '10-progress',
    url: '/progress',
    waitFor: ['Mastery'],
  },
  {
    name: '11-premium',
    url: '/premium',
    waitFor: ['Founding Member'],
  },
];

(async () => {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch({
    channel: 'chrome', // system Chrome — no bundled browser download
    headless: true,
    args: ['--force-device-scale-factor=3'],
  });

  const context = await browser.newContext({
    viewport: { width: 360, height: 640 },
    deviceScaleFactor: 3,
    colorScheme: DARK ? 'dark' : 'light',
  });
  const page = await context.newPage();

  for (const shot of SHOTS) {
    console.log(`→ ${shot.name}`);
    await page.goto(`${BASE}${shot.url}`, { waitUntil: 'networkidle', timeout: 45000 });

    // Flutter web paints into a canvas — the semantics tree is the DOM.
    // Wait for the interactive nodes of this screen to exist.
    await page.waitForFunction(
      (labels) => labels.every((l) => {
        const nodes = [...document.querySelectorAll('flt-semantics, [aria-label]')];
        return nodes.some((n) => (n.getAttribute('aria-label') || n.textContent || '').includes(l));
      }),
      shot.waitFor,
      { timeout: 30000 },
    );

    if (shot.url === '/login') {
      // Authentication step (only once, after both auth pages are shot):
      // persist the seeded repo's signed-in flag in localStorage, which the
      // app reads on the next full page load. The reload below then boots
      // straight into the app shell.
      await page.evaluate(() =>
        localStorage.setItem('studyflow.capture_signed_in', '1'));
      console.log('  auth flag set (localStorage)');
    }

    if (shot.clickTab) {
      // Tabs are rendered as buttons in the semantics tree.
      const tab = page.getByRole('button', { name: shot.clickTab }).first();
      if (process.env.DEBUG_CAPTURE) {
        const before = await page.evaluate(() =>
          [...document.querySelectorAll('flt-semantics, [aria-label], [role="button"], [role="tab"]')]
            .map((n) => (n.getAttribute('aria-label') || n.textContent || '').trim())
            .filter(Boolean).slice(0, 40));
        console.log('  [debug] before click:', JSON.stringify(before));
      }
      await tab.click();
      // The tab switch itself is the signal; label matching for the new tab
      // is flaky because Flutter merges tile text into one semantics node.
      // Settle the animation, then verify the selected tab visually via the
      // screenshot at the end of the loop.
      await page.waitForTimeout(1500);
      if (process.env.DEBUG_CAPTURE) {
        const after = await page.evaluate(() =>
          [...document.querySelectorAll('flt-semantics, [aria-label], [role="button"], [role="tab"]')]
            .map((n) => (n.getAttribute('aria-label') || n.textContent || '').trim())
            .filter(Boolean).slice(0, 40));
        console.log('  [debug] after click:', JSON.stringify(after));
      }
    }

    if (shot.askQuestion) {
      // Ask the seeded chat a real question so the grounded answer and
      // citation chip render (the differentiator shot).
      const input = page.getByRole('textbox').last();
      await input.click();
      await input.fill(shot.askQuestion);
      await input.press('Enter');
      await page.waitForFunction(
        (label) =>
          [...document.querySelectorAll('flt-semantics, [aria-label]')].some(
            (n) =>
              (n.getAttribute('aria-label') || n.textContent || '').includes(
                label,
              ),
          ),
        'Sample answer',
        { timeout: 30000 },
      );
      await page.waitForTimeout(1500);
    }

    // Let the last frame settle (glass animations are short, ~300ms).
    await page.waitForTimeout(600);

    const file = path.join(OUT, `${shot.name}${DARK ? '-dark' : ''}.png`);
    await page.screenshot({ path: file });
    console.log(`  ✓ ${path.basename(file)}`);
  }

  await browser.close();
  console.log('done');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
