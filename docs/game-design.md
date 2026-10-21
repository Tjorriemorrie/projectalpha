# Game Design Document

> The full vision of the game: what it is and why it is fun. Keep it high level.
> Detailed, buildable specs live in [features/](features/); build order lives in [roadmap.md](roadmap.md).
> Mark undecided items as **TBD**. Git history is the changelog.
> This covers the whole game, not just the MVP. Status is never tracked here: the **Feature** column links
> to a feature spec once one exists (`—` means part of the vision but not yet planned); see the roadmap for status.

## 1. Overview

| Field             | Value |
|-------------------|-------|
| Working title     | projectalpha |
| Genre             | Single-player (offline) extraction shooter |
| Perspective       | 3D first-person |
| Platforms         | Steam, mainly Windows |
| Target audience   | Casual-friendly fans of extraction and sci-fi survival games who want the tension without PvP. Reference games: Escape from Tarkov, Arc Raiders, Hunt: Showdown, FTL, Dead Space, Barotrauma |
| Session length    | One run: about 5 minutes on small early wrecks, up to 30 minutes at most on large stations |

### Elevator pitch

Draft: an offline first-person sci-fi extraction shooter. You are a salvager on the outer rim who boards
derelict and hostile space stations and ships, fights whatever is aboard, and gets out with loot to sell or
to craft and upgrade with.

Constraint: built by one indie developer, so scope stays very small.

### Design pillars

The 3 core ideas every feature should support. If a feature doesn't serve a pillar, cut it.

1. **Choose your risk.** The player always sees the stakes and decides how much to gamble.
2. **Everything is salvage.** Every item can be looted, broken down, crafted or sold, so every run feeds progress.
   Space is limited (grid inventory), so the player keeps deciding what is worth carrying out.
3. **Lose it all.** Death is permanent loss, which makes extracting tense and meaningful.

## 2. Gameplay

### Core loop

- **Run (minutes):** board a wreck, fight, loot, and extract before the run pressure gets you.
- **Between runs (on your ship):** break loot down into components, craft and upgrade gear, then fly to the next wreck.
- **Trip (a few runs):** stock up with fuel and supplies at a trader hub, do several runs, and plan the route so
  that you end up back at a hub to sell and restock. Fuel is what bends the route into a loop.

Trader hubs are menus, not places to walk around. The travel gives the feeling of having hauled your loot
there.

**Second to second:** move carefully and listen; fight from cover by peeking; sprint for the exit when it goes wrong.

### Player goals

- **Short-term:** extract from a wreck with valuable loot.
- **Mid-term:** get the gear and technology needed to reach riskier, richer locations.
- **Long-term:** the game has an ending. The target or ending is TBD and will be decided along with the story,
  near the end of development.

### Mechanics

High-level list only. Each mechanic gets a detailed spec in `features/` when it is about to be built.

