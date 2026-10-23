"""Lays out and draws the galaxy map of docs/galaxy.md: its 50 star systems, where they lie in light years, and the
jumps between them.

A jump reaches at most JUMP_RANGE light years (the ship's antimatter tank holds one jump), so the distances decide
where the player can go. A good layout:
- puts every system within range of MIN_JUMPS to MAX_JUMPS others, about 5 on average;
- keeps the three companies' territories apart, each one connected within itself, with gaps wider than a jump between
  them that only contested and free systems bridge;
- never leaves two systems just out of range (less than CLEAR_MARGIN beyond JUMP_RANGE), so a gap is clearly a gap;
- leaves every system on the outer ring (where the player starts) enough systems on the far half of the map, at least
  HER_MIN_JUMPS jumps away, for her location;
- keeps systems apart and jump lines clear of other systems, so the map reads well.

Run from the repository root:
    python art-source/galaxy/galaxy_map.py           checks galaxy.json against those rules and draws docs/galaxy-map.svg
    python art-source/galaxy/galaxy_map.py generate  first searches for a new layout and overwrites galaxy.json
Coordinates are light years from the middle of the map, x towards the east and y towards the north (the core worlds).
The systems are named and their history is pinned to where they lie, so move them by hand in galaxy.json and run the
check; generate refuses to replace a named layout unless given --force, since it renumbers every system.
"""

import argparse
import json
import math
import random
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "galaxy.json"
OUTPUT = HERE.parents[1] / "docs" / "galaxy-map.svg"

JUMP_RANGE = 10.0
CLEAR_MARGIN = 1.0
MIN_JUMPS = 4
MAX_JUMPS = 6
MIN_SEPARATION = 4.0
LINE_CLEARANCE = 1.5
OUTER_RING = 28.0
HER_MIN_JUMPS = 6

# Name, colour and ID prefix of each faction. Only the three companies keep their distance from each other.
FACTIONS = {
    "her": ("Halden-Mori", "#e0584c", "H"),
    "cheap": ("Massey", "#e8a93c", "C"),
    "elite": ("Corvid", "#49bcd6", "E"),
    "free": ("Free systems", "#7cc96c", "F"),
    "contested": ("Contested", "#b7a3ea", "X"),
}
COMPANIES = ("her", "cheap", "elite")

# Where the search places each faction's systems and keeps them: sectors around the middle of the map, as (first
# angle, last angle, inner radius, outer radius), angles in degrees counter-clockwise from east. Her company fills the
# middle, the cheap rival curves around the west, the elite rival holds the east, and free pockets the north and south.
# Contested systems name the two companies they lie between.
ZONES = [
    {"faction": "her", "sector": (0, 360, 0, 19), "count": 17},
    {"faction": "cheap", "sector": (130, 230, 26, 38), "count": 13},
    {"faction": "elite", "sector": (-25, 25, 26, 36), "count": 6},
    {"faction": "free", "sector": (65, 115, 23, 36), "count": 4},
    {"faction": "free", "sector": (245, 295, 23, 36), "count": 4},
    {"faction": "contested", "sector": (145, 215, 19, 25), "count": 4, "between": ["her", "cheap"]},
    {"faction": "contested", "sector": (-20, 20, 19, 25), "count": 2, "between": ["her", "elite"]},
]

# The search keeps this much further from every threshold than the check, so rounding the saved coordinates to a
# tenth of a light year can't break a rule.
BUFFER = 0.2
ITERATIONS = 60000


def is_company_border(faction_a: str, faction_b: str) -> bool:
    """Two systems of different companies, which must lie more than a jump apart."""
    return faction_a != faction_b and faction_a in COMPANIES and faction_b in COMPANIES


