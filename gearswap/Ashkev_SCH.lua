-------------------------------------------------------------------------------
-- Ashkev_SCH.lua
-- Character: Ashkev  |  Job: Scholar (SCH)  |  Sub: /WHM baseline
--
-- ARCHITECTURE (do not "fix" these deliberate choices in later edits):
--   * Raw GearSwap ONLY.  No Mote-Include, no state objects, no coroutines,
--     no background polling, no per-frame loops.
--   * Weapons are NEVER placed in gear sets.  main= / sub= are intentionally
--     omitted from every set below.  Equipping a weapon zeroes TP and can
--     disrupt pending weaponskills.  If a dedicated weapon toggle is added
--     later it lives in its own explicit set outside these midcast/precast
--     sets, like the THF Naegling toggle.
--   * Event-driven only.  All binds and any watchers are torn down in
--     file_unload().
--   * Item names come verbatim from //gs export.  GearSwap match is exact
--     and case-sensitive; abbreviations fail silently.
--
-- KEY BEHAVIORS:
--   * Grimoire head conditional:  Peda. M.Board +2 swaps into the FC precast
--     ONLY when the spell's magic type matches the active arts stance AND
--     neither Celerity nor Alacrity is up.  The Grimoire spellcasting
--     multiplier stacks past the 80% FC gear cap up to the 90% cast-time
--     floor, but it does NOT stack with Celerity/Alacrity.
--   * Occult Acumen toggle:  Ctrl+` or F9 flips oa_mode.  When ON, the
--     midcast Elemental branch equips the OA set if player.tp < 2000; above
--     the cutoff it falls through to FreeNuke.  Mirror of the BLM pattern.
--
-- RELOAD AFTER EDITS:  //gs reload  (new keybinds and self_command handlers
-- only register during load).
-------------------------------------------------------------------------------

function get_sets()
    -- =========================================================================
    -- State
    -- =========================================================================
    oa_mode       = false   -- Occult Acumen TP-generation mode
    oa_tp_cutoff  = 2000    -- Above this TP, OA override falls through to FreeNuke

    -- =========================================================================
    -- Keybinds
    -- =========================================================================
    send_command('bind ^` gs c toggle oa')
    send_command('bind F9 gs c toggle oa')

    -- =========================================================================
    -- Gear sets
    -- =========================================================================
    sets.precast = {}
    sets.midcast = {}

    ---------------------------------------------------------------------------
    -- IDLE / DT
    ---------------------------------------------------------------------------
    sets.Idle = {
        ammo="Ombre Tathlum +1",
        head="Nyame Helm",
        body="Jhakri Robe +2",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Elite Royal Collar",
        waist="Null Belt",
        left_ear="Sortiarius Earring",
        right_ear="Malignance Earring",
        left_ring="Shneddick Ring",
        right_ring="Defending Ring",
        back="Null Shawl",
    }

    ---------------------------------------------------------------------------
    -- ENGAGED / TP
    ---------------------------------------------------------------------------
    sets.engaged = {
        ammo="Floestone",
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Jhakri Slops +2",
        feet="Nyame Sollerets",
        neck="Null Loop",
        waist="Null Belt",
        left_ear="Tripudio Earring",
        right_ear="Balder Earring",
        left_ring="Lehko's Ring",
        right_ring="Petrov Ring",
        back="Null Shawl",
    }

    ---------------------------------------------------------------------------
    -- PRECAST: FAST CAST (baseline)
    -- Used when the spell does NOT match active arts, OR when Celerity/
    -- Alacrity is up (they do not stack with Grimoire spellcasting gear).
    ---------------------------------------------------------------------------
    sets.precast.FastCast = {
        ammo="Impatiens",
        head={ name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        body={ name="Merlinic Jubbah", augments={'Mag. Acc.+25 "Mag.Atk.Bns."+25','"Fast Cast"+7','INT+7','Mag. Acc.+6','"Mag.Atk.Bns."+7',}},
        hands={ name="Merlinic Dastanas", augments={'Attack+16','"Fast Cast"+5','CHR+6',}},
        legs={ name="Merlinic Shalwar", augments={'Attack+20','"Fast Cast"+7','VIT+9','Mag. Acc.+8','"Mag.Atk.Bns."+6',}},
        feet={ name="Merlinic Crackows", augments={'"Fast Cast"+6','VIT+8','Mag. Acc.+9','"Mag.Atk.Bns."+12',}},
        neck="Orunmila's Torque",
        waist="Embla Sash",
        left_ear="Enchntr. Earring +1",
        right_ear="Malignance Earring",
        left_ring="Naji's Loop",
        right_ring="Lebeche Ring",
        back="Null Shawl",
    }

    ---------------------------------------------------------------------------
    -- PRECAST: FAST CAST — GRIMOIRE VARIANT
    -- Head swap only:  Peda. M.Board +2 layers Grimoire spellcasting time
    -- reduction on top of the 80% FC gear cap.  Applies only when the spell
    -- matches active arts AND Celerity/Alacrity is not up.
    -- Inherits ammo="Impatiens" from FastCast via set_combine.
    ---------------------------------------------------------------------------
    sets.precast.FastCast_Grimoire = set_combine(sets.precast.FastCast, {
        head="Peda. M.Board +2",
    })

    ---------------------------------------------------------------------------
    -- MIDCAST: ELEMENTAL MAGIC — FREE NUKE
    -- Full Amalric +1 stack for the 3-piece MAB set bonus.
    ---------------------------------------------------------------------------
    sets.midcast.FreeNuke = {
        ammo="Ombre Tathlum +1",
        head={ name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        body={ name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        hands={ name="Amalric Gages +1", augments={'INT+12','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        legs={ name="Amalric Slops +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        feet={ name="Amalric Nails +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        neck="Sanctity Necklace",
        waist="Skrymir Cord",
        left_ear="Malignance Earring",
        right_ear={ name="Arbatel Earring", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+6',}},
        left_ring="Shiva Ring +1",
        right_ring="Resonance Ring",
        back="Null Shawl",
    }

    ---------------------------------------------------------------------------
    -- MIDCAST: OCCULT ACUMEN (TP-generation override for Elemental Magic)
    -- Overrides FreeNuke when oa_mode == true AND player.tp < oa_tp_cutoff.
    -- Merlinic Crackows OA cap confirmed at +11.  Perdition Slops = +30 OA.
    ---------------------------------------------------------------------------
    sets.midcast.OccultAcumen = {
        ammo="Ombre Tathlum +1",
        head="Mall. Chapeau +2",
        body={ name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        hands={ name="Merlinic Dastanas", augments={'Mag. Acc.+21','"Occult Acumen"+8','"Mag.Atk.Bns."+7',}},
        legs="Perdition Slops",
        feet={ name="Merlinic Crackows", augments={'"Occult Acumen"+11','CHR+6','Mag. Acc.+12',}},
        neck="Argute Stole +1",
        waist="Oneiros Rope",
        left_ear="Malignance Earring",
        right_ear={ name="Arbatel Earring", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+6',}},
        left_ring="Lehko's Ring",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
    }

    ---------------------------------------------------------------------------
    -- MIDCAST: HEALING MAGIC (Cure line)
    -- Peda. M.Board +2 head kept from the Grimoire precast when in Light Arts.
    ---------------------------------------------------------------------------
    sets.midcast.Cure = {
        ammo="Ombre Tathlum +1",
        head="Peda. M.Board +2",
        body="Chironic Doublet",
        hands={ name="Kaykaus Cuffs +1", augments={'MP+80','"Conserve MP"+7','"Fast Cast"+4',}},
        legs={ name="Kaykaus Tights +1", augments={'MP+80','"Cure" spellcasting time -7%','Enmity-6',}},
        feet="Vanya Clogs",
        neck="Phalaina Locket",
        waist="Latria Sash",
        left_ear="Malignance Earring",
        right_ear={ name="Arbatel Earring", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+6',}},
        left_ring="Stikini Ring +1",
        right_ring="Mallquis Ring",
        back="Tempered Cape +1",
    }

    ---------------------------------------------------------------------------
    -- MIDCAST: ENHANCING MAGIC (general / Stoneskin / Aquaveil)
    -- Single set for now; Nodens Gorget + Earthcry Earring push Stoneskin
    -- toward the 350 HP absorption cap.  Aquaveil ideally gets a dedicated
    -- SIRD-heavy variant later (Amalric Coif +1 Path A, Regal Cuffs, etc.).
    -- set_combine used to build independent copies so future edits to one
    -- do not mutate the others.
    ---------------------------------------------------------------------------
    sets.midcast['Enhancing Magic'] = {
        ammo="Hydrocera",
        head={ name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        body="Mallquis Saio +2",
        hands="Mallquis Cuffs +2",
        legs="Shedir Seraweels",
        feet="Mallquis Clogs +2",
        neck="Nodens Gorget",
        waist="Embla Sash",
        left_ear="Earthcry Earring",
        right_ear="Malignance Earring",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
    }
    sets.midcast.Stoneskin = set_combine(sets.midcast['Enhancing Magic'], {})
    sets.midcast.Aquaveil  = set_combine(sets.midcast['Enhancing Magic'], {})

    ---------------------------------------------------------------------------
    -- PRECAST: WEAPON SKILLS
    ---------------------------------------------------------------------------
    sets.precast.WS = {
        ammo="Oshasha's Treatise",
        head="Jhakri Coronal +2",
        body="Jhakri Robe +2",
        hands="Jhakri Cuffs +2",
        legs="Jhakri Slops +2",
        feet="Jhakri Pigaches +2",
        neck="Sanctity Necklace",
        waist="Refoccilation Stone",
        left_ear="Malignance Earring",
        right_ear={ name="Arbatel Earring", augments={'System: 1 ID: 1676 Val: 0','Mag. Acc.+6',}},
        left_ring="Stikini Ring +1",
        right_ring="Epaminondas's Ring",
        back="Null Shawl",
    }

    -- Myrkr: max MP for MP-restore WS.  Uploaded set was partial (5 slots);
    -- set_combine over the WS default fills the remaining slots so no slot
    -- is left empty at cast time.
    sets.precast.WS['Myrkr'] = set_combine(sets.precast.WS, {
        ammo="Psilomene",
        head={ name="Amalric Coif +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        body={ name="Amalric Doublet +1", augments={'MP+80','Mag. Acc.+20','"Mag.Atk.Bns."+20',}},
        left_ring="Stikini Ring +1",
    })
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- Returns true when the spell's magic type matches the active grimoire AND
-- neither Celerity nor Alacrity is up (they do not stack with Grimoire
-- spellcasting gear).  Used to decide between FastCast baseline and the
-- FastCast_Grimoire variant.
local function grimoire_matches(spell)
    if not spell or not spell.type then return false end
    if buffactive['Celerity'] or buffactive['Alacrity'] then
        return false
    end
    local is_white = (spell.type == 'WhiteMagic')
    local is_black = (spell.type == 'BlackMagic')
    local light_active = buffactive['Light Arts'] or buffactive['Addendum: White']
    local dark_active  = buffactive['Dark Arts']  or buffactive['Addendum: Black']
    return (is_white and light_active) or (is_black and dark_active)
end

-------------------------------------------------------------------------------
-- Precast
-------------------------------------------------------------------------------
function precast(spell)
    if spell.action_type == 'Magic' then
        if grimoire_matches(spell) then
            equip(sets.precast.FastCast_Grimoire)
        else
            equip(sets.precast.FastCast)
        end
    elseif spell.type == 'WeaponSkill' then
        if sets.precast.WS[spell.english] then
            equip(sets.precast.WS[spell.english])
        else
            equip(sets.precast.WS)
        end
    end
end

-------------------------------------------------------------------------------
-- Midcast
-------------------------------------------------------------------------------
function midcast(spell)
    if spell.action_type ~= 'Magic' then return end

    if spell.skill == 'Elemental Magic' then
        -- OA override: only when mode is on and TP is under the cutoff.
        if oa_mode and player.tp < oa_tp_cutoff then
            equip(sets.midcast.OccultAcumen)
        else
            equip(sets.midcast.FreeNuke)
        end
    elseif spell.skill == 'Healing Magic' then
        equip(sets.midcast.Cure)
    elseif spell.skill == 'Enhancing Magic' then
        if spell.english == 'Stoneskin' then
            equip(sets.midcast.Stoneskin)
        elseif spell.english == 'Aquaveil' then
            equip(sets.midcast.Aquaveil)
        else
            equip(sets.midcast['Enhancing Magic'])
        end
    end
    -- NOTE: Dark Magic (Drain/Aspir/Stun/Bio/Dispel) and Enfeebling Magic
    -- currently have no dedicated midcast branch and will retain the FC set.
    -- Build those sets in a follow-up pass.
end

-------------------------------------------------------------------------------
-- Aftercast
-------------------------------------------------------------------------------
function aftercast(spell)
    if player.status == 'Engaged' then
        equip(sets.engaged)
    else
        equip(sets.Idle)
    end
end

-------------------------------------------------------------------------------
-- Status change (Idle <-> Engaged)
-------------------------------------------------------------------------------
function status_change(new_status, old_status)
    if new_status == 'Engaged' then
        equip(sets.engaged)
    elseif new_status == 'Idle' then
        equip(sets.Idle)
    end
end

-------------------------------------------------------------------------------
-- Self-command handlers  ( //gs c ... )
-------------------------------------------------------------------------------
function self_command(command)
    local args = {}
    for word in string.gmatch(command, '%S+') do
        table.insert(args, word)
    end

    if args[1] == 'toggle' and args[2] == 'oa' then
        oa_mode = not oa_mode
        local state = oa_mode and 'ON' or 'OFF'
        windower.add_to_chat(158, '[SCH] Occult Acumen mode: '..state)
    end
end

-------------------------------------------------------------------------------
-- Teardown:  unbind keys on file unload / reload.
-------------------------------------------------------------------------------
function file_unload()
    send_command('unbind ^`')
    send_command('unbind F9')
end
