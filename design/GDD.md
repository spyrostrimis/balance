# Game Design Document — Balance

Status: early draft. Lines marked **(proposal)** are suggestions not yet decided.
Everything else has been agreed.

## Pillars
1. **Scarcity.** One rare resource, small armies. Better to repair than to rebuild.
   Every unit is worth keeping.
2. **Heroes.** Every side is led by a hero with abilities, in the spirit of
   Warcraft III and DotA. Your hero must not die.
3. **Nuanced factions.** Good vs evil, but no side is simply right.
4. **Readable danger.** Hazards and creatures follow rules the player can learn and play around.

## Inspirations (tributes, not copies)
Games: Dune II, Command & Conquer, C&C: Red Alert, Warcraft III: Reign of Chaos,
DotA / DotA 2, Northgard.
Stories and lore: Dune, Transformers, The Lord of the Rings, Greek mythology,
ThunderCats, Star Wars.

Rule: we borrow mechanics and archetypes, never names, factions, designs or assets.

## The resource: Orichalcum
- Named after the legendary metal of Atlantis in Plato's *Critias*.
- Found inside big rocks (deposits). No open fields like Dune II's spice: deposits are
  rare and finite, so sides must fight over them.
- **Harvester:** a transforming machine. As a truck it drives to the deposit, transforms
  into a humanoid robot that carves the Orichalcum out of the rock, transforms back into
  a truck and drives back into the Refinery.
  - Prototype: separate truck and robot models swapped behind a particle effect.
    The real transformation animation comes later.
- The harvester is a high-value target.

## Factions
Placeholder names by colour until real names are chosen.

### Blue — the generally good guys
More democratic, more about self-determination and freedom. But like the Jedi they can be
flawed: bureaucratic, slow to decide, arrogant, lost touch with common people.
They want to bring balance to the galaxy by removing and resisting the autocracy and
injustice of the powerful.
- Gameplay identity **(proposal)**: research and upgrades take longer but cost less;
  strong once upgraded; repair and morale auras.
- Campaign: yes (full, galaxy-scale).

