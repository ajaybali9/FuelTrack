#!/usr/bin/env python3
"""Build geocoded UK MOT stations asset from the DVSA Active MOT CSV.

Source: https://www.gov.uk/government/publications/active-mot-test-stations
Licence: Open Government Licence v3.0
Geocoder: https://api.postcodes.io/ (MIT)

Usage:
  python3 Scripts/build-uk-mot-stations.py
  python3 Scripts/build-uk-mot-stations.py --csv /path/to/active-mot-stations.csv

Writes:
  Sources/FuelTrack/Resources/uk-mot-stations.json
  Sources/FuelTrack/Resources/uk-mot-stations.meta.json
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

DVSA_CSV_URL = (
    "https://assets.publishing.service.gov.uk/media/"
    "6abcee45943e890cb55e5d00/active-mot-stations.csv"
)
POSTCODES_BULK = "https://api.postcodes.io/postcodes"
BATCH = 100
REPO = Path(__file__).resolve().parents[1]
OUT_DIR = REPO / "Sources" / "FuelTrack" / "Resources"
CACHE_PATH = Path("/tmp/mot-build/postcode-cache.json")


def fetch_csv(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.stat().st_size > 0:
        return path
    print(f"Downloading DVSA CSV → {path}", flush=True)
    with urllib.request.urlopen(DVSA_CSV_URL, timeout=120) as resp:
        path.write_bytes(resp.read())
    return path


def yes(value: str | None) -> bool:
    return (value or "").strip().upper() == "Y"


def load_rows(csv_path: Path) -> list[dict]:
    with csv_path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = []
        for raw in reader:
            if not yes(raw.get("Class_4")):
                continue
            postcode = (raw.get("Postcode") or "").strip().upper()
            if not postcode:
                continue
            classes = [
                n
                for n, key in (
                    (1, "Class_1"),
                    (2, "Class_2"),
                    (3, "Class_3"),
                    (4, "Class_4"),
                    (5, "Class_5"),
                    (7, "Class_7"),
                )
                if yes(raw.get(key))
            ]
            address = ", ".join(
                part
                for part in (
                    (raw.get("Address1") or "").strip(),
                    (raw.get("Address2") or "").strip(),
                    (raw.get("Address3") or "").strip(),
                )
                if part
            )
            rows.append(
                {
                    "id": (raw.get("Site_Number") or "").strip(),
                    "name": (raw.get("Trading_Name") or "").strip(),
                    "address": address,
                    "town": (raw.get("Town") or "").strip(),
                    "postcode": postcode,
                    "phone": (raw.get("Phone") or "").strip(),
                    "classes": classes,
                }
            )
        return rows


def load_cache() -> dict[str, dict | None]:
    if CACHE_PATH.exists():
        return json.loads(CACHE_PATH.read_text())
    return {}


def save_cache(cache: dict[str, dict | None]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    CACHE_PATH.write_text(json.dumps(cache, separators=(",", ":")))


def bulk_lookup(postcodes: list[str]) -> dict[str, dict | None]:
    payload = json.dumps({"postcodes": postcodes}).encode()
    req = urllib.request.Request(
        POSTCODES_BULK,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "FuelTrack-MOT-Build/1.0 (personal; github.com/ajaybali9/FuelTrack)",
        },
        method="POST",
    )
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                body = json.loads(resp.read().decode())
            break
        except urllib.error.HTTPError as exc:
            if exc.code in (429, 500, 502, 503, 504) and attempt < 4:
                time.sleep(2 ** attempt)
                continue
            raise
    out: dict[str, dict | None] = {}
    for item in body.get("result") or []:
        query = (item.get("query") or "").strip().upper()
        result = item.get("result")
        if result and result.get("latitude") is not None and result.get("longitude") is not None:
            out[query] = {
                "lat": float(result["latitude"]),
                "lon": float(result["longitude"]),
            }
        else:
            out[query] = None
    return out


def geocode(postcodes: list[str]) -> dict[str, dict | None]:
    cache = load_cache()
    missing = [pc for pc in postcodes if pc not in cache]
    print(f"Postcodes: {len(postcodes)} unique, {len(missing)} to look up", flush=True)
    for i in range(0, len(missing), BATCH):
        batch = missing[i : i + BATCH]
        looked = bulk_lookup(batch)
        cache.update(looked)
        # Keep keys even when None so we don't retry forever.
        for pc in batch:
            cache.setdefault(pc, None)
        save_cache(cache)
        done = min(i + BATCH, len(missing))
        print(f"  geocoded {done}/{len(missing)}", flush=True)
        time.sleep(0.15)
    return cache


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("/tmp/mot-build/active-mot-stations.csv"))
    args = parser.parse_args()

    csv_path = fetch_csv(args.csv)
    rows = load_rows(csv_path)
    postcodes = sorted({r["postcode"] for r in rows})
    coords = geocode(postcodes)

    stations = []
    skipped = 0
    for row in rows:
        point = coords.get(row["postcode"])
        if not point:
            skipped += 1
            continue
        stations.append(
            {
                "id": row["id"],
                "name": row["name"],
                "address": row["address"],
                "town": row["town"],
                "postcode": row["postcode"],
                "phone": row["phone"],
                "lat": round(point["lat"], 6),
                "lon": round(point["lon"], 6),
                "classes": row["classes"],
            }
        )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_json = OUT_DIR / "uk-mot-stations.json"
    out_meta = OUT_DIR / "uk-mot-stations.meta.json"
    payload = {"stations": stations}
    out_json.write_text(json.dumps(payload, separators=(",", ":")))
    meta = {
        "source": "DVSA Active MOT test stations",
        "sourceURL": "https://www.gov.uk/government/publications/active-mot-test-stations",
        "licence": "Open Government Licence v3.0",
        "geocoder": "postcodes.io",
        "filter": "Class_4 = Y",
        "builtAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "csvPath": str(csv_path),
        "stationCount": len(stations),
        "skippedNoCoords": skipped,
        "uniquePostcodes": len(postcodes),
    }
    out_meta.write_text(json.dumps(meta, indent=2) + "\n")
    size_mb = out_json.stat().st_size / (1024 * 1024)
    print(
        f"Wrote {len(stations)} stations ({size_mb:.2f} MiB) → {out_json}\n"
        f"Skipped {skipped} without coordinates. Meta → {out_meta}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