def segment_distance(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    """Distance from a point to the line segment between a and b."""
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def segments_cross(a: tuple, b: tuple, c: tuple, d: tuple) -> bool:
    """Whether the segments a-b and c-d cross (they share no end point)."""
    def side(p: tuple, q: tuple, r: tuple) -> float:
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    return side(a, b, c) * side(a, b, d) < 0 and side(c, d, a) * side(c, d, b) < 0


def count_components(members: list[int], links: list[set]) -> int:
    """How many separate groups the given systems form, moving only through each other."""
    inside = set(members)
    seen = set()
    groups = 0
    for start in members:
        if start in seen:
            continue
        groups += 1
        seen.add(start)
        queue = deque([start])
        while queue:
            for other in links[queue.popleft()] & inside:
                if other not in seen:
                    seen.add(other)
                    queue.append(other)
    return groups


def hops_from(start: int, links: list[set]) -> list[int]:
    """The fewest jumps from one system to every other (-1 where there is no way)."""
    hops = [-1] * len(links)
    hops[start] = 0
    queue = deque([start])
    while queue:
        here = queue.popleft()
        for other in links[here]:
            if hops[other] < 0:
                hops[other] = hops[here] + 1
                queue.append(other)
    return hops


class Search:
    """Simulated annealing over the systems' positions: moves one system at a time and keeps moves that break fewer
    rules, accepting worse ones less and less often as it cools."""

    def __init__(self, seed: int):
        self.rng = random.Random(seed)
        self.faction, self.between, self.sector, self.x, self.y = [], [], [], [], []
        for zone in ZONES:
            for _ in range(zone["count"]):
                a0, a1, r0, r1 = zone["sector"]
                angle = math.radians(self.rng.uniform(a0, a1))
                radius = math.sqrt(self.rng.uniform(r0 * r0, r1 * r1))
                self.faction.append(zone["faction"])
                self.between.append(zone.get("between"))
                self.sector.append(zone["sector"])
                self.x.append(radius * math.cos(angle))
                self.y.append(radius * math.sin(angle))
        self.n = len(self.x)
        self.links = [set() for _ in range(self.n)]
        for i in range(self.n):
            self.relink(i)

    def relink(self, k: int) -> None:
        for j in range(self.n):
            if j == k:
                continue
            if math.hypot(self.x[k] - self.x[j], self.y[k] - self.y[j]) <= JUMP_RANGE:
                self.links[k].add(j)
                self.links[j].add(k)
            else:
                self.links[k].discard(j)
                self.links[j].discard(k)

    def zone_cost(self, k: int) -> float:
        a0, a1, r0, r1 = self.sector[k]
        radius = math.hypot(self.x[k], self.y[k])
        out_radial = max(0.0, r0 - radius, radius - r1)
        out_arc = 0.0
        if a1 - a0 < 360:
            past = (math.degrees(math.atan2(self.y[k], self.x[k])) - a0) % 360
            if past > a1 - a0:
                out_arc = math.radians(min(past - (a1 - a0), 360 - past)) * radius
        return 5.0 * (out_radial ** 2 + out_arc ** 2)

    def pair_cost(self, i: int, j: int) -> float:
        d = math.hypot(self.x[i] - self.x[j], self.y[i] - self.y[j])
        cost = 0.0
        if d < MIN_SEPARATION + BUFFER:
            cost += 30.0 * (MIN_SEPARATION + BUFFER - d + 1.0)
        if JUMP_RANGE - BUFFER < d < JUMP_RANGE + CLEAR_MARGIN + BUFFER:
            cost += 30.0
        if is_company_border(self.faction[i], self.faction[j]) and d < JUMP_RANGE + CLEAR_MARGIN + BUFFER:
            cost += 100.0
        return cost

    def edges(self) -> list[tuple[int, int]]:
        return [(i, j) for i in range(self.n) for j in self.links[i] if i < j]

    def near(self, k: int, a: int, b: int) -> bool:
        return segment_distance(self.x[k], self.y[k], self.x[a], self.y[a], self.x[b], self.y[b]) \
            < LINE_CLEARANCE + BUFFER

    def crosses(self, a: int, b: int, c: int, d: int) -> bool:
        return segments_cross((self.x[a], self.y[a]), (self.x[b], self.y[b]),
                              (self.x[c], self.y[c]), (self.x[d], self.y[d]))

    def local_cost(self, k: int) -> float:
        """Every term that moving system k can change, except the graph-wide ones in global_cost."""
        cost = self.zone_cost(k) + sum(self.pair_cost(k, j) for j in range(self.n) if j != k)
        edges = self.edges()
        for a, b in edges:
            if k != a and k != b and self.near(k, a, b):
                cost += 20.0
        for a, b in edges:
            if k != a and k != b:
                continue
            for j in range(self.n):
                if j != a and j != b and self.near(j, a, b):
                    cost += 20.0
            for c, d in edges:
                if c != a and c != b and d != a and d != b and self.crosses(a, b, c, d):
                    cost += 2.0
        return cost

    def global_cost(self) -> float:
        cost = 0.0
        for i in range(self.n):
            jumps = len(self.links[i])
            cost += 60.0 * max(0, MIN_JUMPS - jumps, jumps - MAX_JUMPS) + 12.0 * (jumps - 5) ** 2
        cost += 300.0 * (count_components(list(range(self.n)), self.links) - 1)
        for company in COMPANIES:
            members = [i for i in range(self.n) if self.faction[i] == company]
            cost += 300.0 * (count_components(members, self.links) - 1)
        for i in range(self.n):
            for company in self.between[i] or ():
                if not any(self.faction[j] == company for j in self.links[i]):
                    cost += 150.0
        return cost

    def run(self) -> None:
        hot, cold = 30.0, 0.05
        wide, narrow = 5.0, 0.2
        for step in range(ITERATIONS):
            t = step / ITERATIONS
            temperature = hot * (cold / hot) ** t
            spread = wide * (narrow / wide) ** t
            k = self.rng.randrange(self.n)
            before = self.local_cost(k) + self.global_cost()
            old = (self.x[k], self.y[k])
            self.x[k] += self.rng.gauss(0.0, spread)
            self.y[k] += self.rng.gauss(0.0, spread)
            self.relink(k)
            after = self.local_cost(k) + self.global_cost()
            if after > before and self.rng.random() >= math.exp((before - after) / temperature):
                self.x[k], self.y[k] = old
                self.relink(k)
            if step % 10000 == 0:
                print(f"🌌 Searching: step={step}, total={ITERATIONS}, temperature={temperature:.2f}")

    def systems(self) -> list[dict]:
        """The layout as saved: IDs numbered within each faction clockwise from north."""
        order = sorted(range(self.n), key=lambda i: (list(FACTIONS).index(self.faction[i]),
                                                    (90 - math.degrees(math.atan2(self.y[i], self.x[i]))) % 360))
        systems = []
        counts = {faction: 0 for faction in FACTIONS}
        for i in order:
            counts[self.faction[i]] += 1
            system = {"id": f"{FACTIONS[self.faction[i]][2]}{counts[self.faction[i]]}", "faction": self.faction[i],
                      "x": round(self.x[i], 1), "y": round(self.y[i], 1)}
            if self.between[i]:
                system["between"] = self.between[i]
            systems.append(system)
        return systems


def generate(seeds: int) -> None:
    """Runs the search from several seeds and saves the layout that breaks the fewest rules."""
    best = None
    for seed in range(seeds):
        search = Search(seed)
        search.run()
        systems = search.systems()
        failures, stats = check(systems)
        print(f"🌌 Searched layout: seed={seed}, failures={len(failures)}, crossings={stats['crossings']}")
        score = (len(failures), stats["crossings"])
        if best is None or score < best[0]:
            best = (score, seed, systems)
    DATA.write_text(json.dumps({"systems": best[2]}, indent=2) + "\n", encoding="utf-8")
    print(f"🌌 Saved layout: path={DATA.relative_to(HERE.parents[1])}, seed={best[1]}, failures={best[0][0]}, "
          f"crossings={best[0][1]}")


def linked(systems: list[dict]) -> list[set]:
    return [{j for j, other in enumerate(systems) if j != i and distance(system, other) <= JUMP_RANGE}
            for i, system in enumerate(systems)]


def distance(a: dict, b: dict) -> float:
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def check(systems: list[dict]) -> tuple[list[str], dict]:
    """Checks a layout against the rules; returns what it breaks and a few numbers about it."""
    links = linked(systems)
    n = len(systems)
    edges = [(i, j) for i in range(n) for j in links[i] if i < j]
    failures = []
    for i, system in enumerate(systems):
        if not MIN_JUMPS <= len(links[i]) <= MAX_JUMPS:
            failures.append(f"{system['id']} has {len(links[i])} systems in range")
        for company in system.get("between", ()):
            if not any(systems[j]["faction"] == company for j in links[i]):
                failures.append(f"{system['id']} is contested but out of reach of {company}")
    for i in range(n):
        for j in range(i + 1, n):
            d = distance(systems[i], systems[j])
            pair = f"{systems[i]['id']}-{systems[j]['id']}"
            if d < MIN_SEPARATION:
                failures.append(f"{pair} lie only {d:.1f} ly apart")
            if JUMP_RANGE < d < JUMP_RANGE + CLEAR_MARGIN:
                failures.append(f"{pair} lie just out of range, {d:.1f} ly apart")
            if is_company_border(systems[i]["faction"], systems[j]["faction"]) and d <= JUMP_RANGE:
                failures.append(f"{pair} are rival companies in jump range of each other")
    if count_components(list(range(n)), links) > 1:
        failures.append("the map falls apart into separate groups")
    for company in COMPANIES:
        members = [i for i in range(n) if systems[i]["faction"] == company]
        if count_components(members, links) > 1:
            failures.append(f"{company}'s territory is split")
    for k, system in enumerate(systems):
        for a, b in edges:
            if k != a and k != b and segment_distance(system["x"], system["y"], systems[a]["x"], systems[a]["y"],
                                                       systems[b]["x"], systems[b]["y"]) < LINE_CLEARANCE:
                failures.append(f"the jump {systems[a]['id']}-{systems[b]['id']} passes over {system['id']}")
    points = [(s["x"], s["y"]) for s in systems]
    crossings = sum(1 for e, (a, b) in enumerate(edges) for c, d in edges[e + 1:]
                    if len({a, b, c, d}) == 4 and segments_cross(points[a], points[b], points[c], points[d]))

    ring = [i for i in range(n) if math.hypot(*points[i]) >= OUTER_RING]
    choices, far_hops = [], []
    for start in ring:
        hops = hops_from(start, links)
        far = [i for i in range(n) if points[i][0] * points[start][0] + points[i][1] * points[start][1] < 0]
        eligible = [i for i in far if hops[i] >= HER_MIN_JUMPS]
        if not eligible:
            failures.append(f"starting at {systems[start]['id']}, no system on the far half is "
                            f"{HER_MIN_JUMPS}+ jumps away")
        choices.append(len(eligible))
        far_hops += [hops[i] for i in eligible]
    stats = {
        "links": links,
        "edges": edges,
        "crossings": crossings,
        "ring": ring,
        "average_jumps": sum(len(l) for l in links) / n,
        "choices": choices,
        "far_hops": far_hops,
    }
    return failures, stats


def draw(systems: list[dict], stats: dict) -> None:
    """Writes the map as an SVG: territories, the outer ring, every possible jump with its distance, and a legend."""
    scale = 13.0
    half = max(max(abs(s["x"]), abs(s["y"])) for s in systems) + 7.0
    size = 2 * half * scale
    panel = 330
    background = "#0b1020"

    def px(x: float) -> float:
        return (x + half) * scale

    def py(y: float) -> float:
        return (half - y) * scale

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size + panel:.0f}" height="{size:.0f}" '
           f'viewBox="0 0 {size + panel:.0f} {size:.0f}" font-family="Segoe UI, Arial, sans-serif">',
           f'<rect width="100%" height="100%" fill="{background}"/>']
    for s in systems:
        out.append(f'<circle cx="{px(s["x"]):.1f}" cy="{py(s["y"]):.1f}" r="{6.5 * scale:.1f}" '
                   f'fill="{FACTIONS[s["faction"]][1]}" fill-opacity="0.09"/>')
    out.append(f'<circle cx="{px(0):.1f}" cy="{py(0):.1f}" r="{OUTER_RING * scale:.1f}" fill="none" '
               f'stroke="#ffffff" stroke-opacity="0.35" stroke-width="1.5" stroke-dasharray="6 6"/>')
    for a, b in stats["edges"]:
        sa, sb = systems[a], systems[b]
        out.append(f'<line x1="{px(sa["x"]):.1f}" y1="{py(sa["y"]):.1f}" x2="{px(sb["x"]):.1f}" '
                   f'y2="{py(sb["y"]):.1f}" stroke="#8f9cbb" stroke-opacity="0.55" stroke-width="1.3"/>')
    for a, b in stats["edges"]:
        sa, sb = systems[a], systems[b]
        out.append(f'<text x="{px((sa["x"] + sb["x"]) / 2):.1f}" y="{py((sa["y"] + sb["y"]) / 2) + 3.5:.1f}" '
                   f'fill="#c5cde0" font-size="10" text-anchor="middle" stroke="{background}" stroke-width="3" '
                   f'paint-order="stroke">{distance(sa, sb):.0f}</text>')
    ring = set(stats["ring"])
    for i, s in enumerate(systems):
        x, y = px(s["x"]), py(s["y"])
        if i in ring:
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="14" fill="none" stroke="#ffffff" '
                       f'stroke-opacity="0.7" stroke-width="1.2" stroke-dasharray="3 3"/>')
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="9" fill="{FACTIONS[s["faction"]][1]}" '
                   f'stroke="#ffffff" stroke-width="1"/>')
        out.append(f'<text x="{x:.1f}" y="{y + 3.5:.1f}" fill="#0b1020" font-size="10" font-weight="700" '
                   f'text-anchor="middle">{len(stats["links"][i])}</text>')
        out.append(f'<text x="{x + 12:.1f}" y="{y - 9:.1f}" fill="#ffffff" font-size="12" font-weight="600" '
                   f'stroke="{background}" stroke-width="3" paint-order="stroke">{s.get("name", s["id"])}'
                   f'<tspan fill="#8f9cbb" font-size="9" font-weight="400"> {s["id"]}</tspan></text>')

    left = size + 20
    out.append(f'<rect x="{size:.0f}" y="0" width="{panel}" height="{size:.0f}" fill="#111833"/>')
    out.append(f'<text x="{left:.0f}" y="40" fill="#ffffff" font-size="20" font-weight="700">The Honeycomb</text>')
    out.append(f'<text x="{left:.0f}" y="62" fill="#9aa6c4" font-size="12">Galaxy map: every system, with its '
               f'ID in docs/galaxy.md</text>')
    y = 105
    for faction, (name, colour, prefix) in FACTIONS.items():
        count = sum(1 for s in systems if s["faction"] == faction)
        out.append(f'<circle cx="{left + 9:.0f}" cy="{y - 4}" r="9" fill="{colour}" stroke="#ffffff"/>')
        out.append(f'<text x="{left + 28:.0f}" y="{y}" fill="#ffffff" font-size="14">{name} ({prefix}): '
                   f'{count}</text>')
        y += 30
    lines = [
        "Lines: every possible jump, labelled",
        "with its distance in light years.",
        f"A jump reaches at most {JUMP_RANGE:.0f} ly, and no",
        f"two systems lie {JUMP_RANGE:.0f} to {JUMP_RANGE + CLEAR_MARGIN:.0f} ly apart.",
        "",
        "Number in a system: how many",
        f"systems are in jump range ({MIN_JUMPS} to {MAX_JUMPS}).",
        "",
        f"Dashed circle: the outer ring, {OUTER_RING:.0f} ly",
        "from the middle. A dashed ring around a",
        "system: outside it, so the game can start there.",
        f"She is then on the far half of the map,",
        f"at least {HER_MIN_JUMPS} jumps away.",
        "",
        "North: towards the core worlds.",
        "South: uncharted deep space.",
    ]
    y += 10
    for line in lines:
        out.append(f'<text x="{left:.0f}" y="{y}" fill="#c5cde0" font-size="13">{line}</text>')
        y += 19
    y += 15
    out.append(f'<line x1="{left:.0f}" y1="{y}" x2="{left + JUMP_RANGE * scale:.0f}" y2="{y}" stroke="#ffffff" '
               f'stroke-width="3"/>')
    out.append(f'<text x="{left + JUMP_RANGE * scale + 10:.0f}" y="{y + 5}" fill="#ffffff" font-size="13">'
               f'{JUMP_RANGE:.0f} ly: one jump</text>')
    y += 40
    numbers = [
        f"Average systems in range: {stats['average_jumps']:.1f}",
        f"Start systems on the ring: {len(stats['ring'])}",
        f"Her systems per start: {min(stats['choices'])} to {max(stats['choices'])}",
        f"Jumps from start to her: {min(stats['far_hops'])} to {max(stats['far_hops'])}",
    ]
    for line in numbers:
        out.append(f'<text x="{left:.0f}" y="{y}" fill="#c5cde0" font-size="13">{line}</text>')
        y += 19
    out.append("</svg>")
    OUTPUT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"🌌 Drew the galaxy map: path={OUTPUT.relative_to(HERE.parents[1])}, systems={len(systems)}, "
          f"jumps={len(stats['edges'])}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Lay out, check and draw the galaxy map.")
    parser.add_argument("mode", nargs="?", choices=["check", "generate"], default="check")
    parser.add_argument("--seeds", type=int, default=4, help="searches to run when generating; the best is kept")
    parser.add_argument("--force", action="store_true", help="let generate replace a layout whose systems are named")
    args = parser.parse_args()
    if args.mode == "generate":
        named = DATA.exists() and any("name" in s for s in json.loads(DATA.read_text(encoding="utf-8"))["systems"])
        if named and not args.force:
            print(f"❌ Refused to generate: the systems in {DATA.name} are named, and a new layout renumbers them; "
                  f"move systems by hand, or pass --force to start over")
            return
        generate(args.seeds)
    systems = json.loads(DATA.read_text(encoding="utf-8"))["systems"]
    failures, stats = check(systems)
    for failure in failures:
        print(f"❌ Layout breaks a rule: {failure}")
    histogram = {k: sum(1 for l in stats["links"] if len(l) == k) for k in range(MIN_JUMPS - 1, MAX_JUMPS + 2)}
    print(f"🌌 Checked layout: systems={len(systems)}, jumps={len(stats['edges'])}, "
          f"average_in_range={stats['average_jumps']:.2f}, in_range_histogram={histogram}, "
          f"crossings={stats['crossings']}, failures={len(failures)}")
    print(f"🌌 Starts and her location: ring_systems={len(stats['ring'])}, "
          f"choices_per_start={min(stats['choices'])}..{max(stats['choices'])}, "
          f"jumps_to_her={min(stats['far_hops'])}..{max(stats['far_hops'])}, "
          f"average_jumps_to_her={sum(stats['far_hops']) / len(stats['far_hops']):.1f}")
    draw(systems, stats)


if __name__ == "__main__":
    main()
