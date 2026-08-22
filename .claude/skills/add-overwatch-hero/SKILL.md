---
name: add-overwatch-hero
description: Add a newly released Overwatch hero to the Mystery Heroes roster - sources the 256x256 hero portrait from the Overwatch wikis, converts it to the project's webp format, inserts the hero into the correct role list in lib/main.dart, and verifies the result. Use when asked to "add support for <Hero>", "add <Hero>", "a new hero has been released", or to check whether the roster is missing any current heroes.
---

# Add an Overwatch hero to the roster

Adds one hero: a portrait in `assets/` plus one entry in `lib/main.dart`. Nothing else
needs touching - `pubspec.yaml` includes `assets/` as a whole directory, so new portraits
are picked up with no manifest edit.

If the user did not say which role the hero is (Tank / Damage / Support), ask before
editing - it decides which list the name goes in and cannot be inferred from the portrait.

## 1. Resolve and download the portrait

```bash
python .claude/skills/add-overwatch-hero/scripts/fetch_portrait.py "D.Mon"
```

Prints the resolved source URL and the downloaded PNG path (defaults into the session
scratchpad; `--out <path>` to override). Expect 256x256 PNG with alpha.

Source order, and why:

1. **`overwatch.weirdgloop.org`** - primary. Fastest to carry brand-new heroes.
2. **`overwatch.fandom.com`** - fallback. Same `File:<Hero> Hero.png` naming, also
   `File:Icon-<Hero>.png`, e.g. `https://overwatch.fandom.com/wiki/Category:Shion_hero_icons`.
   It **lags on new releases** - when D.Mon shipped, weirdgloop had the portrait and the
   Fandom category was still empty. Don't lead with it.

Both wikis are MediaWiki, so `api.php?action=query&titles=File:<Hero> Hero.png&prop=imageinfo`
resolves the real file URL. The wikis key on the hero's **exact** title including accents -
`File:Torbjörn Hero.png` works, `File:Torbjorn Hero.png` is a miss. The script handles this
for you: it tries accent and punctuation variants, then falls back to a File-namespace
search, so plain-ASCII input like `Torbjorn` still resolves to `Torbjörn Hero.png`.

Exit codes: `0` resolved, `3` not found on either wiki (it prints a manual search link).

**View the PNG with the Read tool before going further.** It confirms you got a hero
portrait in the roster's art style and not a placeholder, logo, or wrong crop. This is a
cheap gate on a mistake that otherwise ships to the live site.

## 2. Convert to the project's webp format

Every existing portrait is 256x256 `yuva420p` webp, roughly 12-24 KB.

```bash
ffmpeg -y -v error -i <downloaded.png> -c:v libwebp -pix_fmt yuva420p \
  -quality 80 -compression_level 6 assets/<assetname>.webp
```

Tooling reality on this machine: **`ffmpeg` is the only option.** `magick` and `cwebp` are
not installed, and `convert` on `PATH` is the Windows NTFS conversion utility - running it
expecting ImageMagick is a genuine hazard, not just a miss.

`<assetname>` must match what the app derives at runtime. From `_getHeroAssetPath` in
`lib/main.dart`: lowercase, then `ú`->`u` and `ö`->`o`, then strip everything outside
`[a-z0-9]`, then `.webp`. So `D.Mon` -> `dmon.webp`, `Soldier: 76` -> `soldier76.webp`,
`Lúcio` -> `lucio.webp`. No special-casing needed for dots or spaces.

Verify the output with `ffprobe -v error -select_streams v:0 -show_entries
stream=width,height,pix_fmt -of csv=p=0`, and view the webp too - it catches a lost alpha
channel, which is invisible in the file size alone.

## 3. Add the hero to the right role list

Edit the `_tanks`, `_damage`, or `_support` list in `lib/main.dart` (near the top of
`_ChallengeScreenState`).

Insertion order matters, in both views:

- The alphabetical view is `List<String>.from(_allHeroes)..sort()` - Dart's default string
  sort is **UTF-16 code-unit order, not human alphabetical**.
- The role-grouped view reads the source list order directly, with no sort.

So keep each source list in that same code-unit order and the two views agree. Practical
consequence: `.` (0x2E) sorts before any letter, so `D.Mon` < `D.Va` < `Domina`, and
`D.Mon` goes at the **front** of `_tanks`. Likewise accented letters sort high
(`Lifeweaver` < `Lúcio` < `Mercy`).

Re-wrap the list to match the surrounding style rather than leaving one long line.

## 4. Verify

```bash
python .claude/skills/add-overwatch-hero/scripts/check_roster.py
```

Cross-checks `lib/main.dart` against the wiki's live hero category and the files in
`assets/`. Reports per-role counts, heroes on the wiki but not in the app (and vice
versa), duplicates, heroes with no portrait file, orphan portraits, and any role list
that has drifted out of Dart sort order (the step 3 trap). Exits non-zero on any
mismatch. `--offline` skips the wiki call. This also answers "is the roster up to
date?" on its own.

**`flutter analyze` does not run here.** The local SDK is Flutter 3.7.7 / Dart 2.19.4,
below this project's `sdk: >=3.0.0` constraint, so `pub get` fails during analyze. Don't
read that failure as a problem with the change. CI is the compile check - the GitHub
Actions workflow uses `channel: stable`. If local verification is ever needed, that means
upgrading the global SDK at `C:\Projects\flutter`; ask first, it's slow and machine-wide.

## 5. Commit, and confirm before pushing

One commit per hero, matching existing history (`Add Shion`, `Add D.Mon`):

```bash
git add assets/<assetname>.webp lib/main.dart && git commit -m "Add <Hero>"
```

**Ask before pushing.** A push to `main` fires `.github/workflows/gh-pages.yml`, which
publishes to **mysteryheroesmashup.com** - a public deploy, not a local step.

After a push, confirm it actually landed rather than assuming:

- Workflow conclusion for your SHA:
  `https://api.github.com/repos/tjeffree/Overwatch-Mystery-Heroes/actions/runs?per_page=5`
- `git fetch origin gh-pages` then `git ls-tree -r --name-only origin/gh-pages | grep <assetname>`
  (Flutter web nests assets, so the deployed path is `assets/assets/<assetname>.webp`)
- Live: `curl -s -o /dev/null -w "%{http_code} %{size_download} %{content_type}"
  https://mysteryheroesmashup.com/assets/assets/<assetname>.webp`

## Notes

- The comment above the role lists (`// Full 51-Hero Roster ...`) is a hardcoded count and
  has drifted out of date. Either update it with the hero or leave it; don't trust it as
  the roster size.
- Running `python -c` with a multi-line inline script through the pyenv shim in Git Bash
  mangles the source and can fail with a confusing `IndentationError`. Write the script to
  a file and run it - both scripts here exist partly for that reason.
