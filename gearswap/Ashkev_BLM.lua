----------------------------------------------------------------------------------------------------------------
-- Ashkev_BLM.lua  (Raw GearSwap - No Mote-Include)
-- Black Mage GearSwap script using explicit precast/midcast/aftercast/status_change/buff_change functions.
-- No Mote-Include dependency. No background polling. No coroutine accumulation.
-- Weapons (main/sub) are NEVER baked into gear sets (a weapon swap zeroes TP and cancels pending
-- weaponskills). Swap weapons manually; the only place a weapon belongs is a dedicated toggle set.
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------------------------------------------------
-- Nuke stance: cycles between two damage sets via Ctrl+` (//gs c cycle nuke).
--   'FreeNuke' -> Spaekona's Coat +4 body (2% dmg->MP conversion; sustain).
--   'Nuke'     -> Full Wicce +2 (Empyrean set proc; damage-focused).
-- Cycle order: FreeNuke <-> Nuke.
-- Magic Burst is NOT in this cycle -- it's driven entirely by MagicAssistant arming
-- burst_until below, and overrides the stance for the burst window. If MAA isn't
-- running, no burst set fires (previous manual Ctrl+` toggle removed 2026-09-17).
-- Nuke2 (full Amalric +1 MAB test set) removed 2026-09-17 after live-play testing:
-- Wicce set proc consistently beat Amalric's raw MAB stacking. Kept FreeNuke for the
-- fast MP-drop fallback when Sublimation/Myrkr backups are down.
nuke_stance = 'FreeNuke'
hoxne_mode  = false  -- toggle with Alt+`  (//gs c toggle hoxne) -- current nuke set + Hoxne Ring (left)

-- Occult Acumen TP-building mode. Toggle with F9 (//gs c toggle oa). While ON and TP is below
-- oa_tp_cutoff, Elemental Magic midcast uses the Occult Acumen set (TP from MP spent) instead of
-- the nuke sets. At/above the cutoff, or with the toggle OFF, nuking behaves exactly as before.
oa_mode       = false
oa_tp_cutoff  = 2000   -- player.tp runs 0..3000; below this, OA gear is worth more than nuke gear

-- Auto magic-burst window. MagicAssistant sends 'gs c MAABurst <elements>' just before it casts a
-- burst; that arms this window so the imminent nuke uses the Magic Burst set automatically, without
-- touching the manual toggle. MAA re-sends per burst cast, so chained bursts stay covered. If MAA
-- isn't running, nothing fires this and the manual toggle is the only path.
burst_until          = 0   -- os.clock() timestamp until which the burst window is armed
burst_window_seconds = 5   -- how long an MAA burst signal keeps the Magic Burst set armed

-- Survival: at/below this HP%, drop to the idle set (already -DT maxed) while engaged.
hp_dt_threshold = 40

-- Adoulin speed body: equip Councilor's Garb as idle body in Western/Eastern Adoulin.
in_adoulin = false

-- Elemental debuff spell names
local elemental_debuffs = {
    ['Rasp']  = true,
    ['Choke'] = true,
    ['Shock'] = true,
    ['Burn']  = true,
    ['Drown'] = true,
    ['Frost'] = true,
}

-- Equip Hachirin-no-Obi when the spell's element matches the current weather or day, capping
-- the day/weather elemental bonus. NO-OP until you own the obi (GearSwap silently skips gear
-- you don't have), so this is safe to leave wired now and will activate the moment you get it.
local function apply_elemental_obi(spell)
    if spell.element and (spell.element == world.weather_element or spell.element == world.day_element) then
        equip({waist="Hachirin-no-Obi"})
    end
end

----------------------------------------------------------------------------------------------------------------
-- GEAR SETS
----------------------------------------------------------------------------------------------------------------
function get_sets()

    ------------------------------------------------------------------------
    -- PRECAST: FAST CAST
    ------------------------------------------------------------------------
    sets.precast = {}
    sets.precast.FC = {
        ammo="Impatiens",
        head={name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        body={name="Merlinic Jubbah", augments={'Mag. Acc.+25 "Mag.Atk.Bns."+25','"Fast Cast"+7','INT+7','Mag. Acc.+6','"Mag.Atk.Bns."+7'}},
        hands={name="Merlinic Dastanas", augments={'Attack+16','"Fast Cast"+5','CHR+6'}},
        legs={name="Merlinic Shalwar", augments={'Attack+20','"Fast Cast"+7','VIT+9','Mag. Acc.+8','"Mag.Atk.Bns."+6'}},
        feet={name="Merlinic Crackows", augments={'"Fast Cast"+6','VIT+8','Mag. Acc.+9','"Mag.Atk.Bns."+12'}},
        neck="Orunmila's Torque",
        waist="Embla Sash",
        -- Malignance is pinned to the LEFT ear in EVERY set it appears in (this file). Wicce +1's
        -- MAB+8 is a right-ear-only bonus, so nuke/enfeeble sets must hold Wicce right + Malignance
        -- left; to stop Malignance from cross-slot swapping (which fails silently) on the transitions
        -- into these sets, FC/idle/WS/Cure/Refresh/Enhancing/Stoneskin keep Malignance left too.
        left_ear="Malignance Earring",
        right_ear="Enchntr. Earring +1",
        left_ring="Naji's Loop",
        right_ring="Lebeche Ring",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    ------------------------------------------------------------------------
    -- PRECAST: WEAPON SKILL (BLM magic WS - INT/MAB/Magic Damage)
    -- main/sub omitted: weapons are never baked into gear sets here, so the WS
    -- fires with whatever weapon you're already holding (Lathi).
    ------------------------------------------------------------------------
    sets.precast.WS = {
        ammo="Oshasha's Treatise",
        head="Ea Hat +1",
        body="Mallquis Saio +2",
        hands="Jhakri Cuffs +2",
        legs="Mallquis Trews +2",
        feet="Mallquis Clogs +2",
        neck="Sibyl Scarf",
        waist="Latria Sash",
        left_ear="Malignance Earring",   -- pinned LEFT file-wide (see FC note)
        right_ear="Ishvara Earring",
        left_ring="Shiva Ring +1",
        right_ring="Mallquis Ring",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    ------------------------------------------------------------------------
    -- PRECAST: MYRKR  (MP-restore weaponskill -- maximize Max MP)
    -- Myrkr restores MP scaling with Max MP (per Brian; exact formula NOT verified
    -- against BGwiki this session -- spot-check whether TP also factors in). This set
    -- stacks Max MP instead of WS damage, and lives in precast so the Max-MP gear is
    -- on the instant the WS resolves.
    -- main/sub intentionally omitted: weapons are never baked into gear sets (a weapon
    -- swap zeroes TP and would cancel the weaponskill). Fire Myrkr with whatever staff
    -- you're already holding.
    ------------------------------------------------------------------------
    sets.precast.Myrkr = {
        ammo="Ombre Tathlum +1",
        head={name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        body={name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        hands="Arch. Gloves +3",
        legs={name="Amalric Slops +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        feet={name="Amalric Nails +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        neck="Orunmila's Torque",
        waist="Eschan Stone",
        left_ear="Sortiarius Earring",
        right_ear="Magnetic Earring",
        left_ring="Lebeche Ring",
        right_ring="Zodiac Ring",
        back="Tempered Cape +1",
    }

    ------------------------------------------------------------------------
    -- PRECAST: JOB ABILITIES
    -- Manafont: Arch. Coat +3 extends the JA's duration when worn at JA activation
    -- (bonus is snapshot at cast time). Body-only overlay; other slots stay as whatever
    -- was equipped, since Manafont is instant and aftercast returns to idle/engaged.
    ------------------------------------------------------------------------
    sets.precast.JA = {}
    sets.precast.JA.Manafont = {body="Arch. Coat +3"}

    ------------------------------------------------------------------------
    -- MIDCAST: MAGIC BURST  (toggle ON via Ctrl+`, or auto-armed by MagicAssistant)
    -- Your exported burst set. main/sub intentionally omitted: weapons are never
    -- baked into gear sets here (a weapon swap mid-midcast zeros TP and would
    -- otherwise stay equipped, since no other set re-specifies a weapon). If you
    -- want Lathi/Khonsu locked for nuking, that belongs in an explicit weapon toggle.
    ------------------------------------------------------------------------
    sets.midcast = {}
    sets.midcast.MagicBurst = {
        ammo="Ombre Tathlum +1",
        head="Ea Hat +1",
        body={name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        hands="Arch. Gloves +3",
        legs="Arch. Tonban +4",
        feet="Jhakri Pigaches +2",
        neck="Null Loop",
        waist="Eschan Stone",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8; Hecate's dropped per your call
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    ------------------------------------------------------------------------
    -- MIDCAST: MANA WALL  (also equips on Mana Wall JA precast for snapshot)
    -- Wicce Sabots +2 carry Mana Wall effect+; other slots stack DT-% (Nyame full body).
    -- Snapshotting on JA precast is what locks the sabots' effect into the shield calc.
    -- While the buff is active, apply_buff_locks() also overlays feet=Wicce Sabots +2 on
    -- any subsequent equip so the sabots stay through nukes/idle/etc.
    -- Right ear + right ring are placeholders; upgrade slots for DT/MDT pieces you own.
    ------------------------------------------------------------------------
    sets.midcast['Mana Wall'] = {
        ammo="Ombre Tathlum +1",
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Wicce Sabots +2",   -- LOCKED: Mana Wall effect+
        neck="Null Loop",
        waist="Null Belt",
        left_ear="Malignance Earring",
        right_ear="Magnetic Earring",   -- placeholder: swap in a DT/MDT earring if you own one
        left_ring="Defending Ring",
        right_ring="Shneddick Ring",    -- placeholder: swap in Shadow Ring / Vengeful Ring / etc. if owned
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }
    sets.precast.JA['Mana Wall'] = sets.midcast['Mana Wall']

    ------------------------------------------------------------------------
    -- MIDCAST: NUKE STANCES (two sets cycled by nuke_stance / Ctrl+`)
    --   FreeNuke: Spaekona's Coat +4 body (2% dmg->MP conversion; sustain default)
    --   Nuke:     Full Wicce +2 (Empyrean Conserve MP set proc; damage-focused)
    -- Both share the same accessory shell (ammo, ears, rings, waist, back) so the
    -- diff is just the body slot: Spae vs Wicce Coat.
    ------------------------------------------------------------------------
    -- FreeNuke: default sustain set. Wicce head/hands/legs/feet + Spae body.
    -- Updated from //gs export 2026-09-01. Design shift from prior version:
    --   feet Amalric Nails +1 -> Wicce Sabots +2 (loses Amalric MP/MAcc/MAB augments)
    --   neck Null Loop        -> Sibyl Scarf (trades MAcc+50/DT-5% for Magic Damage +6/Enmity-6)
    --   waist Null Belt       -> Acuity Belt +1
    --   left_ring Stikini +1  -> Shiva Ring +1 (Fire-specific bonus; dead slot for other elements)
    --   ammo Hydrocera        -> Ombre Tathlum +1
    --   back Null Shawl       -> Taranus's Cape
    sets.midcast.FreeNuke = {
        ammo="Ombre Tathlum +1",
        head="Wicce Petasos +2",
        body="Spae. Coat +4",
        hands="Wicce Gloves +2",
        legs="Wicce Chausses +2",
        feet="Wicce Sabots +2",
        neck="Sibyl Scarf",
        waist="Acuity Belt +1",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8 (Hoxne overlay inherits this)
        left_ring="Shiva Ring +1",
        right_ring="Stikini Ring +1",
        back={ name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%',}},
    }

    -- Nuke: full 5-piece Wicce +2 for the Empyrean set proc, plus CMP-stacked
    -- accessories. Standalone set (was set_combine on FreeNuke; diverged from a
    -- single body override to 5 slots on 2026-09-22, so it's cleaner explicit).
    -- Updated from //gs export 2026-09-22. Design shift vs FreeNuke:
    --   waist Acuity Belt +1  -> Shinjutsu-no-Obi +1 (CMP stack)
    --   left_ring Shiva Ring +1 -> Mephitas's Ring +1 (CMP stack)
    --   right_ring Stikini Ring +1 -> Metamor. Ring +1 (CMP stack)
    --   back Taranus's Cape (aug) -> Aurist's Cape +1 (loses INT+20/MDmg+10/
    --     MAcc+20 MDmg+20/FC+10/PDT-10% for CMP; per-cast damage cost paid by
    --     the CMP tier -- targeting ~85% CMP total per Brian, not verified here).
    -- Also used for Manafont/Manawell windows (MP cost is zero, so Spae's 2%
    -- return is dead; CMP is dead there too, but the raw MAB from Wicce still
    -- carries the set).
    -- main/sub intentionally omitted: weapons are never baked into gear sets
    -- (a weapon swap zeroes TP and would cancel a pending weaponskill).
    sets.midcast.Nuke = {
        ammo="Ombre Tathlum +1",
        head="Wicce Petasos +2",
        body="Wicce Coat +2",
        hands="Wicce Gloves +2",
        legs="Wicce Chausses +2",
        feet="Wicce Sabots +2",
        neck="Sibyl Scarf",
        waist="Shinjutsu-no-Obi +1",
        left_ear="Malignance Earring",   -- pinned LEFT file-wide (see FC note)
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8
        left_ring="Mephitas's Ring +1",
        right_ring="Metamor. Ring +1",
        back="Aurist's Cape +1",
    }

    ------------------------------------------------------------------------
    -- MIDCAST: NUKE + HOXNE RING (current nuke stance, Hoxne Ring in left ring)
    ------------------------------------------------------------------------
    -- TH/farming overlay: Hoxne Ring + Perfect Lucky Egg (TH+1 ammo).
    -- Trades nuke ammo/left-ring stats for Treasure Hunter; damage is secondary in this mode.
    -- Built at dispatch time (see midcast()) so it stacks on whatever nuke_stance is current.
    sets.midcast.HoxneOverlay = {ammo="Perfect Lucky Egg", left_ring="Hoxne Ring"}

    ------------------------------------------------------------------------
    -- MIDCAST: OCCULT ACUMEN (TP building via -ja / nuke MP cost)
    -- From //gs export 2026-08-04. main (Marin Staff +1) / sub (Khonsu)
    -- intentionally stripped: weapons are never baked into gear sets (weapon
    -- swap zeroes TP, which would defeat this set's entire purpose).
    -- OA on gear: Mall. Chapeau +2 (+11), Perdition Slops (+30), Merlinic
    -- Dastanas (+8) = +49, on top of the 50% BLM trait (tier II cap).
    ------------------------------------------------------------------------
    sets.midcast.OccultAcumen = {
        ammo="Seraphic Ampulla",
        head="Mall. Chapeau +2",
        body="Spae. Coat +4",
        hands={ name="Merlinic Dastanas", augments={'Mag. Acc.+21','"Occult Acumen"+8','"Mag.Atk.Bns."+7',}},
        legs="Perdition Slops",
        feet={ name="Merlinic Crackows", augments={'"Occult Acumen"+11','CHR+6','Mag. Acc.+12',}},
        neck="Null Loop",
        waist="Oneiros Rope",   -- OA+20 (was Null Belt Macc+30). Take TP on non-resist content; swap back to Null Belt if resists bite.
        left_ear="Dedition Earring",
        right_ear="Balder Earring",
        left_ring="Lehko's Ring",
        right_ring="Chirich Ring +1",   -- confirmed intentional, matches slot used in sets.engaged
        back="Null Shawl",
    }

    ------------------------------------------------------------------------
    -- MIDCAST: METEOR  (non-elemental; Elemental Magic skill uniquely boosts its damage)
    -- Full Arch. AF (legs/feet now +4) for the skill stacking. main/sub omitted per the no-weapons rule.
    ------------------------------------------------------------------------
    sets.midcast.Meteor = {
        ammo="Ombre Tathlum +1",
        head="Arch. Petasos +3",
        body="Arch. Coat +3",
        hands="Arch. Gloves +3",
        legs="Arch. Tonban +4",
        feet="Arch. Sabots +4",
        neck="Sibyl Scarf",
        waist="Latria Sash",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8
        left_ring="Resonance Ring",
        right_ring="Shiva Ring +1",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    ------------------------------------------------------------------------
    -- MIDCAST: DARK MAGIC (Drain / Aspir)
    ------------------------------------------------------------------------
    sets.midcast.Drain = {
        ammo="Ombre Tathlum +1",
        head={name="Merlinic Hood", augments={'Mag. Acc.+24 "Mag.Atk.Bns."+24','"Drain" and "Aspir" potency +4','CHR+7','Mag. Acc.+11','"Mag.Atk.Bns."+15'}},
        body={name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        hands={name="Merlinic Dastanas", augments={'Attack+16','"Fast Cast"+5','CHR+6'}},
        legs={name="Amalric Slops +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        feet={name="Amalric Nails +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        neck="Pixie Hairpin +1",
        waist="Skrymir Cord",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8 (DrainFreeNuke inherits)
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    -- Dark Magic with Free Nuke body swap (general dark branch: Comet, Death, Stun, etc.)
    sets.midcast.DrainFreeNuke = set_combine(sets.midcast.Drain, {body="Spae. Coat +4"})

    -- Drain / Aspir amount build (Pixie Hairpin +1, Archon / Evanescence rings). Used for all
    -- Drain and Aspir tiers; main/sub omitted per the no-weapons-in-sets rule.
    -- Updated from //gs export 2026-09-01.
    sets.midcast.DrainAspir = {
        ammo="Ombre Tathlum +1",
        head="Pixie Hairpin +1",
        body="Wicce Coat +2",
        hands="Arch. Gloves +3",
        legs="Spae. Tonban +3",
        feet="Arch. Sabots +4",
        neck="Hoxne Torque",
        waist="Acuity Belt +1",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8; NOTE: MAB does NOT boost Drain/Aspir absorb amount (unverified, BGwiki)
        left_ring="Archon Ring",
        right_ring="Evanescence Ring",
        back={ name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%',}},
    }

    ------------------------------------------------------------------------
    -- MIDCAST: ENFEEBLING MAGIC
    ------------------------------------------------------------------------
    sets.midcast['Enfeebling Magic'] = {
        -- main/sub (Lathi/Khonsu) intentionally omitted: weapons are never baked into gear sets
        -- (equipping a weapon mid-cast zeroes TP and can cancel a pending weaponskill). Enfeeble
        -- with whatever weapon you're already holding.
        ammo="Ombre Tathlum +1",
        head={name="Arch. Petasos +3", augments={'Increases Ancient Magic damage and magic burst damage'}},
        body={name="Arch. Coat +3", augments={'Enhances "Manafont" effect'}},
        hands={name="Arch. Gloves +3", augments={'Increases Elemental Magic accuracy'}},
        legs="Arch. Tonban +4",
        feet="Arch. Sabots +4",
        neck="Null Loop",
        waist="Null Belt",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear MAB+8 / Macc
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
    }

    ------------------------------------------------------------------------
    -- MIDCAST: ENHANCING MAGIC
    ------------------------------------------------------------------------
    sets.midcast['Enhancing Magic'] = {
        ammo="Ombre Tathlum +1",
        head={name="Arch. Petasos +3", augments={'Increases Ancient Magic damage and magic burst damage'}},
        body={name="Arch. Coat +3", augments={'Enhances "Manafont" effect'}},
        hands={name="Arch. Gloves +3", augments={'Increases Elemental Magic accuracy'}},
        legs="Arch. Tonban +4",
        feet="Arch. Sabots +4",
        neck="Sibyl Scarf",
        waist="Embla Sash",
        left_ear="Malignance Earring",   -- pinned LEFT file-wide (see FC note)
        right_ear="Sortiarius Earring",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    ------------------------------------------------------------------------
    -- MIDCAST: REFRESH (Enhancing Magic subtype)
    ------------------------------------------------------------------------
    sets.midcast.Refresh = {
        ammo="Ombre Tathlum +1",
        head={name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        body={name="Merlinic Jubbah", augments={'Mag. Acc.+25 "Mag.Atk.Bns."+25','"Fast Cast"+7','INT+7','Mag. Acc.+6','"Mag.Atk.Bns."+7'}},
        hands={name="Merlinic Dastanas", augments={'Attack+16','"Fast Cast"+5','CHR+6'}},
        legs={name="Merlinic Shalwar", augments={'Attack+20','"Fast Cast"+7','VIT+9','Mag. Acc.+8','"Mag.Atk.Bns."+6'}},
        feet={name="Merlinic Crackows", augments={'"Fast Cast"+6','VIT+8','Mag. Acc.+9','"Mag.Atk.Bns."+12'}},
        neck="Orunmila's Torque",
        waist="Gishdubar Sash",
        left_ear="Malignance Earring",   -- pinned LEFT file-wide (see FC note)
        right_ear="Sortiarius Earring",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Grapevine Cape",
    }

    ------------------------------------------------------------------------
    -- MIDCAST: CURE (Cure / Cura / Curaga families) - maximize cure potency
    -- main/sub omitted: weapons are never baked into gear sets here.
    ------------------------------------------------------------------------
    sets.midcast.Cure = {
        ammo="Hydrocera",
        head={name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        body={name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        hands={name="Amalric Gages +1", augments={'INT+12','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        legs="Arch. Tonban +4",
        feet={name="Amalric Nails +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        neck="Phalaina Locket",
        waist="Gishdubar Sash",
        left_ear="Malignance Earring",   -- pinned LEFT file-wide (see FC note)
        right_ear="Roundel Earring",
        left_ring="Naji's Loop",
        right_ring="Lebeche Ring",
        back="Tempered Cape +1",
    }

    ------------------------------------------------------------------------
    -- MIDCAST: STONESKIN / AQUAVEIL - dedicated set for these two spells only.
    -- main/sub omitted: weapons are never baked into gear sets here.
    ------------------------------------------------------------------------
    sets.midcast.Stoneskin = {
        ammo="Hydrocera",
        head={name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20'}},
        body="Mallquis Saio +2",
        hands="Mallquis Cuffs +2",
        legs="Shedir Seraweels",
        feet="Mallquis Clogs +2",
        neck="Nodens Gorget",
        waist="Embla Sash",
        left_ear="Malignance Earring",   -- pinned LEFT file-wide (see FC note)
        right_ear="Earthcry Earring",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
    }

    ------------------------------------------------------------------------
    -- MIDCAST: ELEMENTAL DEBUFF (Rasp, Choke, Shock, Burn, Drown, Frost)
    ------------------------------------------------------------------------
    sets.midcast.ElementalDebuff = {
        ammo="Ombre Tathlum +1",
        head={name="Arch. Petasos +3", augments={'Increases Ancient Magic damage and magic burst damage'}},
        body={name="Arch. Coat +3", augments={'Enhances "Manafont" effect'}},
        hands={name="Arch. Gloves +3", augments={'Increases Elemental Magic accuracy'}},
        legs="Arch. Tonban +4",
        feet="Arch. Sabots +4",
        left_ear="Malignance Earring",
        right_ear={ name="Wicce Earring +1", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+11','Enmity-1',}},   -- Wicce +1 right-ear Macc
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
    }

    ------------------------------------------------------------------------
    -- IDLE (default): DT-focused set. Wicce Coat +2 body + Nyame limbs, Defending Ring.
    -- main/sub (Marin Staff +1 / Khonsu) intentionally stripped from export per Rule 2.2.
    ------------------------------------------------------------------------
    -- Updated from //gs export 2026-09-01.
    --   hands Wicce Gloves +2 -> Nyame Gauntlets (small DT bump, loses Wicce refresh piece)
    --   waist Null Belt       -> Plat. Mog. Belt
    sets.idle = {
        ammo="Ombre Tathlum +1",
        head="Wicce Petasos +2",
        body="Wicce Coat +2",
        hands="Nyame Gauntlets",
        legs="Wicce Chausses +2",
        feet="Wicce Sabots +2",
        neck="Sibyl Scarf",
        waist="Plat. Mog. Belt",
        left_ear="Alabaster Earring",
        right_ear="Magnetic Earring",
        left_ring="Shneddick Ring",
        right_ring="Defending Ring",
        back="Null Shawl",
    }

    ------------------------------------------------------------------------
    -- IDLE: REFRESH  (auto-selected by get_idle_set() when not engaged AND MP < 50%)
    -- Jhakri Robe +2 body for extra refresh tick + INT. Uses Stikini rings for +refresh.
    -- Assiduity Pants +1 legs: +2 passive Refresh (not the spell -- the tick).
    -- Threshold dropped 2026-09-17 from 75% to 50% (see idle_refresh_mp_threshold).
    -- main/sub stripped from export per Rule 2.2.
    ------------------------------------------------------------------------
    sets.idle.Refresh = {
        ammo="Ombre Tathlum +1",
        head="Wicce Petasos +2",
        body="Jhakri Robe +2",
        hands="Wicce Gloves +2",
        legs="Assiduity Pants +1",   -- +2 passive Refresh
        feet="Wicce Sabots +2",
        neck="Sibyl Scarf",
        waist="Null Belt",
        left_ear="Alabaster Earring",
        right_ear="Magnetic Earring",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
    }

    ------------------------------------------------------------------------
    -- ENGAGED (taking physical hits)
    ------------------------------------------------------------------------
    sets.engaged = {
        ammo="Ombre Tathlum +1",
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Null Loop",
        waist="Cornelia's Belt",
        left_ear="Tripudio Earring",
        right_ear="Balder Earring",
        left_ring="Lehko's Ring",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
    }

    sets.resting = sets.idle

    windower.add_to_chat(122, 'Ashkev_BLM: Loaded (Raw GearSwap, no Mote-Include). Ctrl+` = Toggle Nuke Stance (FreeNuke/Nuke), Alt+` = Hoxne Ring Nuke, F9 = Occult Acumen TP mode. Magic Burst is MAA-driven.')

    send_command('bind ^` gs c cycle nuke')
    send_command('bind !` gs c toggle hoxne')
    send_command('bind f9 gs c toggle oa')
    send_command('input /macro book 1')

    -- Auto-apply lockstyle set 3 on load. Delayed a few seconds: lockstyle commands issued too
    -- soon after load/reload can be silently rejected by the client. Tune the wait if it misses.
    send_command('wait 5; input /lockstyleset 3')
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: return the idle set, overlaying Councilor's Garb body in Adoulin for +25% speed
-- Refresh idle takes over when NOT engaged AND MP is below the refresh threshold.
-- Engaged case always uses the DT idle (survival), regardless of MP.
----------------------------------------------------------------------------------------------------------------
idle_refresh_mp_threshold = 50   -- MP% below which the refresh idle set kicks in (idle only). Was 75; dropped 2026-09-17 to avoid hover-swap wonkiness when chain-casting -ja near threshold.

local function get_idle_set()
    local base
    if player.status ~= 'Engaged' and player.mpp < idle_refresh_mp_threshold then
        base = sets.idle.Refresh
    else
        base = sets.idle
    end
    if in_adoulin then
        return set_combine(base, {body="Councilor's Garb"})
    end
    return base
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: apply buff-driven slot locks as an overlay AFTER any set equip. Called at the
-- end of every event handler so the lock is the last write to win (single-pass equip resolution).
-- Mana Wall buff locks:
--   feet=Wicce Sabots +2 (Mana Wall effect+20% -- item stat, not augment)
--   back=Taranus's Cape  (Mana Wall+10% is a BASE stat on the BLM cape per Gorpa-Masorpa,
--                         inherent to any augment path; the FC/nuke augment on your cape
--                         does NOT displace the +10% bonus)
----------------------------------------------------------------------------------------------------------------
local function apply_buff_locks()
    if buffactive['Mana Wall'] then
        equip({
            feet="Wicce Sabots +2",
            back={name="Taranus's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','Magic Damage +10','"Fast Cast"+10','Phys. dmg. taken-10%'}},
        })
    end
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: equip the correct set for current player status
----------------------------------------------------------------------------------------------------------------
local function equip_current_set()
    if player.status == 'Engaged' then
        if player.hpp < hp_dt_threshold then
            equip(get_idle_set())   -- survival: idle is -DT maxed
        else
            equip(sets.engaged)
        end
    else
        equip(get_idle_set())
    end
    apply_buff_locks()
end

----------------------------------------------------------------------------------------------------------------
-- PRECAST
-- Weapon skills equip the WS set; magic spells equip the Fast Cast set.
----------------------------------------------------------------------------------------------------------------
function precast(spell, action)
    -- Myrkr: MP-restore WS. Must precede the generic WeaponSkill branch, which would
    -- otherwise grab the damage set. Equips the Max-MP set (see sets.precast.Myrkr).
    if spell.english == 'Myrkr' then
        equip(sets.precast.Myrkr)
        apply_buff_locks()
        return
    end
    if spell.type == 'WeaponSkill' then
        equip(sets.precast.WS)
        apply_buff_locks()
        return
    end
    -- Job Abilities: only the ones with dedicated snapshot gear are wired.
    -- Manafont: Arch. Coat +3 body extends duration.
    -- Mana Wall: full DT set with Wicce Sabots +2 snapshotted for the shield calc.
    if spell.type == 'JobAbility' then
        if sets.precast.JA[spell.english] then
            equip(sets.precast.JA[spell.english])
        end
        apply_buff_locks()
        return
    end
    if spell.action_type == 'Magic' then
        equip(sets.precast.FC)
        apply_buff_locks()
        return
    end
end

----------------------------------------------------------------------------------------------------------------
-- MIDCAST
-- Routes each spell type to its appropriate gear set.
----------------------------------------------------------------------------------------------------------------
function midcast(spell, action)

    -- 1) Refresh (check before general Enhancing Magic)
    if spell.english:startswith('Refresh') then
        equip(sets.midcast.Refresh)
        apply_buff_locks()
        return
    end

    -- 2) Cure family (Cure / Cura / Curaga). Healing Magic; won't collide with the
    --    skill-based branches below, but kept up top with the other name match.
    if spell.english:startswith('Cure') or spell.english:startswith('Cura') then
        equip(sets.midcast.Cure)
        apply_buff_locks()
        return
    end

    -- 3) Elemental Debuffs (Rasp, Choke, Shock, Burn, Drown, Frost)
    if elemental_debuffs[spell.english] then
        equip(sets.midcast.ElementalDebuff)
        apply_elemental_obi(spell)
        apply_buff_locks()
        return
    end

    -- Drain / Aspir (all tiers): dedicated amount build. Must precede general Dark Magic.
    if spell.english:startswith('Drain') or spell.english:startswith('Aspir') then
        equip(sets.midcast.DrainAspir)
        apply_buff_locks()
        return
    end

    -- 3) Dark Magic nukes & utility (Comet, Death, Stun, Bio, etc.)
    -- Priority order:
    --   1. MAA-armed burst window -> MagicBurst (Elemental Magic default set is a fine burst
    --      approximation for dark nukes; a dedicated dark burst set can slot in here later).
    --   2. Manafont / Manawell buff -> Nuke (full Wicce +2; MP cost is zero, Spae is dead stat).
    --   3. Otherwise -> DrainFreeNuke (Spae body variant for the general dark branch).
    -- Comet/Death still want their own nuke pieces; drop in a dedicated set here once built.
    if spell.skill == 'Dark Magic' then
        if os.clock() < burst_until then
            equip(sets.midcast.MagicBurst)
        elseif buffactive['Manafont'] or buffactive['Manawell'] then
            equip(sets.midcast.Nuke)
        else
            equip(sets.midcast.DrainFreeNuke)
        end
        apply_buff_locks()
        return
    end

    -- 4) Enfeebling Magic (Sleep, Slow, Paralyze, Blind, etc.)
    if spell.skill == 'Enfeebling Magic' then
        equip(sets.midcast['Enfeebling Magic'])
        apply_buff_locks()
        return
    end

    -- Stoneskin / Aquaveil: specific override, MUST come before general Enhancing Magic.
    if spell.english == 'Stoneskin' or spell.english == 'Aquaveil' then
        equip(sets.midcast.Stoneskin)
        apply_buff_locks()
        return
    end

    -- 5) Enhancing Magic (Protect, Shell, Blink, Spikes spells, etc.)
    if spell.skill == 'Enhancing Magic' then
        equip(sets.midcast['Enhancing Magic'])
        apply_buff_locks()
        return
    end

    -- Meteor: non-elemental, and the one nuke whose damage scales with Elemental Magic skill.
    -- Dedicated set, must precede the general Elemental Magic branch. No obi (non-elemental).
    if spell.english == 'Meteor' then
        equip(sets.midcast.Meteor)
        apply_buff_locks()
        return
    end

    -- 6) Elemental Magic (all nukes)
    -- Priority order (highest wins):
    --   1. MAA-armed burst window          -> MagicBurst (MAA is the only path; no manual toggle)
    --   2. Manafont / Manawell buff active -> Nuke (full Wicce +2; MP is free, damage-max)
    --   3. OA mode + TP under cutoff       -> OccultAcumen (TP building)
    --   4. Hoxne mode                      -> current nuke stance + Hoxne overlay (TH farming)
    --   5. Default                         -> nuke_stance (FreeNuke / Nuke)
    -- OA/Manafont interaction note: OA formula uses base MP cost (unverified whether it
    -- accounts for Manafont's zero-cost reduction). If it does, OA under Manafont would return
    -- zero TP anyway. Regardless, full Wicce is the higher-damage choice during that CD.
    if spell.skill == 'Elemental Magic' then
        if os.clock() < burst_until then
            equip(sets.midcast.MagicBurst)
            apply_elemental_obi(spell)
            apply_buff_locks()
            return
        end
        if buffactive['Manafont'] or buffactive['Manawell'] then
            equip(sets.midcast.Nuke)
            apply_elemental_obi(spell)
            apply_buff_locks()
            return
        end
        -- OA TP-building: takes precedence while toggled ON and TP is under the cutoff.
        -- No obi overlay here on purpose: while testing, the equipped set should match
        -- the export exactly (damage is secondary in TP-build mode).
        if oa_mode and player.tp < oa_tp_cutoff then
            equip(sets.midcast.OccultAcumen)
            apply_buff_locks()
            return
        end
        -- Pick the current stance; Hoxne mode overlays TH+1 ammo + Hoxne Ring on top.
        local stance_set = sets.midcast[nuke_stance] or sets.midcast.FreeNuke
        if hoxne_mode then
            equip(set_combine(stance_set, sets.midcast.HoxneOverlay))
        else
            equip(stance_set)
        end
        apply_elemental_obi(spell)
        apply_buff_locks()
        return
    end

end

----------------------------------------------------------------------------------------------------------------
-- SUBLIMATION AUTO-MANAGER  (/SCH sub only)
-- Charges when idle and neither Sublimation state is up (game silently rejects if on recast).
-- Auto-releases when MP drops below sublimation_release_mp% and 'Sublimation: Complete' is up.
--
-- UNVERIFIED: buff strings 'Sublimation: Activated' / 'Sublimation: Complete' are community
-- convention. Spot-check with `windower.ffxi.get_player().buffs` when Sublimation is charging /
-- ready, and adjust the string constants below if names differ. buffactive lookups in modern
-- GearSwap are generally case-insensitive but that's also worth confirming on your setup.
----------------------------------------------------------------------------------------------------------------
sublimation_release_mp = 30   -- MP% below which we auto-release a Complete Sublimation
local SUBLIMATION_CHARGING = 'Sublimation: Activated'
local SUBLIMATION_READY    = 'Sublimation: Complete'

local function sublimation_available()
    return player.sub_job == 'SCH'
end

local function try_release_sublimation()
    if sublimation_available()
       and player.mpp < sublimation_release_mp
       and buffactive[SUBLIMATION_READY] then
        send_command('input /ja "Sublimation" <me>')
    end
end

local function try_activate_sublimation()
    if sublimation_available()
       and not buffactive[SUBLIMATION_CHARGING]
       and not buffactive[SUBLIMATION_READY] then
        send_command('input /ja "Sublimation" <me>')
    end
end

----------------------------------------------------------------------------------------------------------------
-- AFTERCAST
----------------------------------------------------------------------------------------------------------------
function aftercast(spell, action)
    equip_current_set()
    try_release_sublimation()   -- MP just dropped; check if release is warranted
end

----------------------------------------------------------------------------------------------------------------
-- STATUS CHANGE (Idle <-> Engaged)
-- On the Engaged -> Idle transition, kick Sublimation charging if neither state is up.
----------------------------------------------------------------------------------------------------------------
function status_change(new_status, old_status)
    equip_current_set()
    if new_status == 'Idle' and old_status == 'Engaged' then
        try_activate_sublimation()
    end
end

----------------------------------------------------------------------------------------------------------------
-- BUFF CHANGE
-- Mana Wall: re-equip on gain/loss so apply_buff_locks() overlays / clears the feet lock
-- immediately, instead of waiting for the next event handler to fire.
----------------------------------------------------------------------------------------------------------------
function buff_change(buff, gain, details)
    if buff == 'Mana Wall' then
        equip_current_set()
    end
end

----------------------------------------------------------------------------------------------------------------
-- SELF COMMAND
-- Ctrl+` fires:        //gs c cycle nuke     (toggles FreeNuke <-> Nuke)
-- MagicAssistant fires: //gs c MAABurst <elements>  (auto-arms the burst window for the next nuke)
-- Magic Burst is MAA-driven only; there is no manual burst toggle. If MAA isn't running,
-- no burst set fires. This is intentional (see nuke_stance comment at top of file).
----------------------------------------------------------------------------------------------------------------
function self_command(command)
    if command == 'cycle nuke' then
        if nuke_stance == 'FreeNuke' then
            nuke_stance = 'Nuke'
        else
            nuke_stance = 'FreeNuke'
        end
        local labels = {FreeNuke='Free Nuke (Spae+4 body, MP sustain)',
                        Nuke    ='Nuke (full Wicce+2, damage)'}
        windower.add_to_chat(122, 'BLM: Nuke stance -> '..labels[nuke_stance])
        return
    end

    -- MagicAssistant burst signal: arms the Magic Burst set for the next few seconds so the
    -- imminent nuke swaps automatically. Overrides nuke_stance for the burst window.
    local elems = command:match('^MAABurst%s*(.*)')
    if elems then
        burst_until = os.clock() + burst_window_seconds
        windower.add_to_chat(122, 'BLM: Magic Burst armed by MagicAssistant'..(elems ~= '' and ' ['..elems..']' or ''))
        return
    end

    if command == 'toggle oa' then
        oa_mode = not oa_mode
        if oa_mode then
            windower.add_to_chat(122, 'BLM: Occult Acumen Mode ON (TP-build set for elemental casts under '..oa_tp_cutoff..' TP)')
        else
            windower.add_to_chat(122, 'BLM: Occult Acumen Mode OFF')
        end
        return
    end

    if command == 'toggle hoxne' then
        hoxne_mode = not hoxne_mode
        if hoxne_mode then
            windower.add_to_chat(122, 'BLM: Hoxne Ring Nuke Mode ON (Free Nuke set + Hoxne Ring)')
        else
            windower.add_to_chat(122, 'BLM: Hoxne Ring Nuke Mode OFF')
        end
        return
    end
end

----------------------------------------------------------------------------------------------------------------
-- HP WATCHER (survival)
-- Event-driven on action packets (NOT a frame poll, no coroutine accumulation). When the player
-- is targeted (i.e. takes damage), re-check HP so the <40% swap to the idle (-DT) set fires
-- promptly. Guarded by midaction() so it can never strip precast/midcast gear mid-spell; HP
-- recovery (e.g. after a Cure) is picked up on the next aftercast.
----------------------------------------------------------------------------------------------------------------
local function action_targets_me(act)
    if not act or not act.targets then return false end
    for _, t in ipairs(act.targets) do
        if t.id == player.id then return true end
    end
    return false
end

hp_watch_id = windower.register_event('action', function(act)
    if not act then return end
    if player.status ~= 'Engaged' then return end
    if midaction() then return end
    if action_targets_me(act) then
        equip_current_set()
    end
end)

----------------------------------------------------------------------------------------------------------------
-- ZONE CHANGE: equip Councilor's Garb as idle body in Western/Eastern Adoulin (+25% speed).
-- Clears automatically when zoning out of Adoulin.
--
-- Registered as a Windower 'zone change' event (NOT a bare named zone_change() function --
-- GearSwap has no zone_change hook, so a named function is inert and never fires). Matches the
-- name on world.zone, which holds the new zone after the change. Torn down in file_unload().
----------------------------------------------------------------------------------------------------------------
zone_watch_id = windower.register_event('zone change', function(new_id, old_id)
    in_adoulin = (world.zone == 'Western Adoulin' or world.zone == 'Eastern Adoulin')
    if in_adoulin then
        windower.add_to_chat(122, 'BLM: Adoulin zone detected -- Councilor\'s Garb equipped as idle body.')
    end
    equip_current_set()
end)

----------------------------------------------------------------------------------------------------------------
-- MP WATCHER (idle refresh threshold)
-- Only re-equips when player.mpp crosses idle_refresh_mp_threshold in either direction, and
-- only when not engaged and not mid-action. Debounced via last_idle_mp_low so we never re-equip
-- for MP changes that stay on the same side of the threshold (i.e. every Refresh tick).
----------------------------------------------------------------------------------------------------------------
last_idle_mp_low = false

mp_watch_id = windower.register_event('mp change', function(new_mp, old_mp)
    if player.status == 'Engaged' then return end
    if midaction() then return end
    local is_low = (player.mpp < idle_refresh_mp_threshold)
    if is_low ~= last_idle_mp_low then
        last_idle_mp_low = is_low
        equip_current_set()
    end
end)

----------------------------------------------------------------------------------------------------------------
-- FILE UNLOAD: clean up keybinds and event watchers on job change / //gs reload.
----------------------------------------------------------------------------------------------------------------
function file_unload()
    if hp_watch_id then windower.unregister_event(hp_watch_id) end
    if zone_watch_id then windower.unregister_event(zone_watch_id) end
    if mp_watch_id then windower.unregister_event(mp_watch_id) end
    send_command('unbind ^`')
    send_command('unbind !`')
    send_command('unbind f9')
end
