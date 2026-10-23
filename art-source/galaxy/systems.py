"""Writes the game's star system content from the galaxy: one StarSystemDefinition per system, in
game/content/base/systems/<name>/<name>.tres, with its map ID, star, owner and position from galaxy.json and its
places from the tables in section 8 of docs/galaxy.md (Star systems).

galaxy.md stays the one place the systems are written down: change a system there (or move it in galaxy.json) and run
this again, rather than editing the definitions by hand. Each place's kind comes from its description:
- **bold** names are habitable worlds, and a moon when their numeral has a letter (II-b) or they say "moon";
- "battlefield" and "anomaly" at the start of the brackets give those kinds;
- a belt or comet cloud is an asteroid belt; a moon or a numeral with a letter is a moon;
- rock, ice, a gas giant or a bare numeral is a planet; anything else is a station.
Bare numerals (III, III-a) are named after the system (Mori III-a), as galaxy.md's naming rules say.

Run from the repository root:
    python art-source/galaxy/systems.py
"""

import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GALAXY_DOC = ROOT / "docs" / "galaxy.md"
GALAXY_DATA = HERE / "galaxy.json"
CONTENT = ROOT / "game" / "content" / "base" / "systems"
DEFINITION_SCRIPT = "res://scenes/galaxy/star_system_definition.gd"
PLACE_SCRIPT = "res://scenes/galaxy/system_place.gd"

# The enums of StarSystemDefinition and SystemPlace, in their order.
STARS = {"Red dwarf": 0, "Yellow": 1, "White": 2, "Binary": 3, "Neutron star": 4}
OWNERS = {"her": 0, "cheap": 1, "elite": 2, "free": 3, "contested": 4}
PLANET, MOON, BELT, STATION, BATTLEFIELD, ANOMALY = range(6)
KIND_NAMES = ["planet", "moon", "belt", "station", "battlefield", "anomaly"]
MIN_PLACES, MAX_PLACES = 2, 8

ROW = re.compile(r"^\| (?P<id>[HCEFX]\d+) \| (?P<where>[^|]+) \| (?P<name>[^|]+) \| (?P<star>[^|]+) \| (?P<places>.+) \|$")
HABITABLE = re.compile(r"^\*\*(?P<name>.+?)\*\* \((?P<numeral>[^)]*)\)(?:: (?P<note>.+))?$")
PLACE = re.compile(r"^(?P<name>.+?) \((?P<inside>.*)\)(?:: (?P<note>.+))?$")
NUMERAL = re.compile(r"^[IVX]+(?:-[a-z])?(?: and [IVX]+(?:-[a-z])?)?$")
LETTERED = re.compile(r"\b[IVX]+-[a-z]\b")


def place_kind(name: str, inside: str) -> int:
    """A place's kind from its name and what galaxy.md says about it in brackets."""
    text = inside.lower()
    if text.startswith("battlefield"):
        return BATTLEFIELD
    if text.startswith("anomaly"):
        return ANOMALY
    if re.search(r"\bbelt\b", text) or "Belt" in name or "comet" in text:
        return BELT
    if re.search(r"\bmoons?\b", text) or LETTERED.search(name):
        return MOON
    if re.search(r"\b(rock|ice|gas giant)\b", text) or NUMERAL.match(name.split(" ")[-1]):
        return PLANET
    return STATION


def parse_place(text: str, system: str) -> dict:
    """One place of a system's row: its name, kind, whether people live there, and the note about it."""
    habitable = HABITABLE.match(text)
    if habitable:
        numeral = habitable["numeral"]
        kind = MOON if LETTERED.search(numeral) or "moon" in numeral else PLANET
        note = numeral if not habitable["note"] else f"{numeral}: {habitable['note']}"
        return {"name": habitable["name"], "kind": kind, "habitable": True, "note": note}
    match = PLACE.match(text)
    if not match:
        raise ValueError(f"place not understood: system={system}, place={text}")
    name = match["name"]
    if NUMERAL.match(name):
        name = f"{system} {name}"
    note = match["inside"] if not match["note"] else f"{match['inside']}: {match['note']}"
    return {"name": name, "kind": place_kind(name, match["inside"]), "habitable": False, "note": note}


