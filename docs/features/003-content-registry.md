# 003 — Content registry and definitions

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | none |

## Goal

A data-driven content registry that discovers and registers content definitions (items, weapons, enemies, sections) by ID, so new content is plug and play.

## Player experience

Invisible to the player. It enables the moddable, plug-and-play content vision (see Modding) and the pillar *Everything is salvage*.

## Requirements

### Definitions

- [x] A generic registry that registers any kind of content definition. Every definition extends a base
      `ContentDefinition`; adding a new kind of content means adding a subclass, with no change to the registry.
- [x] `ContentDefinition` holds what every kind shares: its `id` and `pack` (filled in by the registry) and a
      `display_name`.
- [x] `SectionDefinition` for wreck sections, with a definition for each of the 10 kit pieces from 002.
- [x] Definitions are small resources that load at startup. Their scenes, models and sounds are referenced by
      path and only load when used, so startup doesn't slow down as content grows.

### Content folders

- [x] Content lives in packs under `game/content/`. The base game is the first pack, `game/content/base/`, and
      loads exactly the way external packs will.
- [x] Each piece of content is self-contained in its own folder, grouped by kind
      (`content/base/sections/airlock/`), holding its definition and its own scene, model and sounds. The 10 kit
      scenes move there from `scenes/sections/`; framework code (`Section`, `Socket`, `SectionMarker`) and shared
      parts (doors, lamps, buttons, materials) stay in `scenes/sections/`. The elevator's own script and ding
      sound move into its folder.

### IDs

- [x] Every definition is registered under the ID `pack:name`, taken from its path: the pack folder and the
      content's own folder, e.g. `content/base/sections/airlock/` is `base:airlock`. IDs are never typed into a
      definition, so they can't be mistyped or copied by accident, and two packs can't clash.
- [x] Names are unique within a pack across all kinds of content. A content folder holds exactly one
      definition.

### Registry

- [x] A `ContentRegistry` autoload scans `game/content/` at startup and registers every definition before the
      first scene loads. It scans in a way that also works in exported builds.
- [x] Systems look content up by ID, or list every definition of one kind (such as all sections), sorted by ID
      so the order is the same on every run.
- [x] Problems are logged as errors and kept in a list, and the rest of the content still loads: duplicate IDs,
      a content folder with no definition or more than one, and a definition whose scene file is missing.
      Looking up an unknown ID logs an error and returns nothing.
- [x] Startup logs a summary: packs, definitions of each kind, and errors.

### The small wreck

- [x] The small wreck stays a hand-placed scene that can be edited in Godot. When it loads, every section in it
      must be a registered section, found by its scene; one that isn't is reported as an assembly error, like a
      loose socket.

### Tests

- [x] Unit tests run the registry on fixture packs in `tests/`: IDs from paths, lookups by ID and by kind, a
      test-only kind of definition that registers with no change to the registry, and each reported problem.
- [x] Every registered section's scene loads with a `Section` root. The small wreck has no unregistered
      sections, and a wreck with an unregistered section reports it.

## Out of scope

- Item, weapon and enemy definitions: 005, 006 and 007 each add their own definition type and content when they
  are designed.
- Loading external packs and Steam Workshop (idea backlog). The base pack proves the loading path they will use.
- Packs overriding each other's content by ID.
- Breakdown components and crafting recipes on definitions (breakdown and crafting are post-MVP).
- Building wrecks from section IDs: that is blueprint-driven assembly (post-MVP).

## Technical notes

- **Layout.** `content/<pack>/<kind>/<name>/` holds one `ContentDefinition` resource (`<name>.tres`) next to the
  files it uses. The ID is `<pack>:<name>`; the kind folder only groups content and is not part of the ID.
- **Files.** `game/autoload/content_registry.gd` is the `ContentRegistry` autoload (no `class_name`, which would
  clash with the autoload's name). `game/scripts/content_definition.gd` (`ContentDefinition`) is the base class;
  `game/scenes/sections/section_definition.gd` (`SectionDefinition`) sits next to `Section`.
- **Scanning.** `ResourceLoader.list_directory` lists folders and resources, including the remapped ones in an
  exported build, where `DirAccess` would see `.remap` files. Every `.tres` or `.res` in a content folder is loaded and
  kept if it is a `ContentDefinition`; other resources (materials) are ignored. The scan takes its root folder
  as a parameter, so tests can point a fresh registry at fixture packs.
- **Lazy references.** `SectionDefinition.scene` is an `@export_file("*.tscn")` path, resolved with
  `ResourceUID.ensure_path`, so a `uid://` picked in the inspector works too. The registry checks the file
  exists when it registers the definition but doesn't load it.
- **The wreck check.** `Wreck` collects the scene paths of every registered `SectionDefinition` and adds an
  assembly error for each section whose `scene_file_path` isn't among them.
- **Tests.** `tests/autoload/content_registry_test.gd` runs fresh registries on `tests/autoload/content_fixtures/`:
  `valid/` holds the packs `alpha` and `beta` with a test-only gadget kind, and `broken/` holds one of each
  reported problem. `tests/content/base_content_test.gd` checks the base pack as the autoload registered it, and
  `tests/sections/wreck_test.gd` the unregistered-section check.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
