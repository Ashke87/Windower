----------------------------------------------------------------------------------------------------------------
-- Ashkev_THF.lua  (Raw GearSwap - No Mote-Include)
-- Thief GearSwap script using explicit precast/midcast/aftercast/status_change/buff_change functions.
-- No Mote-Include dependency. No background polling. No coroutine accumulation.
--
-- Converted 2026-06-16 from the Mote-Include version. Updated 2026-08-03.
--   * Treasure Hunter via gear only (no weapon swap). TH overlay applies ONLY while engaged
--     (idle is never overlaid -- TH can't be applied outside combat).
--   * TH overlay is a 3-slot partial set: ammo / hands / right_ring. Everything else is
--     inherited from whatever base set is underneath.
--   * TH ALSO overlays the three elemental dagger WS (Aeolian Edge, Gust Slash, Cyclone),
--     where TH slots take priority over the WS slots. It does NOT apply to Rudra's Storm,
--     Savage Blade, or any other weapon skill.
--   * Damage Taken mode: Ctrl+` toggle, OR automatic at/below hp_dt_threshold HP% while engaged.
--   * Weapons (main/sub) are NEVER touched by this script -- equipping a weapon zeroes TP.
--     Equip your weapon manually before building TP / weaponskilling.
--
-- KEYBINDS (polarity matches Ashkev_DNC.lua -- Ctrl = defense, Alt = Treasure Hunter):
--   Ctrl+`  ->  //gs c toggle dt   (Damage Taken mode)
--   Alt+`   ->  //gs c toggle th   (Treasure Hunter overlay)
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------------------------------------------------
treasure_mode = false  -- toggle with Alt+` (//gs c toggle th) -- 3-slot overlay on the engaged set

-- Damage Taken mode. Two INDEPENDENT sources, either one activates it:
--   dt_manual        -- deliberate toggle via Ctrl+` (//gs c toggle dt)
--   player.hpp < hp_dt_threshold  -- automatic survival trigger
-- Kept separate so HP recovering back above the threshold does NOT cancel a DT state you
-- turned on deliberately. Only the Ctrl+` toggle clears dt_manual.
dt_manual = false
hp_dt_threshold = 35

-- Weapon skills that receive the Treasure Hunter overlay when treasure_mode is on.
-- Plain table (not S{...}) to avoid depending on Windower's sets library being loaded.
th_weaponskills = {
    ['Aeolian Edge'] = true,
    ['Gust Slash']   = true,
    ['Cyclone']      = true,
}

-- Adoulin speed body: equip Councilor's Garb as idle body in Western/Eastern Adoulin.
in_adoulin = false

----------------------------------------------------------------------------------------------------------------
-- GEAR SETS
----------------------------------------------------------------------------------------------------------------
function get_sets()

    ------------------------------------------------------------------------
    -- IDLE
    ------------------------------------------------------------------------
    -- main="Twashtar" / sub="Gleti's Knife" intentionally omitted from the export --
    -- weapons are never equipped by this script.
    sets.idle = {
        ammo="Aurgelmir Orb",
        head="Malignance Chapeau",
        body="Gleti's Cuirass",
        hands="Gleti's Gauntlets",
        legs="Gleti's Breeches",
        feet="Gleti's Boots",
        neck="Elite Royal Collar",
        waist="Plat. Mog. Belt",
        left_ear="Alabaster Earring",
        right_ear={ name="Skulk. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Accuracy+14','Mag. Acc.+14','"Store TP"+5',}},
        left_ring="Shneddick Ring",
        right_ring="Defending Ring",
        back={ name="Toutatis's Cape", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Damage taken-5%',},},
    }

    ------------------------------------------------------------------------
    -- ENGAGED
    -- main/sub intentionally omitted -- weapons never changed by this script.
    ------------------------------------------------------------------------
    sets.engaged = {
        ammo="Coiste Bodhar",
        head="Skulker's Bonnet +2",
        body="Pill. Vest +4",
        hands="Gleti's Gauntlets",
        legs="Pill. Culottes +4",
        feet="Plun. Poulaines +4",
        neck="Null Loop",
        waist="Windbuffet Belt +1",
        left_ear="Odr Earring",
        right_ear={ name="Skulk. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Accuracy+14','Mag. Acc.+14','"Store TP"+5',}},
        left_ring="Lehko's Ring",
        right_ring="Epona's Ring",
        back="Null Shawl",
    }

    ------------------------------------------------------------------------
    -- TREASURE HUNTER OVERLAY  (PARTIAL SET -- 3 slots only)
    -- Deliberately trimmed to just the TH-bearing pieces. Every slot NOT listed here is
    -- inherited from the set underneath (engaged, or an elemental WS set). Do NOT "complete"
    -- this set by filling in the other slots -- minimal gear swapping is the point.
    --
    -- Applied to: the engaged set (see get_engaged_set), and Aeolian Edge / Gust Slash /
    -- Cyclone precast (see th_weaponskills + precast). NOT applied to idle, and NOT applied
    -- while Damage Taken mode is active.
    --
    -- NOTE: the ammo slot displaces Coiste Bodhar (Store TP) while TH is on, and displaces
    -- Seething Bomblet on the elemental WS. Intended tradeoff, not an oversight.
    -- main/sub intentionally omitted -- weapons never changed by this script.
    ------------------------------------------------------------------------
    sets.TreasureSet = {
        ammo="Per. Lucky Egg",
        hands="Plun. Armlets +2",
        right_ring="Hoxne Ring",
    }

    ------------------------------------------------------------------------
    -- DAMAGE TAKEN
    -- Full replacement set (not an overlay). Activated by the Ctrl+` toggle, or automatically
    -- while engaged at/below hp_dt_threshold HP%. See dt_active() and equip_current_set().
    -- main/sub intentionally omitted -- weapons never changed by this script.
    ------------------------------------------------------------------------
    sets.DT = {
        ammo="Coiste Bodhar",
        head="Malignance Chapeau",
        body="Malignance Tabard",
        hands={ name="Adhemar Wrist. +1", augments={'STR+12','DEX+12','Attack+20',}},
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Elite Royal Collar",
        waist="Null Belt",
        left_ear="Odr Earring",
        right_ear={ name="Skulk. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Accuracy+14','Mag. Acc.+14','"Store TP"+5',}},
        left_ring="Lehko's Ring",
        right_ring="Defending Ring",
        back={ name="Toutatis's Cape", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Damage taken-5%',},},
    }

    ------------------------------------------------------------------------
    -- PRECAST: JOB ABILITIES
    ------------------------------------------------------------------------
    sets.precast = {}
    sets.precast.JA = {}

    -- Flee: single slot. equip() only touches the slots named in the table, so this
    -- overlays whatever is currently worn instead of swapping a full set.
    sets.precast.JA['Flee'] = { feet="Pillager's Poulaines" }

    ------------------------------------------------------------------------
    -- PRECAST: CURING WALTZ  (PARTIAL SET -- 2 slots only)
    -- Requires /DNC. Applied to every Curing Waltz tier (GearSwap reports these as
    -- spell.type == 'Waltz'). Like Flee, this is a 2-slot overlay on the current gear,
    -- not a full set -- do not fill in the remaining slots.
    ------------------------------------------------------------------------
    sets.precast.Waltz = {
        head="Mummu Bonnet +2",
        body="Gleti's Cuirass",
    }

    ------------------------------------------------------------------------
    -- PRECAST: FAST CAST
    -- THF doesn't cast as a main job, but subjobs (e.g. /WHM, /RDM) and Trust
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
        back={ name="Toutatis's Cape", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Damage taken-5%',},},
    }

    ------------------------------------------------------------------------
    -- PRECAST: WEAPON SKILLS
    -- sets.precast.WS is the generic/default WS set; named WS sets hang off it.
    -- A WS with no named set falls back to this generic set.
    --
    -- RUDRA'S STORM deliberately has NO named set -- it uses this generic set, which IS
    -- the Rudra set. Do not add sets.precast.WS["Rudra's Storm"] = sets.precast.WS; that
    -- would make the table reference itself.
    --
    -- The Treasure Hunter overlay is NEVER applied here. TH is restricted to the three
    -- elemental dagger WS listed in th_weaponskills at the top of this file.
    ------------------------------------------------------------------------
    sets.precast.WS = {
        ammo="Aurgelmir Orb",
        head="Skulker's Bonnet +2",
        body="Skulker's Vest +2",
        hands="Meg. Gloves +2",
        legs="Plun. Culottes +2",
        feet="Plun. Poulaines +4",
        neck="Null Loop",
        waist="Kentarch Belt +1",
        left_ear="Odr Earring",
        right_ear="Moonshade Earring",
        left_ring="Lehko's Ring",
        right_ring="Epaminondas's Ring",
        back={ name="Toutatis's Cape", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Damage taken-5%',},},
    }

    ------------------------------------------------------------------------
    -- Savage Blade
    -- main/sub (Naegling / Fusetto +2) intentionally omitted -- the sword
    -- must already be equipped before you WS; swapping it here would zero TP.
    ------------------------------------------------------------------------
    sets.precast.WS['Savage Blade'] = {
        ammo="Oshasha's Treatise",
        head="Meghanada Visor +2",
        body="Meg. Cuirie +2",
        hands="Meg. Gloves +2",
        legs="Meg. Chausses +2",
        feet="Meg. Jam. +2",
        neck="Rep. Plat. Medal",
        waist="Null Belt",
        left_ear="Odr Earring",
        right_ear="Ishvara Earring",
        left_ring="Lehko's Ring",
        right_ring="Epaminondas's Ring",
        back={ name="Toutatis's Cape", augments={'DEX+20','Accuracy+20 Attack+20','DEX+10','Weapon skill damage +10%','Damage taken-5%',},},
    }

    ------------------------------------------------------------------------
    -- Elemental dagger WS: Aeolian Edge / Gust Slash / Cyclone.
    -- These three (and ONLY these three) receive the Treasure Hunter overlay when
    -- treasure_mode is on -- see th_weaponskills and the WeaponSkill branch of precast().
    -- When that happens the TH slots WIN, so Seething Bomblet gives way to Per. Lucky Egg.
    ------------------------------------------------------------------------
    sets.precast.WS['Aeolian Edge'] = {
        ammo="Seething Bomblet",
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Meg. Gloves +2",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Sibyl Scarf",
        waist="Skrymir Cord",
        left_ear="Hecate's Earring",
        right_ear={ name="Skulk. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Accuracy+14','Mag. Acc.+14','"Store TP"+5',}},
        left_ring="Shiva Ring +1",
        right_ring="Epaminondas's Ring",
        back="Null Shawl",
    }
    sets.precast.WS['Cyclone']    = sets.precast.WS['Aeolian Edge']
    sets.precast.WS['Gust Slash'] = sets.precast.WS['Aeolian Edge']

    ------------------------------------------------------------------------
    -- LOAD MESSAGE + KEYBIND
    -- No macro book is set (the Mote version did not set one). Tell me the
    -- THF macro book number and I'll add: send_command('input /macro book N')
    ------------------------------------------------------------------------
    windower.add_to_chat(122, 'Ashkev_THF: Loaded (Raw GearSwap, no Mote-Include). Ctrl+` = Damage Taken, Alt+` = Treasure Hunter.')

    -- Polarity matches Ashkev_DNC.lua: Ctrl = defense, Alt = Treasure Hunter.
    send_command('bind ^` gs c toggle dt')
    send_command('bind !` gs c toggle th')
    send_command('input /macro book 8')

    -- Auto-apply lockstyle set 1 on load. Delayed a few seconds: lockstyle commands issued
    -- too soon after load/reload can be silently rejected by the client. Tune the wait if it misses.
    send_command('wait 5; input /lockstyleset 1')
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: return current engaged set, applying the TH overlay if TH mode is on
----------------------------------------------------------------------------------------------------------------
local function get_engaged_set()
    if treasure_mode then
        return set_combine(sets.engaged, sets.TreasureSet)
    end
    return sets.engaged
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: return idle set, overlaying Councilor's Garb body in Adoulin for +25% speed
----------------------------------------------------------------------------------------------------------------
local function get_idle_set()
    if in_adoulin then
        return set_combine(sets.idle, {body="Councilor's Garb"})
    end
    return sets.idle
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: is Damage Taken mode currently in effect?
-- True if EITHER the manual toggle is on OR HP has dropped to/below the threshold.
-- Because these are ORed rather than sharing one variable, HP climbing back above the
-- threshold does not cancel a manually-toggled DT state.
----------------------------------------------------------------------------------------------------------------
local function dt_active()
    return dt_manual or player.hpp <= hp_dt_threshold
end

----------------------------------------------------------------------------------------------------------------
-- UTILITY: equip the correct set for current player status
--   Engaged + DT active  -> sets.DT (TH overlay suppressed entirely)
--   Engaged              -> engaged set, +TH overlay if treasure_mode
--   Not engaged          -> idle set (+Councilor's Garb in Adoulin). DT and TH never apply
--                           here: TH can't be applied out of combat, and the idle set already
--                           carries Defending Ring + Shneddick Ring for escaping.
--
-- >>> DT-vs-TH DECISION POINT <<<
-- Right now DT wins completely -- no Treasure Hunter at all while DT is active, because
-- Hoxne Ring and Defending Ring both want right_ring. To instead keep TH in the two
-- non-conflicting slots (ammo + hands) while Defending Ring holds the right ring, replace
--     equip(sets.DT)
-- on the engaged branch below with
--     equip(set_combine(set_combine(sets.DT, sets.TreasureSet), {right_ring="Defending Ring"}))
-- and guard it with `if treasure_mode then ... else equip(sets.DT) end`.
----------------------------------------------------------------------------------------------------------------
local function equip_current_set()
    if player.status == 'Engaged' then
        if dt_active() then
            equip(sets.DT)                  -- survival wins; TH overlay suppressed
        else
            equip(get_engaged_set())        -- applies TH overlay if treasure_mode is on
        end
    else
        equip(get_idle_set())
    end
end

----------------------------------------------------------------------------------------------------------------
-- PRECAST
-- Weapon Skills and Job Abilities only. Weapons are never equipped here.
----------------------------------------------------------------------------------------------------------------
function precast(spell, action)

    -- Weapon Skills
    -- Named set if one exists, otherwise the generic set (which is also the Rudra's Storm set).
    -- Treasure Hunter overlays ONLY the three elemental dagger WS, and only when TH mode is on.
    -- TH slots take priority over the WS slots by being the second argument to set_combine.
    if spell.type == 'WeaponSkill' then
        local ws_set = sets.precast.WS[spell.english] or sets.precast.WS
        if treasure_mode and th_weaponskills[spell.english] then
            ws_set = set_combine(ws_set, sets.TreasureSet)
        end
        equip(ws_set)
        return
    end

    -- Curing Waltz (requires /DNC). GearSwap reports every Waltz tier as spell.type == 'Waltz',
    -- so this one branch covers Curing Waltz through Curing Waltz V. 2-slot overlay.
    if spell.type == 'Waltz' then
        equip(sets.precast.Waltz)
        return
    end

    -- Job Abilities (only Flee has a dedicated set; others leave current gear unchanged)
    if spell.type == 'JobAbility' then
        if sets.precast.JA[spell.english] then
            equip(sets.precast.JA[spell.english])
        end
        return
    end

    -- Spell casts: Trust summons and any subjob magic (e.g. /WHM, /RDM) get the
    -- Fast Cast set. spell.action_type == 'Magic' covers all spell categories
    -- (Trust, White/Black/Blue/etc.) in one branch.
    if spell.action_type == 'Magic' then
        equip(sets.precast.FC)
        return
    end

end

----------------------------------------------------------------------------------------------------------------
-- MIDCAST
-- THF has no midcast gear swaps (no FC/magic sets defined, matching the old file).
----------------------------------------------------------------------------------------------------------------
function midcast(spell, action)
    -- Nothing needed for THF
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
-- THF has no buff-driven gear locks currently. Placeholder for future use.
----------------------------------------------------------------------------------------------------------------
function buff_change(buff, gain, details)
    -- Nothing needed currently
end

----------------------------------------------------------------------------------------------------------------
-- SELF COMMAND
--   Ctrl+` fires: //gs c toggle dt   -- Damage Taken mode
--   Alt+`  fires: //gs c toggle th   -- Treasure Hunter overlay
----------------------------------------------------------------------------------------------------------------
function self_command(command)
    if command == 'toggle th' then
        treasure_mode = not treasure_mode
        if treasure_mode then
            windower.add_to_chat(122, '[TH Mode ON] Per. Lucky Egg / Plun. Armlets +2 / Hoxne Ring overlay active.')
        else
            windower.add_to_chat(122, '[TH Mode OFF] Standard engaged gear restored.')
        end
        equip_current_set()
        return
    end

    -- Clears only the MANUAL flag. If HP is still at/below hp_dt_threshold the automatic
    -- trigger keeps DT engaged, which is why the "off" message is worded conditionally.
    if command == 'toggle dt' then
        dt_manual = not dt_manual
        if dt_manual then
            windower.add_to_chat(122, '[DT Mode ON] Damage Taken set locked on.')
        elseif player.hpp <= hp_dt_threshold then
            windower.add_to_chat(122, '[DT Mode] Manual lock released, but HP is at/below '..hp_dt_threshold..'% -- DT still active.')
        else
            windower.add_to_chat(122, '[DT Mode OFF] Standard gear restored.')
        end
        equip_current_set()
        return
    end
end

----------------------------------------------------------------------------------------------------------------
-- HP WATCHER (survival)
-- Event-driven on action packets (NOT a frame poll, no coroutine accumulation). When the player
-- is targeted (i.e. takes damage), re-check HP so the low-HP swap into sets.DT fires
-- promptly instead of waiting for the next swing/aftercast. Guarded by midaction() so it can
-- never strip precast/WS gear mid-action; HP recovery is picked up on the next aftercast/hit.
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
----------------------------------------------------------------------------------------------------------------
-- GearSwap does NOT expose a named zone_change() callback; a function named that
-- is never called. Must be a registered windower event, reading world.zone (a
-- zone NAME string) rather than the numeric zone IDs the callback is handed.
-- Handle is stored so file_unload() can tear it down. Mirrors Ashkev_BLM.lua.
zone_watch_id = windower.register_event('zone change', function(new_id, old_id)
    in_adoulin = (world.zone == 'Western Adoulin' or world.zone == 'Eastern Adoulin')
    if in_adoulin then
        windower.add_to_chat(122, 'THF: Adoulin zone detected -- Councilor\'s Garb equipped as idle body.')
    end
    equip_current_set()
end)

----------------------------------------------------------------------------------------------------------------
-- FILE UNLOAD: clean up the keybind, HP watcher, and zone watcher on job change / //gs reload.
----------------------------------------------------------------------------------------------------------------
function file_unload()
    if hp_watch_id then windower.unregister_event(hp_watch_id) end
    if zone_watch_id then windower.unregister_event(zone_watch_id) end
    send_command('unbind ^`')
    send_command('unbind !`')
end
