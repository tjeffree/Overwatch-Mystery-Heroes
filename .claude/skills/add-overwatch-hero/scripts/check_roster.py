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