| Mechanic | Description | Feature |
|----------|-------------|---------|
| Boarding and extraction | Board a station or ship, then get out alive to keep what you found | [008](features/008-extraction-and-clone-loop.md) |
| First-person combat | Cover-based shooting aboard stations and ships. Forgiving enough to get through many fights in a run: about ten hits kill the player, but health doesn't come back during a run, so every fight wears the player down | [005](features/005-weapon-and-health.md), [004](features/004-free-peek-and-cover.md) |
| Laser weapons and thermal clips | Weapons are lasers. Every shot heats the weapon, and a thermal clip (as in Mass Effect 2) soaks up the heat. Holding the trigger charges a shot that hits harder, kicks more and puts more heat into the clip; when the clip is saturated the player swaps it for a fresh one, which is the reload. The spent clip goes back into the inventory as salvage (to re-cool, break down or sell later) instead of being dropped. Thermal clips fit every weapon, take space in the grid inventory and are lost on death like everything else | [005](features/005-weapon-and-health.md) |
| Free peek | Hold Alt and move the mouse to peek out of cover in any direction (replaces fixed left/right lean). Peeking is look-only: you can't shoot, but you are hard to hit. To shoot from cover, hold right click to aim out, which exposes more of you and makes you easier to hit | [004](features/004-free-peek-and-cover.md) |
| Vents | Crouch-only routes through ventilation shafts | [002](features/002-wreck-section-kit.md) |
| Flashlight | Lights up dark wrecks, but lights you up for enemies too; toggled on and off, no battery | [002](features/002-wreck-section-kit.md), [006](features/006-robot-enemy.md) |
| Elevators | The only way between decks: call with a button, ride, and the arrival ding can be heard | [002](features/002-wreck-section-kit.md) |
| Enemy senses | Enemies see, hear and feel the player. In the dark they only see you up close, unless you are lit by a lamp, your flashlight or your own muzzle flash. Shots, sprinting and the elevator's ding carry far; walking is quieter and crouching quietest. Moving fast, shooting and lighting the way are risks you choose | [006](features/006-robot-enemy.md) |
| Looting | Pry open containers and robot wreckage, in real time while the wreck is still dangerous, and carry the items out | [007](features/007-loot-and-grid-inventory.md) |
| Grid inventory | Items take up tetris-like shapes in a backpack grid and a strip of pockets for things at hand (reloads take thermal clips from the pockets); the player rotates, mirrors and arranges them to fit more loot, and drops what isn't worth the space. Every item is moved by dragging it, with no quick-move shortcuts, can be selected, and shows an item card (value, size, description) under the pointer; dropped items lie on the floor, which the inventory shows as a grid of its own | [007](features/007-loot-and-grid-inventory.md) |
| Trader hubs | Menu-based stations for selling loot and buying anything in the game | — |
| Breakdown | Break any item down into components (like Arc Raiders) | — |
| Crafting and upgrades | Craft any item from components; upgrade gear | — |
| Ship as hub | Your ship is your home between runs (no base building for now) | [008](features/008-extraction-and-clone-loop.md) (minimal) |
| Travel and fuel | Fly between wrecks and hubs; fuel limits how many runs you can do before restocking | — |
| Star map | A free map: jump anywhere within fuel range. Includes job-board leads. Hover or inspect a location to see its difficulty, wreck type and required gear | — |
| Location requirements | Some locations need specific gear or technology to enter (e.g. an oxygen supply for breached wrecks) | — |
| Wreck timer | A countdown until the wreck is destroyed | — |
| Oxygen | Limited air supply aboard breached wrecks | — |
| Escalation | Rival salvagers keep arriving the longer you stay | — |

### Enemies

| Enemy type | Description | Feature |
|------------|-------------|---------|
| Robots | Automated defenses (e.g. turrets, security drones) and maintenance machines aboard stations and ships | [006](features/006-robot-enemy.md) |
| Humans | Rival salvagers, pirates and crews; also the arrivals that escalate contested wrecks | — |
| Aliens | TBD | — |
| Monsters | TBD | — |
| Infected | Humans or aliens taken over by a virus or fungus | — |

### Controls

Gamepad is supported. There is no jump, prone or slide.

| Action | Keyboard / Mouse | Gamepad |
|--------|------------------|---------|
| Move | WASD | Left stick |
| Look / aim | Mouse | Right stick |
| Shoot: tap to fire, hold to charge a stronger shot | Left click | Right trigger |
| Aim down sights | Right click (hold) | Left trigger (hold) |
| Reload | R | X / Square |
| Interact / loot: hold to pry a container open; on a dropped item, opens the floor in the inventory; opens the ship's stash; hold on an airlock's outer door to board the wreck or return to the ship; continues past the run summary | E | A / Cross |
| Sprint (e.g. to run for extraction) | Shift (hold) | Left stick click (lasts until you stop pushing forward) |
| Crouch (e.g. to move through vents) | Ctrl (hold) / C (toggle) | B / Circle (tap to toggle, hold to crouch until released) |
| Peek: hold, then move the mouse or right stick to move the head out of cover in that direction (look only) | Alt (hold) | Left bumper (hold) |
| Aim out of cover: hold together with peek, in either order, to lean further out and shoot | Right click (hold) | Left trigger (hold) |
| Flashlight | F (toggle) | D-pad up (toggle) |
| Inventory: open and close (Esc and interact also close it) | Tab | View / Select (B also closes it) |
| In the inventory: move the cursor | Mouse | Left stick / D-pad |
| In the inventory: drag an item | Left click (hold) | A (hold) |
| In the inventory: rotate the dragged item 90° | Right click | Right bumper |
| In the inventory: mirror the dragged item | Middle click or mouse wheel | Left bumper |
| In the inventory: drop an item on the floor | Drag it onto the floor grid, or release it outside the inventory | Y / Triangle |
| Pause | Esc | Menu / Start |

Gamepad bindings are a first draft.

### Win / lose conditions

- **Win a run:** extract alive and keep everything you carried out.
- **Lose a run:** die aboard, and lose everything you brought in and everything you found.
- **After death:** you wake up as a new clone on your ship. In the fiction, the previous clone's lifeline died
  and the next one is activated. This also explains the permanent loss: the gear died with that clone.
  Waking a new clone takes time, so the wreck is gone by then (destroyed, drifted away or picked clean by others):
  the run ends at death, and there is no going back for the body.