### Red — the generally bad guys
They say they want balance and peace in the galaxy too, but through powerful leadership,
structure and ruthlessness. The ends justify the means. Nothing will stand in their way.
Decisive and effective.
- Gameplay identity **(proposal)**: fast production, high damage, little or no healing;
  possible sacrifice mechanics (spend a unit's life for power).
- Campaign: yes (full, galaxy-scale).

### Green — the opportunists
No plan to conquer the galaxy. About the here and now. Totally immoral.
Sneakier, with lethal weapons, but their army is less coordinated, less cohesive and
weaker than Blue and Red.
- Gameplay identity **(proposal)**: stealth and ambush, glass-cannon units, no group
  bonuses; salvage — gain Orichalcum from destroyed wrecks (they profit from everyone
  else's war).
- Campaign: a small one (e.g. controlling three neighbouring planets for commerce)
  and/or stand-alone missions.

### Palatinate — the Clergy
Religious, mysterious fanatics. Like the Emperor's forces in Dune II.
- Always AI, always against the player. Sometimes against everyone on the map,
  sometimes siding with your enemies.
- Never playable, so they don't need to be balanced and can break the rules.
- Campaign: none.

## Heroes
- Every side has one main hero. The hero can differ from map to map.
- Each hero has active and passive abilities.
- **The hero rule (all maps, always):**
  - If your hero is downed, the mission fails. Your hero must not die.
  - Enemy heroes can't die either. At 0 HP they are deactivated (shown injured/disabled).
    The mission does not end when you down the enemy hero.
  - The same rule applies to every faction, Green and Palatinate included.
    The Palatinate may recover their leader by stranger means **(proposal)**.
- **Fairness requirements:**
  - Low-HP warning: alert, pulsing portrait, sound.
  - Every hero has an escape option: self-repair, retreat or recall **(proposal: which one per hero)**.
- **Downed enemy hero:**
  - Loses its aura and abilities while down — that's the window to push.
  - A recovery unit comes, picks up the hero and carries it home.
  - Destroy the recovery unit → the hero stays down longer, or for the rest of the
    mission **(proposal: which one)**.
  - Recovery unit gets home → the hero returns repaired after a delay.

### Hero abilities for Mission 1 (one active + one passive)
- **Blue Leader:** Repair (active — heals a friendly unit, can target self, which is the
  escape option); Encouragement (passive aura — bonuses to nearby troops).
- **Red Leader:** Heavy Cannon (active — a powerful weapon, working name, inspired by
  Megatron's but not copied); passive **(proposal: e.g. "Ruthless" — bonus damage
  against damaged units)**; escape option **(proposal)**.
  ⚠ Passive and escape option need a decision before milestone 5.

## Movement
Decided (playtest feedback after milestone 2):
- **One unit per cell.** A unit can't stop on a cell that holds a rock, cliff,
  building or another unit.
- **Air units** fly over rocks, cliffs, buildings and ground units, and ground units
  can pass under air units. But no unit, air or ground, can *stop* on a cell that
  is blocked or already taken.
- **Clicking a blocked cell** (rock, cliff, unit): the units go towards it and stop
  on the nearest free cells in front of it.
- **Clicking past an obstacle:** units find a path around it if one exists.
  If the spot can't be reached at all, they go to the nearest reachable cell.
- **Group orders** spread the units over the nearest free cells around the click
  instead of stacking them.

Implementation choices (proposal, easy to change):
- A unit holds two cells while stepping between them.
- A unit blocked by another unit waits briefly, then looks for a way round. If it
  is still stuck after 3 seconds, it picks a new nearby spot once, then stops.
- Ground units don't squeeze diagonally between two obstacles.

## Combat
Milestone 4. All rules and numbers below are **(proposal)** until you confirm them.
- **Auto-attack:** idle units engage the nearest enemy within their *engage range*.
  They walk into attack range and fire. They give up on that enemy if it gets
  1.5 cells beyond the engage range.
- **Move orders:** moving units don't shoot. They fight again once they arrive.
- **Attack orders** (right-click an enemy): chase the target until it is in range,
  then fire until it dies or is downed.
- **Fighting back:** an idle unit that gets shot targets its attacker, even one
  outside its range.
- Units only fire while standing still (not between cells).
- All shots in a tick land at the same time, so a mirrored 1v1 is a draw.
- Range is measured centre to centre in cells. Rocks don't block shots yet
  (no line of sight).
- **Death:** troops at 0 HP die and free their cell. Heroes at 0 HP are **downed**:
  they fall over, stay on their cell, can't act or be targeted, and show "DOWN".
  The full downed rules (mission fail, warning, recovery unit) come in milestone 6.

Placeholder stats (mirrored for both sides, in `data/units/`):

| Unit | HP | Damage | Cooldown (s) | DPS | Range | Engage range | Speed |
|------|----|--------|--------------|-----|-------|--------------|-------|
| Leader | 400 | 20 | 1.0 | 20 | 4.0 | 6.5 | 2.2 |
| Infantry | 120 | 10 | 1.0 | 10 | 3.5 | 6.0 | 2.0 |
| Light vehicle | 220 | 24 | 1.6 | 15 | 4.5 | 7.0 | 3.0 |

Observed in the self-test: Blue attacks Red's base and loses. The faster light
vehicle arrives first and gets focused, so Blue fights 3 against 4. Group speed
(units moving at the pace of the slowest) is an open question.

## Hazards and creatures
- Like the Dune worms: creatures that roam and cause havoc. Different planets, different creatures —
  e.g. a pterodactyl or a huge lizard that eats harvesters, troops and civilians and can
  cause structural damage.
- Each creature needs learnable rules **(proposal examples: only travels on certain
  terrain; attracted by vehicles; hunts lone units, avoids groups)**.

## Missions
- Classic objective: destroy the enemy base. Other objectives are welcome.

### Mission 1 — "The Rock" (working name)
- Purpose: teach the basics by playing.
- Small map (32×32 cells). The Orichalcum rock is in the middle.
- Map layout **(proposal)**: `data/maps/mission_01.tres`. Desert planet, cliff-walled.
  Point-symmetric (each side sees the same map rotated 180°) for a fair fight. Blue
  starts south-west, Red north-east. The 2×2 Orichalcum rock in the centre has four
  boulder clusters around it with open approaches from N/S/E/W. Cliff spurs and
  boulder groups split the field into a direct route and two flanks.
- Player: Blue **(proposal)**. Enemy: Red, AI.
- Each side: 4 units = 1 hero + 3 troops **(proposal: 2 infantry + 1 light vehicle,
  mirrored stats for v1 so the fight is fair)**.
- Placeholder stats **(proposal)**, in `data/units/`: move speed (cells/s) hero 2.2,
  infantry 2.0, light vehicle 3.0. Both sides use the same troops; the two Leaders
  share stats until their abilities are added.
- No base, no economy, no buildings.
- Objective **(proposal)**: standing in the capture zone around the rock with no enemy
  units in it fills a capture bar; hold the rock for 60 seconds to win.
- Win **(proposal)**: capture and hold the rock, OR destroy all enemy troops while their
  hero is downed.
- Lose: your hero is downed, OR the enemy captures and holds the rock.
- Downing the enemy hero should be the natural way to win the rock.

## Open questions
- Real names for the four factions and the heroes.
- ~~Working title of the game.~~ **Answered: Balance.**
- Unit roster per faction beyond Mission 1.
- Recovery unit: what happens if it's destroyed (longer downtime vs out for the mission).
- Red Leader's passive and escape option. **Needs a decision before milestone 5.**
- Mission 1 has no base: where does the enemy's recovery unit come from
  (enters from a map edge, arrives by dropship, …)?
- Are the troops machines, people, or both? (Blue's "Repair" ability suggests machines.)
- Should a group move at the speed of its slowest unit (formation speed)?
- Should rocks and cliffs block shots (line of sight)?
