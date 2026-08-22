"""Cross-check the app roster in lib/main.dart against the wiki hero list and assets/.

Usage:
    python check_roster.py [--offline]

Reports per-role counts, heroes present on the wiki but missing from the app (and vice
versa), heroes whose portrait file is absent, and orphan portrait files. Exits non-zero
if anything is out of sync, so it doubles as a "is the roster up to date?" check.
"""

import argparse
import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ROLES = ("_tanks", "_damage", "_support")
UA = {"User-Agent": "overwatch-mystery-heroes-roster-check/1.0"}

# repo root: <root>/.claude/skills/add-overwatch-hero/scripts/this_file
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "..", ".."))
MAIN_DART = os.path.join(ROOT, "lib", "main.dart")
ASSETS = os.path.join(ROOT, "assets")
README = os.path.join(ROOT, "README.md")

# README role heading -> main.dart list name
README_ROLES = (("Tanks", "_tanks"), ("Damage", "_damage"), ("Support", "_support"))

# Non-hero images that legitimately live in assets/
NON_HERO_ASSETS = {"overwatch.png"}


def asset_name(hero):
    """Mirror of _getHeroAssetPath in lib/main.dart. Keep in sync if that changes."""
    name = hero.lower().replace(u"ú", "u").replace(u"ö", "o")
    return re.sub(r"[^a-z0-9]", "", name) + ".webp"


def read_roster():
    src = io.open(MAIN_DART, encoding="utf-8").read()
    roster = {}
    for role in ROLES:
        match = re.search(role + r"\s*=\s*\[(.*?)\];", src, re.S)
        if not match:
            print("ERROR: could not parse %s out of lib/main.dart" % role)
            sys.exit(2)
        roster[role] = re.findall(r"'([^']+)'", match.group(1))
    return roster


def wiki_heroes():
    params = {
        "action": "query",
        "list": "categorymembers",
        "cmtitle": "Category:Heroes",
        "cmlimit": "500",
        "cmtype": "page",
        "format": "json",
    }
    url = "https://overwatch.weirdgloop.org/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    members = {m["title"] for m in data["query"]["categorymembers"]}
    return members - {"Heroes"}  # the category page itself


def check_readme(roster, total):
    """README.md duplicates the roster in prose and drifts silently. Compare its
    per-role lists and every hardcoded hero count against lib/main.dart."""
    if not os.path.isfile(README):
        print("  no README.md found; skipped")
        return 0

    text = io.open(README, encoding="utf-8").read()
    problems = 0

    for label, role in README_ROLES:
        match = re.search(r"\*\*%s \((\d+)\)\*\*:\s*(.+)" % label, text)
        if not match:
            print("  could not find a '**%s (N)**:' line" % label)
            problems += 1
            continue

        stated = int(match.group(1))
        # Hero names never contain ', ' - 'Soldier: 76' splits safely
        listed = [n.strip() for n in match.group(2).split(",") if n.strip()]
        expected = roster[role]

        if stated != len(expected):
            print("  %s: count says (%d), roster has %d" % (label, stated, len(expected)))
            problems += 1
        if stated != len(listed):
            print("  %s: count says (%d) but %d names are listed"
                  % (label, stated, len(listed)))
            problems += 1

        absent = [h for h in expected if h not in listed]
        extra = [h for h in listed if h not in expected]
        if absent:
            print("  %s: missing from README: %s" % (label, absent))
            problems += 1
        if extra:
            print("  %s: in README but not in the app: %s" % (label, extra))
            problems += 1

    # Hardcoded totals: '53-hero roster', '53-Hero Roster', '(53 heroes)'
    for pattern in (r"(\d+)-[Hh]ero\b", r"\((\d+) heroes\)"):
        for found in re.finditer(pattern, text):
            if int(found.group(1)) != total:
                line = text[:found.start()].count("\n") + 1
                print("  line %d: hardcoded count '%s' should be %d"
                      % (line, found.group(0), total))
                problems += 1

    if problems == 0:
        print("  README roster matches lib/main.dart")
    return problems


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true",
                        help="Skip the wiki comparison; only check assets on disk")
    args = parser.parse_args()

    roster = read_roster()
    app = set()
    print("Roster in lib/main.dart:")
    for role in ROLES:
        print("  %-8s %d" % (role.lstrip("_"), len(roster[role])))
        app |= set(roster[role])
    total = sum(len(roster[r]) for r in ROLES)
    print("  %-8s %d" % ("total", total))

    if total != len(app):
        dupes = [h for h in app if sum(roster[r].count(h) for r in ROLES) > 1]
        print("\nDUPLICATE hero entries: %s" % sorted(dupes))

    problems = 0

    # --- source-order check: each list should be in Dart's default sort order ---
    for role in ROLES:
        if roster[role] != sorted(roster[role]):
            print("\n%s is not in Dart sort order; alphabetical and role views will"
                  " disagree.\n  current: %s\n  sorted : %s"
                  % (role, roster[role], sorted(roster[role])))
            problems += 1

    # --- assets on disk ---
    have = set(os.listdir(ASSETS))
    expected = {asset_name(h) for h in app}
    missing = sorted((h, asset_name(h)) for h in app if asset_name(h) not in have)
    orphans = sorted(f for f in have
                     if f not in expected and f not in NON_HERO_ASSETS)

    print("\nAssets:")
    if missing:
        problems += 1
        for hero, fname in missing:
            print("  MISSING portrait for %s (expected assets/%s)" % (hero, fname))
    if orphans:
        problems += 1
        for fname in orphans:
            print("  ORPHAN asset with no hero: assets/%s" % fname)
    if not missing and not orphans:
        print("  all %d heroes have a portrait; no orphans" % len(app))

    # --- hardcoded count in the main.dart comment above the lists ---
    src = io.open(MAIN_DART, encoding="utf-8").read()
    for found in re.finditer(r"(\d+)-[Hh]ero\b", src):
        if int(found.group(1)) != total:
            line = src[:found.start()].count("\n") + 1
            print("\nlib/main.dart line %d: comment says '%s', roster has %d"
                  % (line, found.group(0), total))
            problems += 1

    # --- README ---
    print("\nREADME.md:")
    problems += check_readme(roster, total)

    # --- wiki comparison ---
    if not args.offline:
        print("\nWiki comparison (overwatch.weirdgloop.org Category:Heroes):")
        try:
            wiki = wiki_heroes()
        except Exception as exc:
            print("  could not reach wiki (%s); skipped" % exc)
        else:
            absent = sorted(wiki - app)
            extra = sorted(app - wiki)
            print("  wiki: %d heroes | app: %d heroes" % (len(wiki), len(app)))
            if absent:
                problems += 1
                print("  NOT IN APP (add these): %s" % absent)
            if extra:
                problems += 1
                print("  IN APP BUT NOT ON WIKI (renamed or typo?): %s" % extra)
            if not absent and not extra:
                print("  in sync - roster is up to date")

    print("\n%s" % ("OK" if problems == 0 else "%d problem(s) found" % problems))
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
