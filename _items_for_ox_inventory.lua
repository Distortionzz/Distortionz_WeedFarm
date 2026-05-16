-- =====================================================================
--  distortionz_weedfarm — ox_inventory items
--  Paste these into ox_inventory/data/items.lua (inside the return {}).
--  `black_money` is assumed to already exist (distortionz_scrapper uses
--  it). dz_joint is made useable by distortionz_weedfarm via qbx_core
--  CreateUseableItem — do NOT add an ox client/server use handler here.
-- =====================================================================

['weed_nugget'] = {
    label = 'Weed Nugget',
    weight = 8,
    stack = true,
    close = true,
    description = 'A dense nugget of fresh-harvested bud.',
    client = {
        image = 'weed_nugget.png',
    },
},

['dz_joint'] = {
    label = 'Joint',
    weight = 3,
    stack = true,
    close = true,
    description = 'Rolled and ready. Takes the edge off.',
    client = {
        image = 'dz_joint.png',
    },
},
