# Locust

A survive-the-killer Roblox game inspired by Murder Mystery 2 (MM2) and horror "hunt or be hunted" formats.

## How it plays

- Players vote between two maps (Carnival / Neighborhood).
- One player is randomly chosen as **the Locust** (the killer) each round — the game avoids picking the same Locust twice in a row when there's more than one player.
- The Locust gets a speed boost, a distinct look, and a weapon (HyperlaserGun), and is held in a hold box before being released onto the map.
- Everyone else is a survivor: survive the timer, or reach an escape exit before time runs out.
- Survivors can die (health reaches 0) or escape (reach an `EscapeExit` gate during the escape phase).
- The round ends early once every survivor is dead or has escaped, and everyone is returned to their cabin for the next round.

## Project structure

All scripts are `Script` instances (server-side) inside Roblox Studio. Paths below show where each one lives in the Explorer.

| File | Roblox path | What it does |
|---|---|---|
| `src/MapVoteHandler.server.lua` | `Workspace.MapVote.MapVoteHandler` | Main game loop: voting, map selection, Locust selection, survivor spawning, death/escape tracking, round timers, and sending everyone back to their cabin between rounds. |
| `src/DoorManager.server.lua` | `ServerScriptService.DoorManager` | Rigs every simple `Door` part in the world with a `ProximityPrompt` so it swings open instead of just vanishing. Skips compound `Door` **Models** (frame + separate door leaf assets) since animating the whole model breaks them. |
| `src/ForceCabinSpawn.server.lua` | `ServerScriptService.ForceCabinSpawn` | Assigns each joining player to their own numbered `Spawn` / `Spawn2` / `Spawn3`... part so players don't stack on top of each other in the lobby. |
| `src/KnifeDamage.server.lua` | `ServerStorage.Knife.KnifeDamage` (a `Script` inside the `Knife` tool — kept for reference; the live weapon is currently the HyperlaserGun) | Melee weapon logic: the Locust can hit nearby survivors they're facing to instantly down them. |

## World setup this code depends on

These need to exist as named Parts/Models in Workspace for the scripts above to work:

- `LocustHoldBox` — where the Locust waits before being released.
- `LocustReleasePoint<MapName>` (e.g. `LocustReleasePointCarnival`) — where the Locust is teleported when released.
- `PlayerSpawn<MapName>` (e.g. `PlayerSpawnCarnival`) — survivor spawn points for that map, can have multiple.
- `EscapeExit<MapName>` (e.g. `EscapeExitCarnival`) — a **Model** (arch/gate structure); touching any part inside it during the escape phase marks a survivor as escaped.
- `Spawn`, `Spawn2`, `Spawn3`, ... — lobby/cabin spawn points, one per expected player.
- `MapVote1` / `MapVote2` — the voting pads players stand on to vote.
- `Map1` / `Map2` — the boards showing live vote counts.
- `VotingStatus` — the sign showing round status text.
- `ServerStorage.HyperlaserGun` — the weapon cloned into the Locust's backpack each round.

## Status

Core round loop (voting → map load → Locust selection → hold/release → survive/escape → death tracking → reset) is working and has been tested with two players. Known gaps:

- No real character model / morph for the Locust yet beyond a dark neon color + red eyes fallback (used when `ServerStorage.LocustMorph` isn't set up).
- Round length and vote timers are currently tuned for fast local testing (`VOTE_TIME = 20`, `SURVIVAL_PHASE_TIME = 180`, `ESCAPE_PHASE_TIME = 60`) and may need tuning for real play sessions.
