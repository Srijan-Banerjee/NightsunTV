#!/usr/bin/env python3
"""Expands the NightsunTV catalog by merging:
1. The existing curated catalog.json
2. Free-TV/IPTV curated global playlist (2,200+ streams)
3. Samsung TV Plus global FAST channels (2,600+ streams)
4. Pluto TV global FAST channels (3,100+ streams)
5. Plex TV global FAST channels (2,800+ streams)
6. Tubi TV free live channels
7. Unmapped streams from iptv-org streams.json (2,400+ streams)

Deduplicates streams, normalizes categories & country codes,
and writes updated assets/data/catalog.json and catalog_meta.json.
"""

from __future__ import annotations

import concurrent.futures
import hashlib
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "assets" / "data"
CATALOG_PATH = DATA_DIR / "catalog.json"
META_PATH = DATA_DIR / "catalog_meta.json"
IPTV_CACHE_STREAMS = ROOT / ".cache" / "iptv-org" / "streams.json"

SOURCES_M3U = [
    {
        "name": "Free-TV Curated",
        "url": "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8",
        "default_country": "ZZ",
        "network": "Free-TV",
    },
    {
        "name": "Samsung TV Plus Global",
        "url": "https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/samsungtvplus_all.m3u",
        "default_country": "US",
        "network": "Samsung TV Plus",
    },
    {
        "name": "Pluto TV Global",
        "url": "https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/plutotv_all.m3u",
        "default_country": "US",
        "network": "Pluto TV",
    },
    {
        "name": "Plex TV Global",
        "url": "https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/plex_all.m3u",
        "default_country": "US",
        "network": "Plex",
    },
    {
        "name": "Tubi TV Live",
        "url": "https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/tubi_playlist.m3u",
        "default_country": "US",
        "network": "Tubi",
    },
]

CATEGORY_MAP = {
    "news": "news",
    "opinion": "news",
    "weather": "weather",
    "sports": "sports",
    "sport": "sports",
    "action": "movies",
    "movie": "movies",
    "movies": "movies",
    "cinema": "movies",
    "film": "movies",
    "drama": "entertainment",
    "comedy": "comedy",
    "animation": "animation",
    "anime": "animation",
    "cartoon": "animation",
    "kids": "kids",
    "children": "kids",
    "family": "family",
    "music": "music",
    "doc": "documentary",
    "documentary": "documentary",
    "history": "documentary",
    "science": "science",
    "tech": "science",
    "lifestyle": "lifestyle",
    "travel": "travel",
    "food": "cooking",
    "cooking": "cooking",
    "auto": "auto",
    "outdoor": "outdoor",
    "nature": "documentary",
    "crime": "entertainment",
    "reality": "entertainment",
    "series": "series",
    "classic": "classic",
    "general": "general",
    "entertainment": "entertainment",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def download_m3u(source_info: dict) -> tuple[str, str]:
    name = source_info["name"]
    url = source_info["url"]
    log(f"  Downloading {name}…")
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"},
    )
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                content = resp.read().decode("utf-8", errors="ignore")
                log(f"  Downloaded {name}: {len(content)} chars")
                return name, content
        except Exception as e:
            if attempt < 3:
                time.sleep(2 * attempt)
            else:
                log(f"  Failed downloading {name}: {e}")
                return name, ""
    return name, ""


def normalize_category(group: str | None) -> list[str]:
    if not group:
        return ["general"]
    g = group.lower()
    cats = []
    for k, v in CATEGORY_MAP.items():
        if k in g and v not in cats:
            cats.append(v)
    return cats[:3] or ["general"]


def parse_m3u(content: str, default_country: str, network: str) -> list[dict]:
    items = []
    lines = content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("#EXTINF:"):
            tvg_name_m = re.search(r'tvg-name="([^"]+)"', line)
            tvg_logo_m = re.search(r'tvg-logo="([^"]+)"', line)
            tvg_id_m = re.search(r'tvg-id="([^"]+)"', line)
            tvg_country_m = re.search(r'tvg-country="([^"]+)"', line)
            group_m = re.search(r'group-title="([^"]+)"', line)
            channel_id_m = re.search(r'channel-id="([^"]+)"', line)

            comma_idx = line.rfind(",")
            display_name = line[comma_idx + 1 :].strip() if comma_idx != -1 else "Channel"
            clean_name = re.sub(r"\s*[ⓈⓉⓎⓅ]\s*$", "", display_name).strip()
            name = clean_name or (tvg_name_m.group(1) if tvg_name_m else "Channel")

            country = (tvg_country_m.group(1) if tvg_country_m else default_country).upper()
            if country == "GB":
                country = "UK"

            cid = (
                tvg_id_m.group(1)
                if tvg_id_m
                else (channel_id_m.group(1) if channel_id_m else "")
            )

            group_title = group_m.group(1) if group_m else None
            categories = normalize_category(group_title)

            logo = tvg_logo_m.group(1).strip() if tvg_logo_m else None

            # Next line is stream URL
            i += 1
            while i < len(lines) and (not lines[i].strip() or lines[i].strip().startswith("#")):
                i += 1
            if i < len(lines):
                stream_url = lines[i].strip()
                if stream_url.startswith("http://") or stream_url.startswith("https://"):
                    items.append(
                        {
                            "name": name,
                            "id": cid,
                            "country": country,
                            "categories": categories,
                            "logo": logo,
                            "url": stream_url,
                            "network": network,
                        }
                    )
        i += 1
    return items


