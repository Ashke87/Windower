----------------------------------------------------------------------------------------------------------------
-- Ashkev_DNC.lua  (Raw GearSwap - No Mote-Include)
-- Dancer GearSwap script using explicit precast/midcast/aftercast/status_change/buff_change functions.
-- No Mote-Include dependency. No background polling. No coroutine accumulation.
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------------------------------------------------
climactic_flourish_active = false

-- Damage Taken mode (Ctrl+`): manual toggle. When ON, the engaged set is replaced by
-- sets.engaged.DT (full defensive set) while engaged -- a panic button for dire moments.
-- When OFF, the normal (TP-maxed) engaged set is worn. Simple on/off flag, no TP cycling.
-- Takes priority over TH mode below -- if both are on, DT wins.
dt_mode = false

-- Treasure Hunter mode (Alt+`): manual toggle. When ON (and DT mode is OFF), sets.engaged.TH
-- (ammo + right_ring only) is overlaid on top of whichever engaged base is active -- normal
-- or Alt. Gear-only -- no weapon swap.
th_mode = false

-- Alt engaged mode (Ctrl+F9): manual toggle. When ON (and DT mode is OFF), the engaged base
-- becomes sets.engaged.Alt instead of the normal sets.engaged -- an alternate set for stacking
-- buffs differently. TH mode's ammo/ring overlay still applies on top if TH is also on.
-- DT mode overrides this entirely (see get_engaged_set()).
alt_mode = false

-- Auto-survival: at/below this HP%, drop to the idle set (Nyame/-DT) while engaged.
-- NOTE: as written this fires even when DT mode is ON, so idle overrides the DT set below
-- this HP%. Flagged in chat -- change to option B/C/D if you don't want that behavior.
hp_dt_threshold = 40

-- Adoulin speed body: equip Councilor's Garb as idle body in Western/Eastern Adoulin.
in_adoulin = false

