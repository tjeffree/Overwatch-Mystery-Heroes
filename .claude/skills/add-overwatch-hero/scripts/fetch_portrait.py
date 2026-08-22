"""Resolve and download an Overwatch hero portrait from the wikis.

Usage:
    python fetch_portrait.py "D.Mon" [--out path.png] [--dry-run]

Tries overwatch.weirdgloop.org first (carries new heroes soonest), then
overwatch.fandom.com (same naming, but lags on new releases). Prints the resolved
source URL and the local path of the downloaded PNG.
"""

import argparse
import json
import os
import sys
import tempfile
import unicodedata
import urllib.parse
import urllib.request

WIKIS = [
    ("weirdgloop", "https://overwatch.weirdgloop.org/api.php"),
    ("fandom", "https://overwatch.fandom.com/api.php"),
]

UA = {"User-Agent": "overwatch-mystery-heroes-portrait-fetch/1.0"}


def strip_accents(text):
    decomposed = unicodedata.normalize("NFD", text)
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def title_candidates(hero):
    """Filename forms to try, most likely first. Accented form goes first: the wikis
    use the exact hero title, so 'Torbjorn' misses where 'Torbjoern' hits."""
    names = []
    for base in (hero, strip_accents(hero)):
        if base not in names:
            names.append(base)
        # 'Soldier: 76' is stored as 'Soldier_76', so drop stray punctuation too
        cleaned = base.replace(":", "").replace("  ", " ").strip()
        if cleaned not in names:
            names.append(cleaned)

    titles = []
    for n in names:
        for pattern in ("File:%s Hero.png", "File:Icon-%s.png", "File:%s Portrait.png"):
            t = pattern % n
            if t not in titles:
                titles.append(t)
    return titles


def image_info(api, title):
    params = {
        "action": "query",
        "titles": title,
        "prop": "imageinfo",
        "iiprop": "url|size|mime",
        "format": "json",
    }
    url = api + "?" + urllib.parse.urlencode(params, encoding="utf-8")
    req = urllib.request.Request(url, headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
    except Exception as exc:
        print("  ! %s: request failed (%s)" % (title, exc))
        return None

    pages = data.get("query", {}).get("pages", {})
    for page in pages.values():
        info = page.get("imageinfo")
        if info:
            return info[0]
    return None


def search_files(api, hero, verbose=True):
    """Fallback: full-text search the File namespace. Catches titles that differ from
    the input by accents or punctuation, e.g. input 'Torbjorn' -> 'Torbjörn Hero.png'."""
    params = {
        "action": "query",
        "list": "search",
        "srsearch": "%s Hero" % hero,
        "srnamespace": "6",
        "srlimit": "20",
        "format": "json",
    }
    url = api + "?" + urllib.parse.urlencode(params, encoding="utf-8")
    req = urllib.request.Request(url, headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            hits = json.load(resp).get("query", {}).get("search", [])
    except Exception as exc:
        if verbose:
            print("  ! search failed (%s)" % exc)
        return []

    # Prefer '<something> Hero.png', then any Icon-*.png
    titles = [h["title"] for h in hits]
    ranked = [t for t in titles if t.endswith(" Hero.png")]
    ranked += [t for t in titles if t.startswith("File:Icon-") and t not in ranked]
    return ranked


def resolve(hero, verbose=True):
    for wiki_name, api in WIKIS:
        for title in title_candidates(hero):
            info = image_info(api, title)
            if info:
                if verbose:
                    print("  found on %s: %s" % (wiki_name, title))
                return wiki_name, title, info
            if verbose:
                print("  miss on %s: %s" % (wiki_name, title))

        for title in search_files(api, hero, verbose):
            info = image_info(api, title)
            if info:
                if verbose:
                    print("  found on %s via search: %s" % (wiki_name, title))
                return wiki_name, title, info
    return None, None, None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("hero", help='Hero name as it appears in game, e.g. "D.Mon"')
    parser.add_argument("--out", help="Destination PNG path")
    parser.add_argument("--dry-run", action="store_true",
                        help="Resolve the URL but do not download")
    args = parser.parse_args()

    print('Resolving portrait for "%s"' % args.hero)
    wiki_name, title, info = resolve(args.hero)

    if not info:
        print("\nFAILED: no portrait found on either wiki.")
        print("The hero may be too new, or the title may differ (check accents and")
        print("spelling against the wiki page). Search manually:")
        print("  https://overwatch.weirdgloop.org/w/Special:Search?search=%s"
              % urllib.parse.quote(args.hero))
        return 3

    width, height = info.get("width"), info.get("height")
    print("\nsource : %s (%s)" % (info["url"], wiki_name))
    print("size   : %sx%s  %s  %s bytes" % (width, height, info.get("mime"), info.get("size")))

    if (width, height) != (256, 256):
        print("WARNING: expected 256x256 to match existing portraits.")

    if args.dry_run:
        return 0

    out = args.out
    if not out:
        out_dir = os.path.join(tempfile.gettempdir(), "overwatch-hero-portraits")
        if not os.path.isdir(out_dir):
            os.makedirs(out_dir)
        safe = strip_accents(args.hero).lower()
        safe = "".join(c for c in safe if c.isalnum())
        out = os.path.join(out_dir, safe + ".png")

    req = urllib.request.Request(info["url"], headers=UA)
    with urllib.request.urlopen(req, timeout=60) as resp:
        blob = resp.read()
    with open(out, "wb") as fh:
        fh.write(blob)

    print("saved  : %s (%d bytes)" % (out, len(blob)))
    print("\nNext: view this PNG with the Read tool to confirm it is the right portrait,")
    print("then convert it:")
    print('  ffmpeg -y -v error -i "%s" -c:v libwebp -pix_fmt yuva420p \\' % out)
    print("    -quality 80 -compression_level 6 assets/<assetname>.webp")
    return 0


if __name__ == "__main__":
    sys.exit(main())
