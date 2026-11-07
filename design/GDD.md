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
- Player: Blue **(proposal)**. Enemy: Red, AI.
- Each side: 4 units = 1 hero + 3 troops **(proposal: 2 infantry + 1 light vehicle,
  mirrored stats for v1 so the fight is fair)**.
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
