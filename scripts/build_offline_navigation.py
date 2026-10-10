"""Build the bundled Sri Lanka road graph. No map downloads happen in the app.

Run with the project-local Python environment described in docs/offline-navigation.md.
Output is a gzip-compressed little-endian CSR graph and an ODbL provenance manifest.
"""
import argparse
from array import array
from collections import Counter, defaultdict
from datetime import datetime, timezone
import gzip
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE_URL = "https://download.geofabrik.de/asia/sri-lanka-latest.osm.pbf"
CLASSES = ["motorway", "trunk", "primary", "secondary", "tertiary",
           "unclassified", "residential", "living_street", "service", "track"]
SPEEDS = [80, 60, 50, 45, 35, 30, 25, 15, 15, 10]
BLOCKED = {"no", "private", "customers", "delivery", "agricultural", "forestry", "destination"}


def policy(tags):
    """Conservative public motor-road profile. Vehicle-specific restrictions win."""
    highway = tags.get("highway", "")
    base = highway.removesuffix("_link")
    if base not in CLASSES or tags.get("area") == "yes":
        return None
    if any(k in tags for k in ("access:conditional", "vehicle:conditional",
                               "motor_vehicle:conditional", "motorcar:conditional",
                               "oneway:conditional", "oneway:motorcar:conditional",
                               "oneway:motor_vehicle:conditional", "motorcar:forward:conditional",
                               "motorcar:backward:conditional", "motor_vehicle:forward:conditional",
                               "motor_vehicle:backward:conditional")):
        return None  # Time-dependent legality needs a calendar evaluator.
    access = next((tags[k] for k in ("motorcar", "motor_vehicle", "vehicle", "access") if k in tags), "yes")
    if access in BLOCKED:
        return None
    index = CLASSES.index(base)
    flags = 1  # car
    if base != "motorway" and tags.get("motorroad") != "yes" and tags.get("motorcycle", "yes") not in BLOCKED:
        flags |= 2  # three-wheeler profile avoids expressways
    if tags.get("junction") == "roundabout":
        flags |= 4
    direction = tags.get("oneway:motorcar", tags.get("oneway:motor_vehicle", tags.get("oneway")))
    if direction is None:
        direction = "yes" if base == "motorway" or flags & 4 else "no"
    if direction in {"reversible", "alternating"}:
        return None
    forward = direction not in {"-1", "reverse"}
    backward = direction not in {"yes", "true", "1"}
    if tags.get("motorcar:forward", tags.get("motor_vehicle:forward", tags.get("vehicle:forward"))) in BLOCKED:
        forward = False
    if tags.get("motorcar:backward", tags.get("motor_vehicle:backward", tags.get("vehicle:backward"))) in BLOCKED:
        backward = False
    speed = SPEEDS[index]
    try:
        value = tags.get("maxspeed", "").split(";")[0].strip()
        if value:
            speed = min(speed, max(5, int(float(value.replace(" mph", "")) * (1.609344 if "mph" in value else 1))))
    except ValueError:
        pass
    return index, speed, flags, forward, backward


def meters(a, b):
    lat1, lon1, lat2, lon2 = [v * math.pi / 180 / 1e6 for v in (*a, *b)]
    value = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 12742000 * math.asin(min(1, math.sqrt(value)))


def simplify(points, tolerance=900):
    """Douglas-Peucker in E6 degrees (~100 m), for the overview map only."""
    keep = {0, len(points) - 1}
    pending = [(0, len(points) - 1)]
    while pending:
        first, last = pending.pop()
        a, b = points[first], points[last]
        dx, dy = b[0] - a[0], b[1] - a[1]
        squared = dx * dx + dy * dy
        best, index = tolerance * tolerance, None
        for i in range(first + 1, last):
            p = points[i]
            t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / squared)) if squared else 0
            distance = (p[0] - a[0] - t * dx) ** 2 + (p[1] - a[1] - t * dy) ** 2
            if distance > best:
                best, index = distance, i
        if index is not None:
            keep.add(index)
            pending.extend([(first, index), (index, last)])
    return [points[i] for i in sorted(keep)]


