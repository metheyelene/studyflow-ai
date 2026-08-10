# Contributing to StudyFlow AI

Thanks for helping. This is a small, fast-moving codebase — the rules below
keep it shippable and secure.

## Development workflow

1. **Branch from `main`**: `git checkout -b feat/your-change` (use
   `feat/`, `fix/`, `chore/` prefixes).
2. Make small, focused commits. Commit messages explain **why**, not just
   what:
   ```
   feat(notes): add paste-notes editor with autosave
   fix(auth): normalize bare-500 DB errors into JSON the client can parse
   ```
3. Push and open a pull request. CI runs on every push: lint → typecheck →
   tests → build → dependency audit → secret scan. **The PR must be green**
   before it merges.
4. Never merge a failing build to `main` — `main` auto-deploys to
   production.

## Before you open a PR

```bash
npm run lint        # no errors
npm run typecheck   # no output = clean
npm test            # all tests pass
npm run build       # succeeds
```

## Coding conventions

- **TypeScript everywhere**, no `any` unless you document why.
- **Server-side by default.** Anything that touches data, the DB, or AI goes
  in a server component, server action, or API route. Client components only
  render and call back into the server.
- **Secrets never reach the client.** API keys live only in server-side env
  vars. Never import `process.env.SECRET` into a client component.
- **Limits come from one place.** Free/premium numbers live in
  `src/lib/plans.ts` and are enforced server-side — never duplicate them and
  never trust a client-supplied plan flag.
- **UI uses tokens only.** Colors/spacing come from the design tokens in
  `src/app/globals.css` (`bg-card`, `text-muted-foreground`, …). No hardcoded
  hex values in components.
- **Friendly errors, technical logs.** Users get human copy
  (`src/lib/auth-errors.ts` is the pattern); real error details go to
  server logs / Sentry, never to the UI.
- **Validation on every input.** Server actions and API routes validate with
  Zod before touching the DB.
- **Structured AI output.** AI features parse + validate model responses
  against a schema before displaying them.

## Testing

- Unit tests live next to the code: `src/lib/plans.test.ts` is the pattern.
- Every bug fix ships with a regression test when practical.
- Run the whole suite: `npm test`.

## Security rules (non-negotiable)

- **Never commit `.env`** or any real secret. `.env*` is gitignored (except
  `.env.example`).
- Never paste API keys, DB credentials, or payment secrets into chat, issues,
  or PR descriptions.
- Never unlock premium based on a frontend callback — subscriptions change
  only from verified webhooks.
- If you find a vulnerability, open a private issue or tell the maintainer
  directly — don't post details publicly before it's fixed.

## Docs

If a change alters setup, env vars, commands, or architecture, update the
relevant file in `docs/` in the same PR.
