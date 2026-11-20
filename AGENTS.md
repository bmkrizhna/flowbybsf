# Flow (flowbybsf) — shared workflow for every AI tool and person

One source of truth: **GitHub `main`** → Vercel auto-deploys it to https://flowbybsf.vercel.app.
Data lives in one Supabase project (`btafdmfbrhvsjsenxpdj`), shared by everything.

## Rules (ChatGPT, Claude, anyone)
1. **Always start from the latest `main`.** `git pull origin main` (or re-read `index.html` from `main`) before every change. Never work from an older copy, an old branch, or a pasted file.
2. **Commit to `main`.** Small, focused commits with a clear message. Do not keep long-lived side branches, and do not "restore" or revert to an older build unless Bala asks for it by name.
3. **Never move the live alias by hand.** Pushing to `main` is the deploy. Test with the Vercel preview of a branch only when a change is risky.
4. **Do not overwrite someone else's change.** Before editing a region, read the latest `git log -5` and keep recent changes unless asked to remove them.
5. **Database changes** go through a Supabase migration (named, in `list_migrations`), never ad-hoc SQL on live data. Do not reopen `app_state` to the browser; all access is via the `state_get` / `state_put` / `app_login` functions.
6. Do not commit secrets. The Supabase anon key in `index.html` is public by design.

## Layout
Single-file app `index.html` + `manifest.json`, `sw.js`, `vercel.json`, `assets/`. Bump the `sw.js` cache name when shell files change.

## Before pushing
`node --check` every inline `<script>` block.
