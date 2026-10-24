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

Draft: an offline first-person sci-fi extraction shooter. You are a salvager on the outer rim who mind-controls
expendable androids to board derelict and hostile space stations and ships, fight whatever is aboard, and get out
with loot to sell or to craft and upgrade with. All the while you are racing the clock to save your wife:
infected with a virus she stole from its creator, she is stranded deep in space and running out of time. Her one-way
messages raise the stakes as you go, and you need to find the cure and reach her in time.

Constraint: built by one indie developer, so scope stays very small.

### Design pillars

The 3 core ideas every feature should support. If a feature doesn't serve a pillar, cut it.

1. **Choose your risk, against the clock.** The player always sees the stakes of every ship and station and decides
   how much to gamble. Playing it safe is a risk too: every day spent is one she may not have, so taking too long can
   mean reaching her too late.
2. **Everything is salvage.** Every item can be looted, broken down, crafted or sold, so every run feeds progress.
   Space is limited (a few slots), so the player keeps deciding what is worth carrying out.
3. **Lose it all.** Death is permanent loss, which makes extracting tense and meaningful.

## 2. Gameplay

### Core loop

- **Run (minutes, one day):** board a ship or station, fight, loot, and extract before the run pressure gets you.
  A run takes a day whether the android extracts or dies.
- **Between runs (on your ship):** break loot down into components, craft and upgrade gear, decrypt drives, then fly
  to the next wreck on hydrogen.
