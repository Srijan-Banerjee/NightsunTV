#!/usr/bin/env python3
"""Build the bundled NightsunTV catalog from the official iptv-org API.

The script is intentionally dependency-free (Python standard library only).
It downloads the current iptv-org data into .cache/iptv-org, joins channels,
streams, logos and metadata, and writes assets/data/catalog.json.

Usage:
  python3 tool/fetch_catalog.py            # use cached downloads when present
  python3 tool/fetch_catalog.py --refresh  # force fresh downloads
  python3 tool/fetch_catalog.py --offline  # never touch the network
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache" / "iptv-org"
OUT_DIR = ROOT / "assets" / "data"
API = "https://iptv-org.github.io/api"
FILES = [
    "channels.json",
    "streams.json",
    "logos.json",
    "feeds.json",
    "categories.json",
    "countries.json",
    "languages.json",
    "blocklist.json",
]
USER_AGENT = "NightsunTV/1.0 catalog builder (+https://github.com/iptv-org/iptv)"
RASTER_FORMATS = {"PNG", "JPEG", "JPG", "WEBP", "GIF", "AVIF"}
SUPPORTED_FORMATS = RASTER_FORMATS | {"SVG"}
FORMAT_PREFERENCE = {"PNG": 5, "WEBP": 4, "JPEG": 3, "JPG": 3, "GIF": 2, "AVIF": 1, "SVG": 0}
QUALITY_RE = re.compile(r"(\d{3,4})[pi]", re.IGNORECASE)


def log(message: str) -> None:
    print(message, flush=True)


def download(name: str, refresh: bool, offline: bool) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    target = CACHE / name
    if target.exists() and not refresh:
        return target
    if offline:
        if target.exists():
            return target
        raise RuntimeError(f"missing cached file {target} and --offline was requested")
    url = f"{API}/{name}"
    tmp = target.with_suffix(target.suffix + ".part")
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            log(f"  downloading {name} (attempt {attempt}/3)…")
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=90) as response:
                with open(tmp, "wb") as handle:
                    while True:
                        chunk = response.read(1024 * 256)
                        if not chunk:
                            break
                        handle.write(chunk)
            if tmp.stat().st_size < 100:
                raise RuntimeError("download was unexpectedly small")
            tmp.replace(target)
            return target
        except Exception as error:  # noqa: BLE001 - retry loop
            last_error = error
            if tmp.exists():
                tmp.unlink(missing_ok=True)
            if attempt < 3:
                time.sleep(1.5 * attempt)
    raise RuntimeError(f"could not download {name}: {last_error}")


def load_json(path: Path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def list_of_dicts(value) -> list[dict]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def clean_text(value) -> str | None:
    if not isinstance(value, str):
        return None
    value = " ".join(value.split()).strip()
    return value or None


def clean_list(value, limit: int = 8) -> list[str]:
    if not isinstance(value, list):
        return []
    result: list[str] = []
    for item in value:
        text = clean_text(item)
        if text and text not in result:
            result.append(text)
        if len(result) >= limit:
            break
    return result


def quality_value(value) -> int:
    if not isinstance(value, str):
        return 0
    if "4k" in value.lower() or "2160" in value:
        return 2160
    match = QUALITY_RE.search(value)
    return int(match.group(1)) if match else 0


def is_http_url(value) -> bool:
    if not isinstance(value, str):
        return False
    try:
        parsed = urllib.parse.urlsplit(value.strip())
    except ValueError:
        return False
    return parsed.scheme.lower() in ("http", "https") and bool(parsed.netloc)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="force fresh API downloads")
    parser.add_argument("--offline", action="store_true", help="use cached files only")
    args = parser.parse_args()
    if args.refresh and args.offline:
        parser.error("--refresh and --offline cannot be combined")

    started = time.time()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    log("NightsunTV catalog builder")
    log(f"  cache: {CACHE}")

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        paths = dict(
            zip(
                FILES,
                pool.map(lambda name: download(name, args.refresh, args.offline), FILES),
            )
        )

    channels_raw = list_of_dicts(load_json(paths["channels.json"]))
    streams_raw = list_of_dicts(load_json(paths["streams.json"]))
    logos_raw = list_of_dicts(load_json(paths["logos.json"]))
    feeds_raw = list_of_dicts(load_json(paths["feeds.json"]))
    categories_raw = list_of_dicts(load_json(paths["categories.json"]))
    countries_raw = list_of_dicts(load_json(paths["countries.json"]))
    languages_raw = list_of_dicts(load_json(paths["languages.json"]))
    blocklist_raw = list_of_dicts(load_json(paths["blocklist.json"]))
    log(
        f"  loaded {len(channels_raw)} channels, {len(streams_raw)} streams, "
        f"{len(logos_raw)} logos, {len(feeds_raw)} feeds"
    )

    blocked = {
        item.get("channel")
        for item in blocklist_raw
        if isinstance(item.get("channel"), str)
    }

    categories: dict[str, str] = {}
    for item in categories_raw:
        cid = clean_text(item.get("id"))
        name = clean_text(item.get("name"))
        if cid and name:
            categories[cid] = name
    if "general" not in categories:
        categories["general"] = "General"

    countries: dict[str, dict] = {}
    for item in countries_raw:
        code = clean_text(item.get("code"))
        name = clean_text(item.get("name"))
        if not code or not name:
            continue
        countries[code.upper()] = {
            "code": code.upper(),
            "name": name,
            "flag": clean_text(item.get("flag")) or "🌐",
            "languages": clean_list(item.get("languages"), 6),
        }
    countries.setdefault(
        "ZZ",
        {"code": "ZZ", "name": "International", "flag": "🌐", "languages": []},
    )
    countries.setdefault(
        "UK",
        {"code": "UK", "name": "United Kingdom", "flag": "🇬🇧", "languages": ["eng"]},
    )

    language_names: dict[str, str] = {}
    for item in languages_raw:
        code = clean_text(item.get("code"))
        name = clean_text(item.get("name"))
        if code and name:
            language_names[code] = name
    language_names.setdefault("und", "Undetermined")

    # Best logo per channel. Prefer a raster image, then the largest source.
    best_logo: dict[str, dict] = {}
    for item in logos_raw:
        channel_id = clean_text(item.get("channel"))
        url = clean_text(item.get("url"))
        if not channel_id or not url or item.get("in_use") is not True:
            continue
        fmt = (clean_text(item.get("format")) or "").upper()
        if fmt not in SUPPORTED_FORMATS or not is_http_url(url):
            continue
        try:
            width = int(item.get("width") or 0)
            height = int(item.get("height") or 0)
        except (TypeError, ValueError):
            width = height = 0
        raster = 1 if fmt in RASTER_FORMATS else 0
        score = (raster, width * height, FORMAT_PREFERENCE.get(fmt, 0))
        current = best_logo.get(channel_id)
        if current is None or score > current["score"]:
            best_logo[channel_id] = {"url": url, "format": fmt, "score": score}

    feeds_by_channel: dict[str, list[dict]] = {}
    for item in feeds_raw:
        channel_id = clean_text(item.get("channel"))
        if channel_id:
            feeds_by_channel.setdefault(channel_id, []).append(item)

    def languages_for(channel_id: str, country_code: str) -> list[str]:
        candidates = feeds_by_channel.get(channel_id, [])
        ordered = sorted(
            candidates,
            key=lambda feed: (
                0 if feed.get("is_main") is True else 1,
                str(feed.get("id") or ""),
            ),
        )
        result: list[str] = []
        for feed in ordered:
            for code in clean_list(feed.get("languages"), 6):
                if code not in result:
                    result.append(code)
            if result and feed.get("is_main") is True:
                break
        if not result:
            country = countries.get(country_code, {})
            result = clean_list(country.get("languages"), 3)
        return result[:3] or ["und"]

    streams_by_channel: dict[str, list[dict]] = {}
    for index, item in enumerate(streams_raw):
        channel_id = clean_text(item.get("channel"))
        url = clean_text(item.get("url"))
        if not channel_id or not url or not is_http_url(url):
            continue
        quality = clean_text(item.get("quality"))
        streams_by_channel.setdefault(channel_id, []).append(
            {
                "url": url,
                "quality": quality,
                "userAgent": clean_text(item.get("user_agent")),
                "referrer": clean_text(item.get("referrer")),
                "title": clean_text(item.get("title")),
                "_index": index,
            }
        )

    channels_out: list[dict] = []
    used_categories: set[str] = set()
    used_countries: set[str] = set()
    used_languages: set[str] = set()
    source_total = 0

    for item in channels_raw:
        channel_id = clean_text(item.get("id"))
        name = clean_text(item.get("name"))
        if not channel_id or not name:
            continue
        if channel_id in blocked:
            continue
        if item.get("closed") or item.get("replaced_by"):
            continue
        streams = streams_by_channel.get(channel_id)
        if not streams:
            continue

        # Deduplicate by exact URL, keeping the first indexed occurrence.
        unique: dict[str, dict] = {}
        for stream in streams:
            unique.setdefault(stream["url"], stream)
        ordered = sorted(
            unique.values(),
            key=lambda stream: (
                -quality_value(stream.get("quality")),
                0 if str(stream.get("url", "")).lower().startswith("https://") else 1,
                stream["_index"],
            ),
        )

        country_code = clean_text(item.get("country"))
        country_code = country_code.upper() if country_code else "ZZ"
        if country_code == "GB":
            country_code = "UK"
        if country_code not in countries:
            country_code = "ZZ"
        used_countries.add(country_code)

        channel_categories = [
            category
            for category in clean_list(item.get("categories"), 8)
            if category in categories
        ]
        if not channel_categories:
            channel_categories = ["general"]
        used_categories.update(channel_categories)

        languages = [
            code for code in languages_for(channel_id, country_code)
            if code in language_names
        ]
        if not languages:
            languages = ["und"]
        used_languages.update(languages)

        logo = best_logo.get(channel_id)
        launched = item.get("launched")
        if isinstance(launched, str) and launched.isdigit():
            launched = int(launched)
        if not isinstance(launched, int):
            launched = None

        sources = [
            {
                "url": stream["url"],
                "quality": stream.get("quality"),
                "userAgent": stream.get("userAgent"),
                "referrer": stream.get("referrer"),
                "title": stream.get("title"),
            }
            for stream in ordered
        ]
        source_total += len(sources)

        channels_out.append(
            {
                "id": channel_id,
                "name": name,
                "altNames": clean_list(item.get("alt_names"), 5),
                "country": country_code,
                "categories": channel_categories,
                "languages": languages,
                "network": clean_text(item.get("network")),
                "website": clean_text(item.get("website")),
                "launched": launched,
                "nsfw": bool(item.get("is_nsfw")) or "xxx" in channel_categories,
                "logo": logo["url"] if logo else None,
                "logoFormat": logo["format"] if logo else None,
                "sources": sources,
            }
        )

    channels_out.sort(key=lambda channel: (channel["name"].casefold(), channel["id"]))

    categories_out = [
        {"id": cid, "name": categories[cid]}
        for cid in sorted(used_categories, key=lambda cid: categories[cid].casefold())
    ]
    countries_out = [
        countries[code] for code in sorted(used_countries, key=lambda code: countries[code]["name"].casefold())
    ]
    languages_out = [
        {"code": code, "name": language_names[code]}
        for code in sorted(used_languages, key=lambda code: language_names.get(code, code).casefold())
    ]

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    counts = {
        "channels": len(channels_out),
        "sources": source_total,
        "countries": len(countries_out),
        "languages": len(languages_out),
        "categories": len(categories_out),
        "withLogo": sum(1 for channel in channels_out if channel["logo"]),
        "multiSource": sum(1 for channel in channels_out if len(channel["sources"]) > 1),
        "nsfw": sum(1 for channel in channels_out if channel["nsfw"]),
    }
    catalog = {
        "schema": 1,
        "generatedAt": generated_at,
        "source": {
            "name": "iptv-org",
            "repo": "https://github.com/iptv-org/iptv",
            "api": API,
        },
        "counts": counts,
        "categories": categories_out,
        "countries": countries_out,
        "languages": languages_out,
        "channels": channels_out,
    }

    payload = json.dumps(catalog, ensure_ascii=False, separators=(",", ":"))
    output = OUT_DIR / "catalog.json"
    output.write_text(payload, encoding="utf-8")
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    meta = {
        "generatedAt": generated_at,
        "sha256": digest,
        "bytes": len(payload.encode("utf-8")),
        "counts": counts,
        "topCountries": sorted(
            (
                {"code": channel["country"], "channels": sum(1 for c in channels_out if c["country"] == channel["country"])}
                for channel in channels_out
            ),
            key=lambda item: -item["channels"],
        )[:10],
    }
    # De-duplicate the country list above (the generator expression repeats entries).
    seen_countries: set[str] = set()
    top_countries = []
    for item in sorted(
        (
            (code, sum(1 for channel in channels_out if channel["country"] == code))
            for code in {channel["country"] for channel in channels_out}
        ),
        key=lambda pair: -pair[1],
    )[:10]:
        if item[0] not in seen_countries:
            seen_countries.add(item[0])
            top_countries.append({"code": item[0], "channels": item[1]})
    meta["topCountries"] = top_countries
    (OUT_DIR / "catalog_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    log("")
    log(f"  channels: {counts['channels']:,}")
    log(f"  sources:  {counts['sources']:,}")
    log(f"  countries:{counts['countries']:,}  languages: {counts['languages']:,}  categories: {counts['categories']:,}")
    log(f"  logos:    {counts['withLogo']:,}  multi-source: {counts['multiSource']:,}  nsfw: {counts['nsfw']:,}")
    log(f"  output:   {output.relative_to(ROOT)}  ({len(payload.encode('utf-8')) / 1024 / 1024:.1f} MB)")
    log(f"  sha256:   {digest}")
    log(f"  finished in {time.time() - started:.1f}s")
    if counts["channels"] < 8000:
        log("ERROR: fewer channels than expected; refusing a suspicious catalog")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