def read_systems() -> list[dict]:
    """Every system of galaxy.md's section 8, with its position and owner from galaxy.json."""
    text = GALAXY_DOC.read_text(encoding="utf-8")
    section = text.split("## 8. Star systems", 1)[1].split("\n## ", 1)[0]
    positions = {s["id"]: s for s in json.loads(GALAXY_DATA.read_text(encoding="utf-8"))["systems"]}
    systems = []
    for line in section.splitlines():
        row = ROW.match(line.strip())
        if not row:
            continue
        system_id, name, star = row["id"], row["name"].strip(), row["star"].strip()
        data = positions.get(system_id)
        if data is None or data["name"] != name:
            raise ValueError(f"system not in galaxy.json under that name: id={system_id}, name={name}")
        places_text = row["places"].strip().removeprefix("No habitable world: ")
        places = [parse_place(place.strip(), name) for place in places_text.split(" · ")]
        if not MIN_PLACES <= len(places) <= MAX_PLACES:
            raise ValueError(f"system needs {MIN_PLACES} to {MAX_PLACES} places: id={system_id}, places={len(places)}")
        if places[0]["kind"] == MOON:
            raise ValueError(f"system starts with a moon: id={system_id}, place={places[0]['name']}")
        systems.append({"id": system_id, "name": name, "star": STARS[star], "owner": OWNERS[data["faction"]],
                        "x": data["x"], "y": data["y"], "places": places})
    if len(systems) != len(positions):
        missing = sorted(set(positions) - {s["id"] for s in systems})
        raise ValueError(f"galaxy.md and galaxy.json list different systems: missing_in_doc={missing}")
    return systems


def folder_name(name: str) -> str:
    """A system's content folder (and ID) from its name: Depot 1 is depot_1, KR-114 is kr_114."""
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def quoted(text: str) -> str:
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def definition_text(system: dict) -> str:
    """The system's definition as a Godot text resource, with its places as sub-resources."""
    lines = ['[gd_resource type="Resource" script_class="StarSystemDefinition" format=3]', "",
             f'[ext_resource type="Script" path="{DEFINITION_SCRIPT}" id="1_definition"]',
             f'[ext_resource type="Script" path="{PLACE_SCRIPT}" id="2_place"]', ""]
    ids = []
    for index, place in enumerate(system["places"], start=1):
        ids.append(f"Resource_place{index}")
        lines += [f'[sub_resource type="Resource" id="{ids[-1]}"]', 'script = ExtResource("2_place")',
                  f"display_name = {quoted(place['name'])}"]
        if place["kind"] != PLANET:
            lines.append(f"kind = {place['kind']}")
        if place["habitable"]:
            lines.append("habitable = true")
        lines += [f"note = {quoted(place['note'])}", ""]
    lines += ["[resource]", 'script = ExtResource("1_definition")', f"display_name = {quoted(system['name'])}",
              f"map_id = {quoted(system['id'])}"]
    if system["star"] != 1:
        lines.append(f"star = {system['star']}")
    if system["owner"] != 3:
        lines.append(f"owner = {system['owner']}")
    lines.append(f"map_position = Vector2({system['x']}, {system['y']})")
    references = ", ".join(f'SubResource("{place_id}")' for place_id in ids)
    lines.append(f'places = Array[ExtResource("2_place")]([{references}])')
    return "\n".join(lines) + "\n"


def write_systems(systems: list[dict]) -> None:
    """Writes every system's definition, and points out folders of systems galaxy.md no longer lists."""
    written = set()
    for system in systems:
        folder = folder_name(system["name"])
        if folder in written:
            raise ValueError(f"two systems share a folder: folder={folder}, system={system['id']}")
        written.add(folder)
        path = CONTENT / folder / f"{folder}.tres"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(definition_text(system), encoding="utf-8", newline="\n")
    stale = sorted(p.name for p in CONTENT.iterdir() if p.is_dir() and p.name not in written)
    for name in stale:
        print(f"⚠️ System folder no longer in galaxy.md, delete it by hand: folder={name}")
    kinds = {kind: sum(1 for s in systems for p in s["places"] if p["kind"] == index)
             for index, kind in enumerate(KIND_NAMES)}
    print(f"🌌 Wrote the star systems: systems={len(systems)}, "
          f"places={sum(len(s['places']) for s in systems)}, kinds={kinds}, "
          f"habitable={sum(1 for s in systems for p in s['places'] if p['habitable'])}, stale={len(stale)}, "
          f"path={CONTENT.relative_to(ROOT)}")


def main() -> None:
    systems = read_systems()
    print(f"🌌 Read the star systems: systems={len(systems)}, doc={GALAXY_DOC.relative_to(ROOT)}, "
          f"data={GALAXY_DATA.relative_to(ROOT)}")
    write_systems(systems)


if __name__ == "__main__":
    main()