----------------------------------------------------------------------------------------------------------------
-- GEAR SETS
----------------------------------------------------------------------------------------------------------------
function get_sets()

    -- Shared augmented mantle (WS-oriented: DEX+10 / WSD+10%) -- used on WS and dance sets
    local senuna_mantle = {
        name="Senuna's Mantle",
        augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Phys. dmg. taken-10%'}
    }

    -- TP-oriented mantle (Accuracy+10 / "Store TP"+10) -- used on the engaged set only
    local senuna_mantle_tp = {
        name="Senuna's Mantle",
        augments={'DEX+20','Accuracy+20 Attack+20','Accuracy+10','"Store TP"+10','Phys. dmg. taken-10%'}
    }

    ------------------------------------------------------------------------
    -- IDLE
    ------------------------------------------------------------------------
    sets.idle = {
        -- main/sub (Twashtar / Gleti's Knife) intentionally omitted — weapons never go in gear sets
        ammo="Aurgelmir Orb",
        head="Malignance Chapeau",
        body="Gleti's Cuirass",
        hands="Gleti's Gauntlets",
        legs="Gleti's Breeches",
        feet="Gleti's Boots",
        neck="Elite Royal Collar",
        waist="Null Belt",
        left_ear="Alabaster Earring",
        right_ear="Balder Earring",
        left_ring="Shneddick Ring",
        right_ring="Defending Ring",
        back="Null Shawl",
    }

    -- sets.idle.PDT = {}  -- not yet built; add when ready

    ------------------------------------------------------------------------
    -- ENGAGED
    -- Updated 2026-09-24 from //gs export: Coiste Bodhar, Sherida Earring, Null Shawl back.
    -- main/sub (Twashtar / Gleti's Knife) intentionally omitted — weapons never go in gear sets
    ------------------------------------------------------------------------
    sets.engaged = {
        ammo="Coiste Bodhar",
        head="Maculele Tiara +2",
        body="Malignance Tabard",
        hands="Maxixi Bangles +4",
        legs="Meg. Chausses +2",
        feet="Horos T. Shoes +3",
        neck={name="Etoile Gorget +1", augments={'Path: A'}},
        waist="Null Belt",
        left_ear="Sherida Earring",
        right_ear="Balder Earring",
        left_ring="Lehko's Ring",
        right_ring="Epona's Ring",
        back="Null Shawl",
    }

    -- sets.engaged.Acc = {}  -- not yet built; add when ready

    -- ALT ENGAGED TOGGLE SET (Ctrl+F9): buff-stacking alternate engaged base, swapped in via
    -- //gs c toggle alt. DT mode overrides this entirely; TH mode's ammo/ring overlay still
    -- applies on top if TH is also on (see get_engaged_set()).
    -- Updated 2026-09-24 from //gs export: Coiste Bodhar, Sherida Earring.
    -- main/sub (Twashtar / Fusetto +3 in the export) intentionally omitted -- weapons stay
    -- locked by default; say so explicitly if this set is meant to carry a weapon swap.
    sets.engaged.Alt = {
        ammo="Coiste Bodhar",
        head={name="Adhemar Bonnet +1", augments={'DEX+12','AGI+12','Accuracy+20'}},
        body="Horos Casaque +3",
        hands={name="Adhemar Wrist. +1", augments={'STR+12','DEX+12','Attack+20'}},
        legs="Meg. Chausses +2",
        feet="Horos T. Shoes +3",
        neck={name="Etoile Gorget +1", augments={'Path: A'}},
        waist="Sailfi Belt +1",
        left_ear="Sherida Earring",
        right_ear="Balder Earring",
        left_ring="Lehko's Ring",
        right_ring="Epona's Ring",
        back="Null Shawl",
    }

    -- DAMAGE TAKEN TOGGLE SET (Ctrl+`): full defensive set, swapped in via //gs c toggle dt.
    -- Manual panic button for dire moments. main/sub intentionally omitted -- weapons never in sets.
    sets.engaged.DT = {
        ammo="Aurgelmir Orb",
        head="Malignance Chapeau",
        body="Malignance Tabard",
        hands="Macu. Bangles +2",
        legs="Nyame Flanchard",
        feet="Macu. Toe Sh. +2",
        neck="Null Loop",
        waist="Null Belt",
        left_ear="Odr Earring",
        right_ear="Alabaster Earring",
        left_ring="Lehko's Ring",
        right_ring="Petrov Ring",
        back="Null Shawl",
    }

    -- TREASURE HUNTER OVERLAY (Alt+`): via //gs c toggle th, overlays just ammo + right_ring
    -- onto whichever engaged base is currently active (normal or Alt). Does NOT apply during
    -- DT mode -- DT takes full priority over both TH and Alt (see get_engaged_set()).
    sets.engaged.TH = {
        ammo="Per. Lucky Egg",
        right_ring="Hoxne Ring",
    }

    ------------------------------------------------------------------------
    -- PRECAST: JOB ABILITIES
    ------------------------------------------------------------------------
    sets.precast = {}
    sets.precast.JA = {}

    sets.precast.JA['Climactic Flourish'] = { head="Maculele Tiara +2" }
    -- Reverse Flourish: matched by name in precast() (not by type) to survive whatever
    -- spell.type GearSwap assigns to flourishes. Kept here as a named table for clarity.
    sets.precast.JA['Reverse Flourish'] = {
        hands="Macu. Bangles +2",
        back={name="Toetapper Mantle", augments={'"Store TP"+2','"Dual Wield"+1','"Rev. Flourish"+28'}},
    }
    -- No Foot Rise: handled in precast() -- single-slot overlay (body only)

    ------------------------------------------------------------------------
    -- PRECAST: FAST CAST
    -- DNC doesn't cast as a main job, but subjobs (e.g. /WHM, /RDM) and Trust
    -- summons do. This set is worn on any spell cast. main/sub intentionally
    -- omitted -- weapons are never touched by this script.
    ------------------------------------------------------------------------
    sets.precast.FC = {
        ammo="Impatiens",
        head={ name="Herculean Helm", augments={'Pet: Attack+19 Pet: Rng.Atk.+19','Attack+15','Accuracy+19 Attack+19','Mag. Acc.+19 "Mag.Atk.Bns."+19',}},
        body={ name="Herculean Vest", augments={'Mag. Acc.+21','"Fast Cast"+6','"Mag.Atk.Bns."+14',}},
        hands={ name="Herculean Gloves", augments={'"Fast Cast"+6','DEX+6','Mag. Acc.+6',}},
        legs={ name="Herculean Trousers", augments={'"Fast Cast"+5','INT+4','Mag. Acc.+7',}},
        feet={ name="Herculean Boots", augments={'"Mag.Atk.Bns."+15','"Fast Cast"+5','INT+1',}},
        neck="Orunmila's Torque",
        waist="Null Belt",
        left_ear="Enchntr. Earring +1",
        right_ear="Moonshade Earring",
        left_ring="Naji's Loop",
        right_ring="Lebeche Ring",
        back={ name="Senuna's Mantle", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Phys. dmg. taken-10%',}},
    }

    ------------------------------------------------------------------------
    -- PRECAST: SAMBA (overlay-only -- only Samba-enhancing pieces; other slots
    -- retained from whatever set is currently worn)
    ------------------------------------------------------------------------
    sets.precast.Samba = {
        head="Maxixi Tiara +2",
        back=senuna_mantle_tp,
    }

    ------------------------------------------------------------------------
    -- PRECAST: JIG (overlay-only -- only Jig-enhancing pieces; other slots
    -- retained from whatever set is currently worn)
    ------------------------------------------------------------------------
    sets.precast.Jig = {
        legs="Horos Tights +4",
        feet="Maxixi Toe Shoes +3",
    }

    ------------------------------------------------------------------------
    -- PRECAST: WALTZ (overlay -- only Waltz-relevant slots; unlisted slots
    -- retained from whatever set is currently worn)
    ------------------------------------------------------------------------
    sets.precast.Waltz = {
        head="Mummu Bonnet +2",
        body="Maxixi Casaque +3",
        hands="Mummu Wrists +2",
        legs="Mummu Kecks +2",
        feet="Maxixi Toe Shoes +3",
        neck={name="Etoile Gorget +1", augments={'Path: A'}},
        left_ear="Sjofn Earring",
        right_ear="Roundel Earring",
        back={name="Toetapper Mantle", augments={'"Store TP"+2','"Dual Wield"+1','"Rev. Flourish"+28'}},
    }

    ------------------------------------------------------------------------
    -- PRECAST: STEPS (full set) -- main/sub intentionally omitted
    ------------------------------------------------------------------------
    sets.precast.Step = {
        ammo="Oshasha's Treatise",
        head="Maxixi Tiara +2",
        body="Maxixi Casaque +3",
        hands="Maxixi Bangles +4",
        legs="Meg. Chausses +2",
        feet="Horos T. Shoes +3",
        neck={name="Etoile Gorget +1", augments={'Path: A'}},
        waist="Null Belt",
        left_ear="Odr Earring",
        right_ear={name="Maculele Earring", augments={'System: 1 ID: 1676 Val: 0','Accuracy+10','Mag. Acc.+10'}},
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back=senuna_mantle_tp,
    }

    -- Feather Step: same as the Step set, but Maculele Toe Shoes +2 on feet (boosts Feather Step)
    sets.precast.FeatherStep = set_combine(sets.precast.Step, {feet="Maculele Toe Shoes +2"})

    ------------------------------------------------------------------------
    -- PRECAST: VIOLENT FLOURISH (full set) -- main/sub intentionally omitted
    ------------------------------------------------------------------------
    sets.precast.ViolentFlourish = {
        ammo="Oshasha's Treatise",
        head="Maculele Tiara +2",
        body="Horos Casaque +3",
        hands="Macu. Bangles +2",
        legs="Horos Tights +4",
        feet="Macu. Toe Sh. +2",
        neck="Null Loop",
        waist="Null Belt",
        left_ear="Enchntr. Earring +1",
        right_ear={name="Maculele Earring", augments={'System: 1 ID: 1676 Val: 0','Accuracy+10','Mag. Acc.+10'}},
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
    }

    ------------------------------------------------------------------------
    -- PRECAST: WEAPON SKILLS
    ------------------------------------------------------------------------
    sets.precast.WS = {}

    -- Default / Rudra's Storm
    sets.precast.WS.Default = {
        -- main/sub (Twashtar / Gleti's Knife) intentionally omitted — weapons never go in gear sets
        ammo="Oshasha's Treatise",
        head="Maculele Tiara +2",
        body="Malignance Tabard",
        hands="Maxixi Bangles +4",
        legs="Horos Tights +4",
        feet="Malignance Boots",
        neck={ name="Etoile Gorget +1", augments={'Path: A'}},
        waist="Gerdr Belt",
        left_ear="Moonshade Earring",
        right_ear={ name="Maculele Earring", augments={'System: 1 ID: 1676 Val: 0','Accuracy+10','Mag. Acc.+10'}},
        left_ring="Lehko's Ring",
        right_ring="Epaminondas's Ring",
        back=senuna_mantle,
    }

    sets.precast.WS["Rudra's Storm"] = sets.precast.WS.Default

    -- Evisceration
    sets.precast.WS["Evisceration"] = {
        ammo="Aurgelmir Orb",
        head={name="Adhemar Bonnet +1", augments={'DEX+12','AGI+12','Accuracy+20'}},
        body="Meg. Cuirie +2",
        hands="Mummu Wrists +2",
        legs="Gleti's Breeches",
        feet="Mummu Gamash. +2",
        neck={name="Etoile Gorget +1", augments={'Path: A'}},
        waist="Gerdr Belt",
        left_ear="Moonshade Earring",
        right_ear={name="Maculele Earring", augments={'System: 1 ID: 1676 Val: 0','Accuracy+10','Mag. Acc.+10'}},
        left_ring="Lehko's Ring",
        right_ring="Mummu Ring",
        back=senuna_mantle,
    }

    -- Aeolian Edge
    sets.precast.WS["Aeolian Edge"] = {
        ammo="Ombre Tathlum +1",
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Etoile Gorget +1",
        waist="Eschan Stone",
        left_ear="Sortiarius Earring",
        right_ear="Moonshade Earring",
        left_ring="Chirich Ring +1",
        right_ring="Hetairoi Ring",
        back=senuna_mantle,
    }

    windower.add_to_chat(122, 'Ashkev_DNC: Loaded (Raw GearSwap, no Mote-Include).')

    send_command('bind ^` gs c toggle dt')
    send_command('bind !` gs c toggle th')
    send_command('bind ^f9 gs c toggle alt')
    send_command('input /macro book 6')
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: return current idle set, applying Climactic Flourish head lock if active,
-- and Councilor's Garb body in Adoulin for +25% speed
----------------------------------------------------------------------------------------------------------------
local function get_idle_set()
    local base = sets.idle
    if in_adoulin then
        base = set_combine(base, {body="Councilor's Garb"})
    end
    if climactic_flourish_active then
        return set_combine(base, {head="Maculele Tiara +2"})
    end
    return base
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: return current engaged set. Priority: DT mode (full override) > Alt/normal base,
-- with TH mode's ammo/ring overlaid on top of that base if active. Climactic Flourish head
-- lock applies last, on top of everything.
----------------------------------------------------------------------------------------------------------------
local function get_engaged_set()
    local base
    if dt_mode then
        base = sets.engaged.DT
    else
        base = alt_mode and sets.engaged.Alt or sets.engaged
        if th_mode then
            base = set_combine(base, sets.engaged.TH)
        end
    end
    if climactic_flourish_active then
        return set_combine(base, {head="Maculele Tiara +2"})
    end
    return base
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: equip the correct set for current player status
----------------------------------------------------------------------------------------------------------------
local function equip_current_set()
    if player.status == 'Engaged' then
        if player.hpp < hp_dt_threshold then
            equip(get_idle_set())       -- survival: idle is -DT maxed (Climactic head lock preserved)
        else
            equip(get_engaged_set())
        end
    else
        equip(get_idle_set())
    end
end

----------------------------------------------------------------------------------------------------------------
-- PRECAST
----------------------------------------------------------------------------------------------------------------
function precast(spell, action)

    -- Spell casts: Trust summons and any subjob magic (e.g. /WHM, /RDM) get the
    -- Fast Cast set. spell.action_type == 'Magic' covers all spell categories
    -- (Trust, White/Black/Blue/etc.) in one branch, and is checked first so it
    -- can never collide with the Samba/Jig/Waltz name matches below.
    if spell.action_type == 'Magic' then
        equip(sets.precast.FC)
        return
    end

    -- Flourishes matched by name BEFORE type branches -- GearSwap may assign flourishes
    -- a type other than 'JobAbility' (e.g. 'Flourish1', 'Flourish2'), so name-matching
    -- is the only reliable way to catch them. Violent and Reverse Flourish both go here;
    -- Climactic Flourish falls through to the JA branch below (head swap only, safe either way).
    if spell.english == 'Violent Flourish' then
        equip(sets.precast.ViolentFlourish)
        return
    end

    if spell.english == 'Reverse Flourish' then
        -- Overlay: only hands + back swap; everything else stays as-worn.
        equip(sets.precast.JA['Reverse Flourish'])
        return
    end

    -- Job Abilities
    if spell.type == 'JobAbility' then
        if spell.english == 'No Foot Rise' then
            -- Single-slot overlay: only the body swaps in. Aftercast restores the full set.
            -- DT mode / Climactic head lock are unaffected -- not touching those slots.
            equip({body="Horos Casaque +3"})
        elseif sets.precast.JA[spell.english] then
            equip(sets.precast.JA[spell.english])
        end
        return
    end

    -- Weapon Skills
    if spell.type == 'WeaponSkill' then
        equip(sets.precast.WS[spell.english] or sets.precast.WS.Default)
        return
    end

    -- Samba (spell type is 'Ability' with 'Samba' in name)
    if spell.english:find('Samba') then
        equip(sets.precast.Samba)
        return
    end

    -- Jig
    if spell.english:find('Jig') then
        equip(sets.precast.Jig)
        return
    end

    -- Waltz
    if spell.english:find('Waltz') then
        equip(sets.precast.Waltz)
        return
    end

    -- Steps
    if spell.type == 'Step' then
        if spell.english == 'Feather Step' then
            equip(sets.precast.FeatherStep)
        else
            equip(sets.precast.Step)
        end
        return
    end

end

----------------------------------------------------------------------------------------------------------------
-- MIDCAST
-- DNC has no meaningful midcast gear swaps — all timing is handled at precast.
-- Midcast fires fast enough that the server already sees precast gear for JAs.
----------------------------------------------------------------------------------------------------------------
function midcast(spell, action)
    -- Nothing needed for DNC
end

----------------------------------------------------------------------------------------------------------------
-- AFTERCAST
----------------------------------------------------------------------------------------------------------------
function aftercast(spell, action)
    equip_current_set()
end

----------------------------------------------------------------------------------------------------------------
-- STATUS CHANGE (Idle <-> Engaged)
----------------------------------------------------------------------------------------------------------------
function status_change(new_status, old_status)
    equip_current_set()
end

----------------------------------------------------------------------------------------------------------------
-- BUFF CHANGE
-- Tracks Climactic Flourish buff to lock Maculele Tiara +2 while active.
----------------------------------------------------------------------------------------------------------------
function buff_change(buff, gain, details)
    if buff == 'Climactic Flourish' then
        climactic_flourish_active = gain
        equip_current_set()
    end
end

----------------------------------------------------------------------------------------------------------------
-- SELF COMMAND
-- //gs c toggle dt  →  toggles Damage Taken mode on/off (bound to Ctrl+`)
-- //gs c toggle th  →  toggles TH ammo/ring overlay on/off (bound to Alt+`, DT overrides)
-- //gs c toggle alt →  toggles Alt engaged base on/off (bound to Ctrl+F9, DT overrides, TH still overlays)
----------------------------------------------------------------------------------------------------------------
function self_command(command)
    if command == 'toggle dt' then
        dt_mode = not dt_mode
        windower.add_to_chat(122, 'DNC Damage Taken mode: '..(dt_mode and 'ON (defensive set)' or 'OFF (normal engaged)'))
        equip_current_set()
    elseif command == 'toggle th' then
        th_mode = not th_mode
        windower.add_to_chat(122, 'DNC Treasure Hunter overlay: '..(th_mode and 'ON (Lucky Egg / Hoxne Ring)' or 'OFF'))
        equip_current_set()
    elseif command == 'toggle alt' then
        alt_mode = not alt_mode
        windower.add_to_chat(122, 'DNC Alt engaged set: '..(alt_mode and 'ON' or 'OFF (normal engaged)'))
        equip_current_set()
    end
end

----------------------------------------------------------------------------------------------------------------
-- ACTION WATCHER (HP auto-survival)
-- Event-driven on action packets (NOT a frame poll, so no coroutine accumulation), unregistered
-- in file_unload. When the player is targeted (takes damage), re-check HP so the
-- <hp_dt_threshold% swap to the idle (-DT) set fires promptly. The old per-swing re-equip
-- (TP-cycle) is gone -- the engaged set is now the TP set, and Damage Taken mode is manual.
-- Guarded by midaction(): never re-equips mid-WS/step/waltz, so it can't strip precast gear.
----------------------------------------------------------------------------------------------------------------
local function action_targets_me(act)
    if not act or not act.targets then return false end
    for _, t in ipairs(act.targets) do
        if t.id == player.id then return true end
    end
    return false
end

action_watch_id = windower.register_event('action', function(act)
    if not act then return end
    if player.status ~= 'Engaged' then return end
    if midaction() then return end
    if action_targets_me(act) then
        equip_current_set()
    end
end)

----------------------------------------------------------------------------------------------------------------
-- ZONE WATCHER: equip Councilor's Garb as idle body in Western/Eastern Adoulin (+25% speed).
-- Uses windower.register_event('zone change') -- GearSwap does not expose a zone_change callback.
----------------------------------------------------------------------------------------------------------------
zone_watch_id = windower.register_event('zone change', function(new_zone_id)
    local zone_name = world.zone
    in_adoulin = (zone_name == 'Western Adoulin' or zone_name == 'Eastern Adoulin')
    if in_adoulin then
        windower.add_to_chat(122, 'DNC: Adoulin zone detected -- Councilor\'s Garb equipped as idle body.')
    end
    equip_current_set()
end)

----------------------------------------------------------------------------------------------------------------
-- FILE UNLOAD: clean up the keybind and event handler on job change / //gs reload.
----------------------------------------------------------------------------------------------------------------
function file_unload()
    if action_watch_id then windower.unregister_event(action_watch_id) end
    if zone_watch_id then windower.unregister_event(zone_watch_id) end
    send_command('unbind ^`')
    send_command('unbind !`')
    send_command('unbind ^f9')
end
