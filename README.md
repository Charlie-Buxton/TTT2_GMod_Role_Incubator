# Incubator Role for Trouble in Terrorist Town 2

A custom social-deduction game role for [TTT2](https://docs.ttt2.neoxult.de/), built in Lua for [Garry's Mod](https://store.steampowered.com/app/4000/Garrys_Mod/).

Incubator begins the round disguised as an ordinary Innocent. When they are killed, their death creates a new threat: after a short delay, a hostile mutant hatches from their corpse with a burst of blood and sound effects.

[Trouble in Terrorist Town](https://www.troubleinterroristtown.com/) is a multiplayer social-deduction mode included with Garry's Mod. A small group of hidden Traitors must eliminate the Innocent players before they are discovered. TTT2 expands TTT with a framework for custom roles, equipment, settings, and win conditions. This repository adds one of those roles.

## What Incubator Does

Incubator is on the Innocent team, but their identity is concealed while they are alive.

After Incubator dies:

- A warning growl plays immediately at the player's position.
- The addon waits three seconds before hatching the mutant.
- The hatch position is taken from the player's corpse where possible.
- One of two Podbeg mutant variants is chosen at random.
- A splat sound and a large blood effect play when the mutant appears.
- Only one mutant can hatch from each Incubator death.
- Spawned mutants are tracked and removed when the next round begins.

Incubator has no equipment shop or starting credits. The role exists to add a small consequence to an otherwise ordinary death: eliminating a player can make the round more dangerous rather than less.

## Example Round

Player 1 is secretly assigned Incubator but appears to be a normal member of the Innocent team. Nobody else is told that Incubator exists.

When Player 1 is killed, the nearby players hear a growl. Three seconds later, a mutant hatches from the corpse with a splat sound and a burst of blood. The remaining players now have to react to an AI-controlled threat while still trying to work out who the Traitors are.

The result is a simple mechanical twist with a social consequence: a body is no longer just evidence. It can also become an immediate danger.

## Project Structure

```text
src/ttt2-role_incubator/
|-- addon.json                                      # Garry's Mod addon metadata
|-- lua/terrortown/
|   |-- entities/roles/incubator/shared.lua         # Main role behavior
|   `-- lang/en/incubator.lua                       # English UI text
|-- materials/vgui/ttt/dynamic/roles/
|   |-- icon_incu.vmt                               # Optional role icon material
|   `-- icon_incu.vtf                               # Optional role icon texture
`-- sound/incubator/
    |-- growl.wav                                   # Warning sound on death
    `-- splat.wav                                   # Hatch sound
```

## Configuration

TTT2 provides its usual role controls for enabling the role and tuning how often it appears.

| Setting | Default |
| --- | --- |
| Team | Innocent |
| Publicly revealed role | No |
| TTT2 role percentage value | `0.13` |
| Maximum Incubators per round | `1` |
| Minimum players | `6` |
| Starting credits | `0` |
| Shop access | Disabled |

The hatch delay and possible NPC classes are currently code-level constants:

| Setting | Default |
| --- | --- |
| Hatch delay | `3` seconds |
| Possible mutant classes | `npc_vj_ah_podbeg`, `npc_vj_ah_podbegorange` |

## Running the Addon

### Requirements

- [Garry's Mod](https://store.steampowered.com/app/4000/Garrys_Mod/)
- A server running [TTT2](https://docs.ttt2.neoxult.de/)
- [VJ ATOMIC HEART : MUTANT NPC](https://steamcommunity.com/sharedfiles/filedetails/?id=2951420390)


### Local Installation

Copy the addon folder into the Garry's Mod addons directory:

```text
src/ttt2-role_incubator/
```

becomes:

```text
garrysmod/addons/ttt2-role_incubator/
```

Start a TTT2 server and enable the Incubator role through the standard TTT2 role settings.

## Manual Test Checklist

1. Start a TTT2 round with the role enabled.
2. Assign or roll the Incubator role and kill that player.
3. Confirm that the growl plays immediately.
4. Confirm that exactly one mutant spawns near the corpse after three seconds.
5. Confirm that the splat sound and blood effects play at the hatch position.
6. Start the next round and confirm that the spawned mutant is removed.

