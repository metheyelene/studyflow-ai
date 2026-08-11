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
    name: '03-dashboard',
    url: '/home',
    waitFor: ['Ready to study?', 'QUICK ACTIONS'],
  },
  {
    name: '04-notebooks',
    url: '/notebooks',
    waitFor: ['Sample: Cell Biology — Unit 2', 'New'],
  },
  {
    name: '05-notebook-detail',
    url: `/notebooks/${NOTEBOOK_ID}`,
    waitFor: ['Sample: Cell Biology — Unit 2', 'Ask AI'],
  },
  {
    name: '06-notebook-ask-ai',
    url: `/notebooks/${NOTEBOOK_ID}`,
    waitFor: ['Sample: Cell Biology — Unit 2', 'No sources yet'],
    clickTab: 'Ask AI',
    afterTab: ['Ask your notebook'],
  },
  {
    name: '07-study-tools',
    url: `/notebooks/${NOTEBOOK_ID}`,
    waitFor: ['Sample: Cell Biology — Unit 2', 'No sources yet'],
    clickTab: 'Study tools',
    afterTab: ['Summarize', 'Flashcards'],
  },
  {
    name: '08-study-plan',
    url: '/study',
    waitFor: ['Flashcards, quizzes, and your study plan'],
  },
  {
    name: '09-progress',
    url: '/progress',
    waitFor: ['Progress', 'quiz scores'],
  },
  {
    name: '10-profile',
    url: '/profile',
    waitFor: ['Profile', 'Aarav Sharma'],
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
