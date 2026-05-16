Config = {}

Config.Debug = true   -- TESTING: prints plant spawn/target lines. Set false before shipping.

Config.ResourceName   = 'distortionz_weedfarm'
Config.CurrentVersion = '1.0.5'

-- ─── Version checker ────────────────────────────────────────────────
Config.VersionCheck = {
    enabled      = true,
    url          = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_WeedFarm/main/version.json',
    checkOnStart = true,
}

-- ─── Notify integration ─────────────────────────────────────────────
Config.Notify = {
    title                 = 'Weed Farm',
    useDistortionzNotify  = true,
}

-- ─── Items ──────────────────────────────────────────────────────────
-- These names MUST match ox_inventory item names. A paste-in snippet
-- for ox_inventory/data/items.lua is at _items_for_ox_inventory.lua.
Config.Items = {
    nugget = 'weed_nugget',   -- raw harvested product
    joint  = 'dz_joint',      -- rolled, smokeable (self-contained)
    money  = 'black_money',   -- dirty-money item (matches distortionz_scrapper)
}

-- ─── Grow field ─────────────────────────────────────────────────────
Config.Field = {
    -- Mature plant prop (player can harvest) and the stub it leaves while
    -- regrowing. Both are base-game weed props.
    ripeProp      = 'bkr_prop_weed_lrg_01b',
    regrowProp    = 'bkr_prop_weed_01_small_01c',

    harvestMs     = 4500,            -- progress time to pull a plant
    regrowSeconds = 150,             -- time before a harvested plant is ripe again
    yield         = { min = 2, max = 5 },  -- nuggets per plant

    target = {
        icon     = 'fa-solid fa-cannabis',
        label    = 'Harvest plant',
        distance = 2.5,
    },

    -- Plant placements. PLACEHOLDER — a quiet field NW of the map. Replace
    -- with your real vec3 spots before shipping.
    plants = {
        vec3(2222.10, 5577.30, 53.70),
        vec3(2225.40, 5575.10, 53.66),
        vec3(2219.00, 5574.40, 53.72),
        vec3(2227.80, 5571.60, 53.60),
        vec3(2221.50, 5569.90, 53.64),
        vec3(2216.20, 5571.80, 53.71),
        vec3(2229.90, 5567.40, 53.55),
        vec3(2224.10, 5565.80, 53.58),
    },
}

-- ─── Rolling (nuggets → joint) ──────────────────────────────────────
Config.Roll = {
    command         = 'rolljoint',   -- chat command to roll
    nuggetsPerJoint = 3,
    paperItem       = nil,           -- optional extra item required, e.g. 'rolling_paper' (nil = none)
    durationMs      = 5000,
}

-- ─── Street dealing (cornersell-style) ──────────────────────────────
Config.Sell = {
    command       = 'sellweed',      -- toggles dealing mode on/off

    scanRadius    = 14.0,            -- look for buyer peds within this range
    offerDistance = 2.6,             -- must be this close to offer a deal
    offerKey      = 38,              -- control id (38 = E)

    perDeal       = { min = 1, max = 3 },     -- nuggets moved per deal
    pricePerNugget= { min = 70, max = 115 },  -- dirty money per nugget

    acceptChance  = 0.70,            -- chance the NPC takes the deal
    snitchChance  = 0.15,            -- on refusal, chance the NPC calls it in

    cooldownMs    = 4000,            -- server anti-spam between deals (per player)
    pedCooldownMs = 30000,           -- can't deal the same ped again within this

    dealAnim = {
        dict       = 'mp_common',
        clipPlayer = 'givetake1_a',
        clipPed    = 'givetake1_b',
        durationMs = 3000,
    },

    -- Prop held during the hand-off. attachTo: 'ped' (buyer holds it),
    -- 'player' (you hold it), or 'both'. Set enabled=false to disable.
    -- bkr_prop_weed_bag_01a = small zip baggie (fits a hand). Big bags
    -- like prop_paper_bag_01 engulf the ped — avoid hand-attaching those.
    bag = {
        enabled  = true,
        model    = 'bkr_prop_weed_bag_01a',
        attachTo = 'ped',
        bone     = 28422,                       -- right hand
        pos      = vec3(0.14, 0.03, 0.0),
        rot      = vec3(-100.0, 25.0, 0.0),
    },
}

-- ─── Police heat (street sales) ─────────────────────────────────────
Config.Heat = {
    enabled       = true,
    sellChance    = 0.10,            -- per successful deal
    alertDelayMs  = { min = 3000, max = 8000 },
    alertCode     = '10-66',
    alertLabel    = 'Suspected street narcotics dealing',
    alertJobs     = { 'police', 'sheriff', 'fib' },
}

-- ─── Joint / smoking ────────────────────────────────────────────────
-- Smoking fires the server's canonical `hud:server:RelieveStress` event
-- (same path qbx_consumables uses), so it works with the stock HUD.
Config.Joint = {
    -- Same smoke-weed animation the stock joint uses: the scully_emotemenu
    -- 'joint' emote. Falls back to smokeAnim if scully isn't running.
    emote      = 'joint',
    smokeAnim  = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c' },
    cycles     = 5,                  -- relief ticks per joint
    intervalMs = 8000,               -- ms between ticks
    relief     = { min = 12, max = 18 },  -- stress removed per tick
}