def download(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        print(f"Using cached source: {path.name}", flush=True)
        return
    temp = path.with_suffix(".partial")
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "RideXOfflineNavigationBuilder/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response, temp.open("wb") as output:
        count = 0
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
            count += len(chunk)
            if count % (16 * 1024 * 1024) == 0:
                print(f"Downloaded {count // 1024 // 1024} MiB", flush=True)
    temp.replace(path)


def build(source, output):
    import osmium

    class Roads(osmium.SimpleHandler):
        def __init__(self):
            super().__init__()
            self.coords = {}
            self.ways = []
            self.blocked_nodes = set()
            self.restrictions = []
            self.places = []
            self.coasts = []
            self.skipped = Counter()

        def node(self, node):
            tags = dict(node.tags)
            access = next((tags[k] for k in ("motorcar", "motor_vehicle", "vehicle", "access") if k in tags), "")
            if access in BLOCKED or (tags.get("barrier") in {"bollard", "block", "bus_trap", "sump_buster", "cycle_barrier", "gate", "lift_gate"}
                                     and access not in {"yes", "permissive", "designated"}):
                self.blocked_nodes.add(node.id)
            if tags.get("place") in {"city", "town", "village", "suburb", "hamlet"} and tags.get("name"):
                self.places.append([tags.get("name:en", tags["name"]), round(node.location.lat * 1e6),
                                    round(node.location.lon * 1e6), tags["place"], tags.get("name", "")])

        def way(self, way):
            tags = dict(way.tags)
            if tags.get("natural") == "coastline":
                self.coasts.append([[round(n.lat * 1e6), round(n.lon * 1e6)] for n in way.nodes if n.location.valid()])
            rules = policy(tags)
            if rules is None:
                if tags.get("highway"):
                    self.skipped[tags["highway"]] += 1
                return
            nodes = []
            for node in way.nodes:
                if not node.location.valid():
                    return
                self.coords[node.ref] = (round(node.lat * 1e6), round(node.lon * 1e6))
                nodes.append(node.ref)
            if len(nodes) > 1:
                self.ways.append((way.id, nodes, tags.get("name:en", tags.get("name", tags.get("ref", ""))), *rules))

        def relation(self, relation):
            tags = dict(relation.tags)
            if tags.get("type") != "restriction":
                return
            restriction = tags.get("restriction:motorcar", tags.get("restriction:motor_vehicle", tags.get("restriction", "")))
            exceptions = tags.get("except", "").split(";")
            if "motorcar" in exceptions or "motor_vehicle" in exceptions:
                return
            members = [(m.role, m.type, m.ref) for m in relation.members]
            self.restrictions.append((restriction, members, any("conditional" in k for k in tags)))

    handler = Roads()
    print("Reading motor roads, places and turn restrictions…", flush=True)
    handler.apply_file(str(source), locations=True, idx="sparse_mem_array", filters=[
        osmium.filter.KeyFilter("highway", "natural", "type", "place", "barrier",
                               "access", "vehicle", "motor_vehicle", "motorcar")])
    print(f"Collected {len(handler.coords):,} road nodes and {len(handler.ways):,} road ways; building graph...", flush=True)
    # Sorting by grid cell makes spatial queries contiguous without an expensive runtime index.
    ids = sorted(handler.coords, key=lambda nid: (handler.coords[nid][0] // 20000, handler.coords[nid][1] // 20000, nid))
    lookup = {nid: i for i, nid in enumerate(ids)}
    n = len(ids)
    nodes = array("i", (v for nid in ids for v in handler.coords[nid]))
    source_nodes, targets, lengths, road_ids = array("I"), array("I"), array("I"), array("I")
    roads = []
    overview = []
    way_lookup = {}
    for way_id, refs, name, kind, speed, flags, forward, backward in handler.ways:
        rid = len(roads)
        roads.append([name, kind, speed, flags])
        if kind <= 4:
            overview.append([kind, simplify([handler.coords[ref] for ref in refs])])
        way_lookup[way_id] = rid
        for a, b in zip(refs, refs[1:]):
            if a == b or a in handler.blocked_nodes or b in handler.blocked_nodes:
                continue
            length = max(1, round(meters(handler.coords[a], handler.coords[b]) * 100))
            if forward:
                source_nodes.append(lookup[a]); targets.append(lookup[b]); lengths.append(length); road_ids.append(rid)
            if backward:
                source_nodes.append(lookup[b]); targets.append(lookup[a]); lengths.append(length); road_ids.append(rid)
    e = len(targets)
    counts = array("I", [0]) * n
    for node in source_nodes:
        counts[node] += 1
    starts = array("I", [0])
    for count in counts:
        starts.append(starts[-1] + count)
    positions = array("I", starts[:-1])
    csr_targets, csr_lengths, csr_roads = (array("I", [0]) * e for _ in range(3))
    for i, node in enumerate(source_nodes):
        index = positions[node]
        csr_targets[index] = targets[i]; csr_lengths[index] = lengths[i]; csr_roads[index] = road_ids[i]
        positions[node] += 1
    # Keep restrictions in way/node form; routing states carry the incoming edge.
    restrictions = []
    excluded_complex = []
    for restriction, members, conditional in handler.restrictions:
        froms = [way_lookup[ref] for role, typ, ref in members if role == "from" and typ == "w" and ref in way_lookup]
        tos = [way_lookup[ref] for role, typ, ref in members if role == "to" and typ == "w" and ref in way_lookup]
        vias = [lookup[ref] for role, typ, ref in members if role == "via" and typ == "n" and ref in lookup]
        via_ways = [way_lookup[ref] for role, typ, ref in members if role == "via" and typ == "w" and ref in way_lookup]
        if vias and froms and tos and not conditional and (restriction.startswith("no_") or restriction.startswith("only_")):
            for via in vias:
                for frm in froms:
                    restrictions.append([via, frm, tos, restriction])
        elif froms and (via_ways or conditional):
            # Conservatively disallow entering a complex restricted path rather than route through it illegally.
            excluded_complex.append([froms, via_ways or tos])
    cells = []
    for i, nid in enumerate(ids):
        lat, lon = handler.coords[nid]
        key = [lat // 20000, lon // 20000]
        if not cells or cells[-1][:2] != key:
            cells.append([*key, i, i + 1])
        else:
            cells[-1][3] = i + 1
    with osmium.io.Reader(str(source)) as reader:
        data_timestamp = reader.header().get("osmosis_replication_timestamp")
    metadata = {"version": 1, "region": "Sri Lanka", "cellE6": 20000, "cells": cells,
                "roads": roads, "places": handler.places, "coastlines": handler.coasts,
                "overviewRoads": overview,
                "restrictions": restrictions, "excludedComplexTurns": excluded_complex,
                "sourceTimestamp": data_timestamp, "maxSpeedKph": 80,
                "attribution": "© OpenStreetMap contributors", "license": "ODbL-1.0"}
    encoded = json.dumps(metadata, ensure_ascii=False, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as stream:
        stream.write(struct.pack("<8sIIII", b"RDXNAV1\0", n, e, len(encoded), 1))
        stream.write(encoded)
        for values in (nodes, starts, csr_targets, csr_lengths, csr_roads):
            if sys.byteorder != "little":
                values.byteswap()
            stream.write(values.tobytes())
    manifest = {"region": "Sri Lanka", "sourceUrl": SOURCE_URL,
                "sourceTimestamp": data_timestamp, "sourceSha256": hashlib.file_digest(source.open("rb"), "sha256").hexdigest(),
                "assetSha256": hashlib.file_digest(output.open("rb"), "sha256").hexdigest(),
                "builtAtUtc": datetime.now(timezone.utc).isoformat(), "nodes": n, "directedEdges": e,
                "roadWays": len(roads), "places": len(handler.places), "turnRestrictions": len(restrictions),
                "complexRestrictionsConservativelyBlocked": len(excluded_complex), "assetBytes": output.stat().st_size,
                "license": "ODbL-1.0", "copyright": "© OpenStreetMap contributors",
                "copyrightUrl": "https://www.openstreetmap.org/copyright",
                "licenseUrl": "https://opendatacommons.org/licenses/odbl/1-0/",
                "profile": "Public motor roads. Private/destination-only, conditional-access and non-motor roads excluded."}
    output.with_name("manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({k: manifest[k] for k in ("nodes", "directedEdges", "roadWays", "places", "turnRestrictions", "assetBytes")}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / ".map-build/sri-lanka-latest.osm.pbf")
    parser.add_argument("--output", type=Path, default=ROOT / "packages/offline_trip/assets/sri_lanka.nav.gz")
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    if args.download:
        download(args.source)
    build(args.source, args.output)