def main():
    log("=== Expanding NightsunTV Catalog with All Free IPTV Streams ===")
    if not CATALOG_PATH.exists():
        log(f"Error: {CATALOG_PATH} not found.")
        sys.exit(1)

    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    existing_channels: list[dict] = catalog["channels"]
    log(f"Loaded existing catalog with {len(existing_channels)} channels.")

    # Index existing
    existing_by_id = {ch["id"]: ch for ch in existing_channels}
    existing_urls = set(
        s["url"].strip() for ch in existing_channels for s in ch.get("sources", [])
    )
    # Normalized name + country index
    existing_by_name_country: dict[tuple[str, str], dict] = {
        (ch["name"].strip().lower(), ch["country"]): ch for ch in existing_channels
    }

    # 1. Download all M3U sources in parallel
    downloaded_m3u = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = pool.map(download_m3u, SOURCES_M3U)
        for name, content in results:
            downloaded_m3u[name] = content

    parsed_m3u_channels: list[dict] = []
    for s_info in SOURCES_M3U:
        content = downloaded_m3u.get(s_info["name"], "")
        if content:
            items = parse_m3u(content, s_info["default_country"], s_info["network"])
            log(f"  Parsed {len(items)} streams from {s_info['name']}")
            parsed_m3u_channels.extend(items)

    # 2. Add unmapped streams from iptv-org streams.json if available
    if IPTV_CACHE_STREAMS.exists():
        raw_streams = json.loads(IPTV_CACHE_STREAMS.read_text(encoding="utf-8"))
        unmapped_count = 0
        for s in raw_streams:
            s_url = (s.get("url") or "").strip()
            s_title = (s.get("title") or "").strip()
            if not s_url or not s_title or s_url in existing_urls:
                continue
            if s.get("channel") is None:
                parsed_m3u_channels.append(
                    {
                        "name": s_title,
                        "id": "",
                        "country": "ZZ",
                        "categories": ["general"],
                        "logo": None,
                        "url": s_url,
                        "network": None,
                        "quality": s.get("quality"),
                    }
                )
                unmapped_count += 1
        log(f"  Added {unmapped_count} unmapped streams from iptv-org streams.json")

    # 3. Merge new items
    added_channels_count = 0
    added_sources_count = 0

    for item in parsed_m3u_channels:
        url = item["url"].strip()
        if not url or url in existing_urls:
            continue
        existing_urls.add(url)

        name = item["name"].strip()
        country = item["country"]
        key = (name.lower(), country)

        new_source = {
            "url": url,
            "quality": item.get("quality"),
            "userAgent": None,
            "referrer": None,
            "title": name,
        }

        # If matching channel exists, append as an alternative mirror!
        matched_channel = existing_by_name_country.get(key)
        if matched_channel:
            matched_channel["sources"].append(new_source)
            added_sources_count += 1
            if not matched_channel.get("logo") and item.get("logo"):
                matched_channel["logo"] = item["logo"]
            continue

        # Otherwise create a new channel entry
        raw_cid = item.get("id") or ""
        clean_slug = re.sub(r"[^a-zA-Z0-9]+", "", name)
        cid = f"{clean_slug}.{country.lower()}" if clean_slug else f"ch_{abs(hash(url))}"
        if cid in existing_by_id:
            cid = f"{cid}_{abs(hash(url)) % 10000}"

        new_ch = {
            "id": cid,
            "name": name,
            "altNames": [],
            "country": country,
            "categories": item["categories"],
            "languages": ["eng"] if country in ("US", "UK", "CA", "AU", "NZ") else ["und"],
            "network": item.get("network"),
            "website": None,
            "launched": None,
            "nsfw": False,
            "logo": item.get("logo"),
            "logoFormat": "PNG" if (item.get("logo") or "").lower().endswith(".png") else "JPEG",
            "sources": [new_source],
        }

        existing_channels.append(new_ch)
        existing_by_id[cid] = new_ch
        existing_by_name_country[key] = new_ch
        added_channels_count += 1
        added_sources_count += 1

    log(
        f"Merge complete! Added {added_channels_count} new channels and "
        f"{added_sources_count} total new stream mirrors."
    )

    # Sort channels alphabetically by name
    existing_channels.sort(key=lambda c: (c["name"].casefold(), c["id"]))

    # Update metadata & counts
    total_sources = sum(len(c.get("sources", [])) for c in existing_channels)
    multi_source = sum(1 for c in existing_channels if len(c.get("sources", [])) > 1)
    with_logo = sum(1 for c in existing_channels if c.get("logo"))

    used_countries = set(c["country"] for c in existing_channels)
    used_categories = set(cat for c in existing_channels for cat in c.get("categories", []))
    used_languages = set(lang for c in existing_channels for lang in c.get("languages", []))

    counts = {
        "channels": len(existing_channels),
        "sources": total_sources,
        "countries": len(used_countries),
        "languages": len(used_languages),
        "categories": len(used_categories),
        "withLogo": with_logo,
        "multiSource": multi_source,
        "nsfw": 2,
    }

    catalog["counts"] = counts
    catalog["generatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    log(f"Writing updated catalog: {counts['channels']} channels, {counts['sources']} sources…")
    catalog_json_str = json.dumps(catalog, ensure_ascii=False, separators=(",", ":"))
    CATALOG_PATH.write_text(catalog_json_str, encoding="utf-8")

    # Write catalog_meta.json
    hasher = hashlib.sha256()
    hasher.update(catalog_json_str.encode("utf-8"))
    sha = hasher.hexdigest()

    meta = {
        "generatedAt": catalog["generatedAt"],
        "sha256": sha,
        "bytes": len(catalog_json_str.encode("utf-8")),
        "counts": counts,
        "topCountries": [
            {"code": code, "channels": sum(1 for c in existing_channels if c["country"] == code)}
            for code in ["US", "IN", "RU", "DE", "IT", "BR", "UK", "ES", "FR", "CA"]
        ],
    }
    META_PATH.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    log("Successfully updated catalog.json and catalog_meta.json!")


if __name__ == "__main__":
    main()
