# FFXI Windower Addons

Personal GearSwap job files and Windower addons for Final Fantasy XI (retail).

**Character:** Ashkev (alt: Jaheira)

## Architecture

All GearSwap files use raw, explicit event handlers — no Mote-Include framework.
Weapons are never placed inside gear sets (equipping a weapon zeroes TP).

## Structure

- `gearswap/` — Job-specific Lua files loaded by GearSwap
- `addons/` — Custom Windower addons