### Run pressure

What pushes the player to extract depends on the kind of wreck. Each kind is a separate source of pressure, and
the kinds can be introduced gradually as the game goes on.

| Wreck type | Pressure | Fiction |
|------------|----------|---------|
| Quiet wreck | None, only the enemies aboard | Early-game ships where the player learns the ropes |
| Doomed wreck | Timer | The ship is falling into a planet or star |
| Breached wreck | Personal resource (oxygen) | The hull is damaged and has no breathable air |
| Contested wreck | Escalation: more and more enemies arrive over time | A stranded ship that every salvager in the sector wants to loot |

### Progression and difficulty

- **The player chooses the risk.** Every location on the star map shows its difficulty and requirements up front,
  so the player decides how much to gamble. No location is forced on them.
- Gear and technology gate harder locations. Progression mostly means unlocking access to riskier, richer wrecks.
- Early game uses quiet wrecks only. Timers, oxygen and escalation are introduced later as the pressure ramps up
  (see [Run pressure](#run-pressure)).
- The rest is TBD.

## 3. World and story

### Setting

Sci-fi, the outer rim of space. The player is a salvager working derelict and occupied stations and ships.
The salvager is a clone: when one dies, the next wakes up aboard the home ship.

### Story summary

Deliberately deferred: the story will be written near the end of development.

### Characters

Deferred with the story. The only fixed character is the player: a cloned salvager.

| Name | Role | Description |
|------|------|-------------|
| The salvager | Player | A clone; the next one wakes up on the ship when the current one dies |

## 4. Levels / content

Locations are not hand-built levels. They are assembled from a kit of predefined **sections** (corridors, rooms,
airlocks, vents, elevators). Every deck is flat: decks connect only by elevators, with no stairs, ramps or ladders. Each ship and station class has a **blueprint** that describes how its sections fit together,
and missions populate the result with enemies and loot to suit the difficulty (see [Modding](#modding)). Size scales with difficulty: small ships take about 5 minutes,
and the largest stations take up to 30.

| Level / area | Purpose | Key mechanics introduced | Feature |
|--------------|---------|--------------------------|---------|
| Blueprint-based generation | Builds each wreck's layout from its class blueprint | — | — |
| Small ships | Early game, about 5-minute runs | Core loop | [002](features/002-wreck-section-kit.md) |
| Large stations | Late game, runs of up to 30 minutes | TBD | — |

### Modding

The game is meant to be easily moddable, and all content is plug and play:

- **Items and weapons** are self-contained definitions: model, graphics, scripts and sounds, plus what the item
  breaks down into and how it is crafted. Adding one means adding the definition, with no code changes elsewhere.
- **Ships and stations** are built from a kit of predefined sections (corridors, rooms, airlocks, vents).
  A blueprint describes how a ship class assembles those sections. Adding a ship means adding a blueprint
  (and new sections if needed); missions then populate it with enemies and loot to suit the difficulty.
- The base game's own content uses the same system, so it is effectively the first mod.

Technical approach: see [technical-design.md](technical-design.md#content-and-modding).

## 5. Art direction

- Visual style: low-poly, leaning towards semi-realistic (believable proportions and materials, modest polygon counts)
- Mood: dark horror corridors (like Dead Space): flickering lights, tight spaces, dread. It serves the suspense.
  Other moods, such as gritty industrial or clean sci-fi, may vary by wreck type later.
- Color palette: cold and clinical. Blue-grey metal, harsh white lights, and red emergency lighting for danger
  and alarms.
- References / mood board: Dead Space and Alien: Isolation (to be extended).

## 6. Audio

Sound is crucial to the tension. The player must be able to hear threats before seeing them.

- **Music:** none while exploring a wreck, so the silence builds suspense; music kicks in during combat.
  On the ship and the star map there is no music either, only the ship's hum, for a lonely, isolated feel.
- **Sound effects:**
  - Player: breathing and footsteps.
  - Enemies: footsteps and voice lines, so the player can locate and identify them.
  - Looting: searching containers and picking up and moving items.
  - Combat: weapons, impacts and hits.

## 7. User interface

- **Menus:** main menu, pause, settings, inventory (grid), crafting and breakdown, star map, trader hub.
- **HUD:** classic, with corner indicators for health, thermal clip heat, oxygen (on breached wrecks) and the wreck timer
  (on doomed wrecks).

## 8. Scope

The MVP, milestones and build order are tracked in [roadmap.md](roadmap.md).

## 9. Open questions

- What is the ending or final target? Decide it together with the story, near the end of development.