- **Star system (a few runs):** every system has a trader hub to sell and restock at, and ships and stations to
  board. The player boards them to pay for the antimatter to move on and to fill the days it takes to arrive: a
  couple of runs in the first systems, more later as the wait grows. He picks which ones are worth the risk and flies
  a loop through them, then jumps to a neighbouring system (one day). See [Travel and fuel](#travel-and-fuel).
- **Journey (the whole game):** triangulate where she is from her ship's ping, collect the parts of the cure and
  reach her before her time runs out (see [Rescue clock](#rescue-clock), [Finding her](#finding-her) and
  [The cure](#the-cure)).

Trader hubs are menus, not places to walk around: the player trades from a console on his ship (see
[Setting](#setting)).

**Second to second:** move carefully and listen; fight from cover by peeking; sprint for the exit when it goes wrong.

### Player goals

- **Short-term:** extract from a wreck with valuable loot.
- **Mid-term:** earn the fuel to move on to the next system, and get the gear and technology needed to reach
  riskier, richer locations.
- **Long-term:** save your wife before her time runs out: collect the key ingredients of the cure for
  her virus and the instructions for making it, and reach her in time. She holds the final part herself, so the game
  has an ending. See [Story summary](#story-summary) and [The cure](#the-cure).

### Mechanics

High-level list only. Each mechanic gets a detailed spec in `features/` when it is about to be built.

| Mechanic | Description | Feature |
|----------|-------------|---------|
| Boarding and extraction | Board a station or ship, then get out alive to keep what you found. Boarding is always done in secret: if anyone aboard knew, they would be waiting at the airlock, so the suspense is in moving through the ship unnoticed | [008](features/008-extraction-and-clone-loop.md) |
| First-person combat | Cover-based shooting aboard stations and ships. Forgiving enough to get through many fights in a run: about ten hits kill the player, but health doesn't come back during a run, so every fight wears the player down | [005](features/005-weapon-and-health.md), [004](features/004-free-peek-and-cover.md) |
| Laser weapons and thermal clips | Weapons are lasers. Every shot heats the weapon, and a thermal clip (as in Mass Effect 2) soaks up the heat. Holding the trigger charges a shot that hits harder, kicks more and puts more heat into the clip; when the clip is saturated the player swaps it for a fresh one, which is the reload. The spent clip goes back into the inventory as salvage (to re-cool, break down or sell later) instead of being dropped. Thermal clips fit every weapon, take space in the inventory and are lost on death like everything else. Guns are items too: the one in the weapon slot is in hand, the rest are carried or stashed, all are lost on death, and the hubs sell them | [005](features/005-weapon-and-health.md), [009](features/009-trader-hub.md) |
| Peek | Hold Alt and move the mouse to peek out of cover: standing, the head leans left or right round a corner; crouched, it rises up over low cover (replaces fixed left/right lean). Peeking is look-only: you can't shoot, but you are hard to hit. To shoot from cover, hold right click to aim out, which exposes more of you and makes you easier to hit | [004](features/004-free-peek-and-cover.md) |
| Vents | Crouch-only routes through ventilation shafts | [002](features/002-wreck-section-kit.md) |
| Flashlight | Lights up dark wrecks, but lights you up for enemies too; toggled on and off, no battery | [002](features/002-wreck-section-kit.md), [006](features/006-robot-enemy.md) |
| Elevators | The only way between decks: call with a button, ride, and the arrival ding can be heard | [002](features/002-wreck-section-kit.md) |
| Enemy senses | Enemies see, hear and feel the player. In the dark they only see you up close, unless you are lit by a lamp, your flashlight or your own muzzle flash. Shots, sprinting and the elevator's ding carry far; walking is quieter and crouching quietest. Moving fast, shooting and lighting the way are risks you choose | [006](features/006-robot-enemy.md) |
| Looting | Pry open containers and robot wreckage, in real time while the wreck is still dangerous, and carry the items out | [007](features/007-loot-and-grid-inventory.md), [010](features/010-wreck-variety.md) |
| Inventory | Every item takes one square slot, and a slot holds a stack of one kind of item: a weapon slot for the gun in hand, ammo slots for thermal clips (reloads take from them), pockets for things at hand and a backpack; the player drops what isn't worth a slot. Items are dragged, a shortcut moves a stack to the other side and another splits it, and at the hub a click sells one and a hold the stack; every item can be selected and shows an item card (value, description) under the pointer; dropped items lie on the floor, which the inventory shows as slots of its own. After an extraction the haul can be unloaded into the stash in one go | [007](features/007-loot-and-grid-inventory.md), [009](features/009-trader-hub.md), [013](features/013-inventory-management-revamp.md) |
| Trader hubs | Menu-based stations, one in every star system, traded with from a console on the ship while it is at the hub: sell loot from the stash for bitcoin and buy anything in the game, guns and fuel included. Prices vary a little from hub to hub. Ask one for a cure ingredient and it tells you which systems have it, and the hubs of those systems sell it; some can tell you that she passed through | [009](features/009-trader-hub.md) |
| Breakdown | Break any item down into components (like Arc Raiders) | — |
| Crafting and upgrades | Craft any item from components; upgrade gear | — |
| Ship as hub | Your ship is your home between runs (no base building for now) | [008](features/008-extraction-and-clone-loop.md) (minimal) |
| Travel and fuel | Two fuels, bought at the trader hubs: antimatter for the jump drive, to jump to the next star system (a day per jump), and hydrogen to fly to the ships and stations within a system. Antimatter takes days to procure, which keeps the player boarding ships while he waits (see [Travel and fuel](#travel-and-fuel)) | [011](features/011-system-map.md), [012](features/012-star-map-and-travel.md) |
| Star map | A map of the fixed, hand-made cluster (see [galaxy.md](galaxy.md)), all of it visible from the start (no fog of war), with about five systems in jump range of any system (a jump reaches at most 10 light years). Every system has a trader hub, and no system is riskier or richer than another. The player plans his route through the systems that have the cure's ingredients | [012](features/012-star-map-and-travel.md) |
| Intel | The map shows every system, but not what is in it: a system's ships and stations show only once the player arrives. Intel, bought at a trader hub, shows them and their details for another system before he jumps there, so he can tell which systems hold good salvage before he spends antimatter and a day on the jump | [012](features/012-star-map-and-travel.md) |
| Triangulation | In every system the player can measure a ping to her ship; combined, the pings give a search area on the star map that shrinks with every ping. Vague at first, clearer as the game goes on (see [Finding her](#finding-her)) | — |
| System map | The ships and stations to board in a star system, found at its planets, moons, asteroids, anomalies and battlefields. Inspect one to see what makes it dangerous, never a difficulty level: its wreck type, how many robots are still active in its security system, how many human enemies are aboard, how quickly it escalates, and the gear it requires. Choosing which ones to board is how the player chooses the risk. Every ship can be boarded once: afterwards it is gone, whether the android extracted or died | [011](features/011-system-map.md) |
| Location requirements | Some locations need specific gear or technology to enter (e.g. an oxygen supply for breached wrecks) | — |
| Wreck timer | A countdown until the wreck is destroyed | — |
| Oxygen | Limited air supply aboard breached wrecks | — |
| Escalation | Rival salvagers keep arriving the longer you stay | — |
| Story parts | Encrypted drives, found only on her company's ships, which are medium risk and need better gear and upgrades. Decrypted on the ship (a day or two) with the key she sent, some hold a key ingredient of the cure or instructions for making it; the final part is with her (see [The cure](#the-cure)) | — |
| Rescue clock | Every run and every jump takes a day. The days count up until her stasis message, then count down to the moment her ship blows itself up; the game sets that countdown so the player can just make it (see [Rescue clock](#rescue-clock)) | [011](features/011-system-map.md) (day counter only) |
| Her messages | One-way messages from her, arriving through the game in four phases that keep raising the stakes (see [Raising the stakes](#raising-the-stakes)) | — |
| Androids | The player starts with three and can buy more at certain hubs. Lose them all and the man must board himself, and his death is game over (see [Androids](#androids)) | — |

### Enemies

| Enemy type | Description | Feature |
|------------|-------------|---------|
| Robots | Automated defenses (e.g. turrets, security drones) and maintenance machines aboard stations and ships | [006](features/006-robot-enemy.md) |
| Humans | Rival salvagers, pirates and crews; also the arrivals that escalate contested wrecks | — |
| Aliens | TBD | — |
| Monsters | TBD | — |
| Infected | Humans or aliens taken over by a virus or fungus; maybe the test subjects of her virus, found on company ships | — |

### Controls

Gamepad is supported. There is no jump, prone or slide.

| Action | Keyboard / Mouse | Gamepad |
|--------|------------------|---------|
| Move | WASD | Left stick |
| Look / aim | Mouse | Right stick |
| Shoot: tap to fire, hold to charge a stronger shot | Left click | Right trigger |
| Aim down sights | Right click (hold) | Left trigger (hold) |
| Reload | R | X / Square |
| Interact / loot: hold to pry a container open; on a dropped item, opens the floor in the inventory; opens the ship's stash, trader terminal and system map console; hold on an airlock's outer door to board the wreck or return to the ship; continues past the run summary | E | A / Cross |
| Run summary after an extraction: unload the haul (pockets and backpack) into the stash | Q | X / Square |
| Sprint (e.g. to run for extraction) | Shift (hold) | Left stick click (lasts until you stop pushing forward) |
| Crouch (e.g. to move through vents) | Ctrl (hold) / C (toggle) | B / Circle (tap to toggle, hold to crouch until released) |
| Peek: hold, then move the mouse or right stick sideways to lean left or right while standing, or up to rise over cover while crouched (look only) | Alt (hold) | Left bumper (hold) |
| Aim out of cover: hold together with peek, in either order, to lean further out and shoot | Right click (hold) | Left trigger (hold) |
| Flashlight | F (toggle) | D-pad up (toggle) |
| Inventory: open and close (Esc and interact also close it) | Tab | View / Select (B also closes it) |
| In the inventory, the trader hub and the system and star maps: move the cursor | Mouse | Left stick / D-pad |
| In the inventory and the trader hub: drag an item | Left click (hold) | A (hold) |
| In the inventory: move a stack straight to the other side (container, stash or floor ↔ the player's slots) | Shift + left click, or double-click | X / Square |
| In the inventory and the trader hub: split a stack (take half into hand) | Right click (hold), release to put it down | Right bumper, A to put it down |
| In the inventory and the trader hub, while splitting: take one more or one fewer | Mouse wheel up / down | Right bumper / left bumper |
| In the inventory: drop an item on the floor | Drag it onto the floor, or release it outside the inventory | Y / Triangle |
| In the trader hub: buy one of an item (it goes to the stash) | Left click on it on the shelf | A |
| In the trader hub: sell one of an item in the stash | Left click on it | A |
| In the trader hub: sell a whole stack in the stash | Hold left click on it (1 s) | Hold A on it (1 s) |
| In the trader hub: fill the hydrogen tank | Left click on FILL UP | A |
| In the trader hub: order a full tank of antimatter | Left click on ORDER | A |
| In the trader hub: collect antimatter that has arrived (ORDER reads COLLECT) | Left click on COLLECT | A |
| Trader hub: close | Tab, Esc or E | View / Select or B |
| In the system and star maps: switch between the two tabs (the console opens on the system map) | Q, or left click on a tab's header | Left or right bumper, or A on a tab's header |
| In the system map: see a wreck's or the hub's details and the course there | Point at it | Point at it |
| In the system map: select a wreck or the hub | Left click on it | A |
| In the system map: fly to the selected wreck or the hub | Left click on FLY | A |
| In the star map: see a system's details and the jump there | Point at it | Point at it |
| In the star map: select a system | Left click on it | A |
| In the star map: buy intel on the selected system (at the hub) | Left click on BUY INTEL | A |
| In the star map: jump to the selected system (at the hub) | Hold left click on JUMP (1 s) | Hold A on JUMP (1 s) |
| System and star maps: close | Tab, Esc or E | View / Select or B |
| Pause | Esc | Menu / Start |

Gamepad bindings are a first draft.

### Win / lose conditions

- **Win a run:** extract alive and keep everything you carried out.
- **Lose a run:** die aboard, and lose everything you brought in and everything you found.
- **After death:** normally it is an android that dies, not you (see [Androids](#androids)). The link carries its
  memories back, so you remember everything up to the moment it died (which is what the run summary shows), and the
  gear dies with it. The disconnect knocks you out for a while, and by the time you come to, the ship is gone for
  good: the crew finds the dead android and knows it was boarded, so occupied ships lock down and fly off, and wrecks
  are claimed by other salvagers. The run ends at death, and there is no going back for the body. Dying costs the
  same single day as extracting.
- **End of the game:** reaching her always ends the game. If she is still alive, it is the good ending; if she has
  died, the bad one (see [Rescue clock](#rescue-clock)).
- **Game over:** you die yourself, which can only happen once all your androids are lost and you board in person;
  or the countdown runs out and her ship blows up.

### Androids

- He starts with three androids, the first one carrying the basic kit. When one dies he links into the next, which
  wakes in its charging cradle on his ship empty-handed: he arms it from the stash or buys a gun at the hub. With no
  gun and no bitcoin it boards unarmed, and he picks an easy wreck where it might loot a gun and get out.
- More can be bought at certain trader hubs: the pacing places them like the cure's ingredients, always among the
  systems in jump range, and a new android comes empty-handed too. Their price is another hidden pacing lever (see
  [Rescue clock](#rescue-clock)).
- If all of them are lost, the man has to board himself. He plays exactly like an android, with the same controls,
  health and kit; only his death is game over.
- If he has no androids left at the end, he boards her ship himself, carrying the cure: the tensest finale the game
  can have.
- On the home ship the player walks around as the android, past his own body in the link chair.

### Rescue clock

The whole game runs against a clock, which starts as a count of days and becomes a countdown.

- Until her stasis message (see [Raising the stakes](#raising-the-stakes)), the clock only counts the days that have
  passed.
- Her stasis message starts a countdown to the moment her ship blows itself up, the contingency she set so that
  nobody can get the virus. The game sets the countdown's length at that moment, from an estimate of how long this
  player needs to reach her, so that he can just make it in time. The whole game still comes to about 90 to 100
  days.
- Her pod can give out before the ship blows: in the last stretch of the countdown (about the last eight days), it
  is random whether she is still alive. Reach her before that stretch and she is sure to be alive. When the countdown
  runs out, her ship blows up: game over.
- Boarding a ship or station takes a day, whether the android extracts or dies, and so does every jump to another
  star system. Counting in days makes it easy to control how many ships the player boards over the whole game.
- Days only pass by boarding and jumping. Decrypting a drive, flying within a system and visiting the hub take no
  time, and the player can't wait without boarding.
- There is no way to buy her more days: a fixed clock keeps the pacing controllable and every day meaningful.
- **Hidden pacing.** The game never changes a ship or station once the player can see it: he always sees the true
  risk of every one he chooses to board. Behind the scenes it picks which ships and stations a system holds (how
  many, which kinds and how risky) at the moment they are revealed, on arrival or when he buys intel on the system,
  to suit how he is doing. It also adjusts how quickly he moves through the systems (such as how long antimatter
  takes to procure), when he gets the parts of the cure, what ingredients and androids cost, how quickly the
  triangulation narrows down her location, when her messages arrive and how long the countdown is, so that he
  arrives near its end. Getting there before its last stretch takes a good player.
- The numbers assume that about half of all runs end in a successful extraction.

### Travel and fuel

The ship runs on two fuels, both bought at the trader hubs:

| Fuel | What it does |
|------|--------------|
| Antimatter | Feeds the jump drive: a jump to another star system, which takes a day. Rare and expensive. A jump burns it by distance and a full tank reaches at most 10 light years, so the distances on the star map decide where the ship can go (see [galaxy.md](galaxy.md#4-the-map)); a short jump leaves some for the next |
| Hydrogen | Flies the ship within a system, between its planets, moons, asteroids, anomalies and battlefields, to the ships and stations there and back to the hub. Cheap and common |

- Early on the player is weak and can only take on the smallest wrecks, couriers, so a full tank of antimatter
  costs about the loot of a run or two on them, and the first systems take only a couple of runs. The wait for
  delivery grows through the game, so later systems take more.
- Antimatter isn't on the shelf: the hub needs days to procure it, and those days grow gradually through the game.
  The player can't wait without boarding, so he can't board one ship and jump; he boards ships while he waits. The
  procurement time is one of the hidden pacing levers (see [Rescue clock](#rescue-clock)).
- Nothing stores antimatter but the ship's tank, and an order always fills it. The player collects it at the hub
  once it has arrived, and the ship jumps only from the hub. After a jump the drive recharges for a day, so even with
  antimatter left over the player boards at least one ship in every system.
- A system never strands the player: while he can't jump on yet, easy ships turn up when too few are left to wait out
  a delivery, or to earn the antimatter when he can't afford it.
- Hydrogen is always on the shelf, and flying within a system or visiting the hub takes no time.
- Trading and refuelling only happen at the hub, and the ship never flies further than its tank can get it back to
  the hub, so it can't be stranded.
- The loop lives within a system: flying a loop through several ships before returning to the hub saves hydrogen and
  bitcoin, compared with flying back to the hub after every ship.

### Finding her

Her messages don't say where she is: the player finds her by triangulation.

- In every star system he visits, he can measure a ping to her ship. Her ship only answers to the key from her first
  message, so the nemesis can't follow it.
- Each ping gives a direction with an error cone, drawn on the star map, so the pings never pinpoint her early, the
  way real triangulation would after two or three clean readings. Where the cones overlap is the search area, which
  shrinks a little with every ping, so each jump visibly makes progress even before there is a clear direction.
- At first the cones are wide, so he moves almost at random; as the game goes on they narrow and point him in a
  direction. How quickly they narrow is one of the hidden pacing levers (see [Rescue clock](#rescue-clock)), and
  nothing else sharpens them: there is no receiver upgrade.
- Her location is random, on the far half of the map from his start and at least six jumps away (see
  [galaxy.md](galaxy.md#4-the-map)), so every playthrough is a different journey, and it is fixed when the game
  starts. The hidden pacing only changes how clear the pings are, never where she is, so a player who reads the pings
  carefully is never cheated.
- **The whole map is visible.** The cluster is fixed, the same in every playthrough (see [galaxy.md](galaxy.md)),
  and the star map shows all of it from the start; from any system there are about five systems he can jump to.
  What is in a system shows only on arrival or through [intel](#mechanics). The pacing picks which systems in reach
  have an ingredient or a hub still.
- **Budget.** The clock gives about 90 days, and every system costs about five or six on average (a couple of runs
  in the first systems and more later, plus the jump), so the whole journey crosses only about 15 to 18 systems.
  Her random location has to fit within that.
- The ping is not a way to talk. There are no comms: he can't reach her, and she doesn't know he is coming.

### The cure

The story parts are what it takes to make the cure for her virus: its key ingredients and the instructions for
making it.

- **Why the cure is scattered.** The cure wasn't on her station. To keep the nemesis from selling it, she wrote an AI
  to hide it, and the AI split it into pieces and scattered them across the company's ship network, on drives
  encrypted with her key. She stole the virus so he couldn't release it, and hid the cure so he couldn't sell it.
  - She hid the cure instead of deleting it because it was the only safety net if the virus ever got out, as it did,
    in her.
  - The AI only had access to the company's ship network, so it couldn't leak the cure outside it.
  - The nemesis can't decrypt the drives or tell which ones they are. Her husband can, because her second message
    came with the key; drives he carries out before it arrives wait until then.
- So the parts are on **encrypted drives**, found only on her company's ships.
- Company ships are medium risk: the player needs better gear and upgrades before he boards them. They can turn up
  throughout the game, since the hidden pacing controls when a drive holds a part.
- The cure takes about six parts: four ingredients, each one a hunt to find and buy, and two halves of the
  instructions.
- A drive is loot like any other: carried out to keep it, lost with the android. It decrypts on the ship in the
  background, with the result coming in a day or two later, and only then does the player learn what is on it. So he never knows whether a part was lost with an
  android: he only ever carries out a drive and hopes it holds what he is looking for.
- The decryption delay, and what the drives turn out to hold, let the game control when the parts arrive and move the
  story forward gradually (see hidden pacing in [Rescue clock](#rescue-clock)).
- A drive that holds an ingredient names it. The player asks for that ingredient at a trader hub, which tells him
  which star systems have it, and he plans his route through those systems. The game puts the ingredient in one or
  more of the systems he can jump to, so it is always within reach. Maybe, if he is doing well, an
  ingredient sits in a system a little way back, so he has to double back.
- He buys the ingredient at the trader hub of a system that has it, so an ingredient can never be lost. It is
  expensive, so it costs extra runs and with them days, and its price is another hidden pacing lever.
- Drives that hold no part still pay: company data that sells well, which buys fuel, and the nemesis's logs and
  company records, which tell his side of the story. Every drive is worth carrying out.
- He mixes the cure at his ship's workbench once he has all the parts he can collect.
- She holds the final part herself: the virus sample. The cure has to be tuned to the live strain, so the android
  finishes it at her pod with her sample. The sample is also the evidence against the nemesis.

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

- **The player chooses the risk.** Every ship and station in a star system shows up front what makes it dangerous
  and what it requires, so the player decides how much to gamble. It never shows a difficulty level: the game rolls
  each location's difficulty (five levels) behind the scenes, and the player sees its details instead, such as how
  many robots are still active in its security system, how many human enemies are aboard or how quickly rival
  salvagers arrive, and judges what he can handle. No location is forced on them. Star systems themselves are no
  riskier or richer than each other: the risk lies only in which ships and stations the player boards. The other
  risk is time: every run costs a day of her pod.
- Difficulty is tuned so that about half of all runs end in a successful extraction. The hidden pacing never changes
  a ship the player can see: it picks which ships a system holds when they are revealed, and how quickly the journey
  moves (see [Rescue clock](#rescue-clock)).
- Her company's ships, the only ones that carry the encrypted drives, are medium risk: the player needs better gear
  and upgrades before boarding them (see [The cure](#the-cure)).
- On day 0 the player starts in a random system on the outer ring of the map (see
  [galaxy.md](galaxy.md#4-the-map)) with three androids, the basic kit, a little antimatter (too little for any
  jump) and a little bitcoin: not enough for more antimatter, so the first system already needs runs.
- Gear and technology gate harder locations. Progression mostly means unlocking access to riskier, richer wrecks.
- Early game uses quiet wrecks only. Timers, oxygen and escalation are introduced later as the pressure ramps up
  (see [Run pressure](#run-pressure)).
- The rest is TBD.

## 3. World and story

### Setting

Sci-fi, the outer rim of space, where wars and battles have left derelicts and battlefields everywhere and made the
companies that fight them rich. The player is a man, a salvager working derelict and occupied stations and ships.
Boarding them is too deadly for people, so salvagers on the rim send androids: from his own ship he mind-controls an
android that goes aboard. He is no soldier. When an android dies, the link lets him remember what it went through,
but the disconnect knocks him out for a while; then he links into the next one, if he has one left (see
[Androids](#androids)).

The rim trades in bitcoin (₿). Nobody docks to trade there: a ship trades with a system's trader hub over the comms
link, and drones carry all the cargo between them: what he sells goes out of his ship's hold, and what he buys comes
back to it. So he trades from a console without ever leaving his ship.

The galaxy, its star systems and the factions at war over them are in [galaxy.md](galaxy.md).

### Story summary

The man is out to save his wife, who trusts no one but him. She worked for Halden-Mori, a mercenary army and
weapons maker, in its bioweapons division on a space station. The division builds weapons for
contracts, but the company's top researcher, a high-up executive, was creating a virus there off the books: with
the company's resources, but without its knowledge or approval. His plan: release the virus on civilians, then make
a fortune selling the cure. Even a mercenary army would be finished if that came out.

She did not agree with it morally, so she defected: she stole the virus, wrote an AI to hide the cure, and fled, far
away and on her own. The station's defences damaged her ship as she fled, and it finally gave out deep in space,
many star systems away. And she got infected: the virus kills slowly, over months.

She has no one else to turn to: on the war-torn rim the company is the nearest thing to law, no hospital knows the
virus, and infected, she can't go to the nearest station. So she sends her husband private, encrypted messages,
meant only for him. They arrive one by one over the course of the game, and each one raises the stakes (see
[Raising the stakes](#raising-the-stakes)): she needs him to find her; she is infected and the cure is hidden on
the company's ships; she will blow up her ship so that nobody can get the virus; and finally, she is very sick and
has gone into a stasis pod, which holds the virus off, and the countdown starts. None of them says where she is: he
has to find her by triangulating her ship's ping (see [Finding her](#finding-her)). The messages only go one way: he
can't reach her, and she doesn't know he is coming.

He has no link to the company: he is an ordinary salvager. To save her he needs the cure: its key ingredients and
the instructions for making it. They are the story parts, found on encrypted drives (see [The cure](#the-cure)).
She holds the final part herself (the virus sample), so the last stop is her.

Along the way a hub she passed through can tell him she was there: a still image with narration, which builds up
the story without cutscenes.

**The nemesis.** The researcher who created the virus is the story's bad guy, and the only one looking for her, but
he doesn't know which way she went: only her husband gets her messages. The player never meets, fights or defeats
him: he exists only in the narrative. He shows up through what the player decrypts (his logs and company records,
on drives that hold no part of the cure) and in hub stills, such as his bounty on her.

**The end.** Reaching her always ends the game, with a final playable run: an android boards her ship with the
cure, and an android can't catch the virus. If she is still alive, it is the good ending: the android wakes her and
gives her the cure, and she comes aboard his ship. Her sample and records reach the company, and the nemesis flees.
If she has died, it is the bad ending. If the countdown runs out first, her ship blows up: game over.

The detailed story is still written near the end of development, but this premise stands.

### Raising the stakes

The stakes must keep rising throughout the game. Her one-way messages drive this: each one arrives as a still with
narration, and the hidden pacing decides when (see [Rescue clock](#rescue-clock)).

| Phase | Her message | What changes for the player |
|-------|-------------|-----------------------------|
| 1. Find me | Her ship is stranded deep in space, and she needs him to come and find her. The game opens on this message | The journey starts: he triangulates her ping from system to system. The clock counts the days that have passed |
| 2. The cure | She is infected, and the cure is hidden on the company's ships. It comes with the key to decrypt their drives | The company's ships and their encrypted drives become the goal |
| 3. The contingency | She will blow up her ship so that nobody can get the virus | A deadline now exists, though he doesn't know yet how long it is |
| 4. Stasis | She is very sick and has gone into a stasis pod | The countdown starts, and the game sets its length so that he can just make it |

More lore and story twists can be added between the phases later.

### Characters

The cast, the companies and the other people and organisations of the cluster are in [characters.md](characters.md).

## 4. Levels / content

Locations are not hand-built levels. They are assembled from a kit of predefined **sections** (corridors, rooms,
airlocks, vents, elevators). Every deck is flat: decks connect only by elevators, with no stairs, ramps or ladders. Each ship and station class has a **blueprint** that describes how its sections fit together,
and missions populate the result with enemies and loot to suit the difficulty (see [Modding](#modding)). Size scales with difficulty: small ships take about 5 minutes,
and the largest stations take up to 30.

| Level / area | Purpose | Key mechanics introduced | Feature |
|--------------|---------|--------------------------|---------|
| Blueprint-based generation | Builds each wreck's layout from its class blueprint | — | — |
| Star systems | The hand-made systems of a fixed galaxy (see [galaxy.md](galaxy.md)): each has a trader hub, plus ships and stations at planets, moons, asteroids, anomalies and battlefields | — | [011](features/011-system-map.md), [012](features/012-star-map-and-travel.md) |
| Small ships | Early game, about 5-minute runs: hand-built layouts (courier, hauler, freighter) with robots and loot rolled every run | Core loop | [002](features/002-wreck-section-kit.md), [010](features/010-wreck-variety.md) |
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

- **Menus:** main menu, pause, settings, inventory (slots), crafting and breakdown, star map, trader hub.
- **HUD:** classic, with corner indicators for health, thermal clip heat, oxygen (on breached wrecks) and the wreck timer
  (on doomed wrecks), and at home on the ship the bitcoin in the wallet.

## 8. Scope

The MVP, milestones and build order are tracked in [roadmap.md](roadmap.md).

## 9. Open questions

None right now. The detailed story, the names of the man, his wife, the nemesis and the virus, and the writing come
near the end of development (see [characters.md](characters.md)).
