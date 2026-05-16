-- =====================================================================
--  Distortionz Weed Farm - Server
--  Authoritative: harvest cooldown per plant, roll recipe, street-deal
--  validation + payout + police heat, dz_joint useable -> client smoke.
-- =====================================================================

local lastHarvest = {}   -- [plantIndex] = os.time()
local lastDeal    = {}   -- [src] = GetGameTimer()

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:server] %s'):format(Config.ResourceName, message))
    end
end

-- ─── qbx / inventory helpers ────────────────────────────────────────

local function GetPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and p then return p end
    end
    return nil
end

local function GetPlayerJobName(src)
    local p = GetPlayer(src)
    if p and p.PlayerData and p.PlayerData.job then return p.PlayerData.job.name end
    return nil
end

local function CountItem(src, item)
    if GetResourceState('ox_inventory') ~= 'started' then return 0 end
    local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, item) end)
    return ok and (tonumber(n) or 0) or 0
end

local function RemoveItem(src, item, qty)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local ok, success = pcall(function() return exports.ox_inventory:RemoveItem(src, item, qty) end)
    return ok and success == true
end

local function AddItem(src, item, qty)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local ok = pcall(function() exports.ox_inventory:AddItem(src, item, qty) end)
    return ok
end

local function CanCarry(src, item, qty)
    if GetResourceState('ox_inventory') ~= 'started' then return true end
    local ok, can = pcall(function() return exports.ox_inventory:CanCarryItem(src, item, qty) end)
    return ok and can == true
end

local function Notify(src, message, status, duration)
    TriggerClientEvent('distortionz_weedfarm:client:notify', src,
        message, status or 'info', duration or 5000)
end

local function IsNear(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local d = #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z))
    return d <= (maxDistance or 5.0)
end

-- ─── Police heat ────────────────────────────────────────────────────

local function FireHeat(src)
    if not Config.Heat.enabled then return end

    local ped = GetPlayerPed(src)
    local pc  = ped and ped ~= 0 and GetEntityCoords(ped) or vec3(0.0, 0.0, 0.0)

    if GetResourceState('distortionz_cad') == 'started' then
        pcall(function()
            exports['distortionz_cad']:AddCall({
                code     = Config.Heat.alertCode,
                title    = Config.Heat.alertLabel,
                location = 'Street narcotics',
                coords   = { x = pc.x, y = pc.y, z = pc.z },
                priority = 2,
            })
        end)
    end

    local delay = math.random(Config.Heat.alertDelayMs.min or 3000, Config.Heat.alertDelayMs.max or 8000)

    SetTimeout(delay, function()
        local jobs = {}
        for _, j in ipairs(Config.Heat.alertJobs or {}) do jobs[j] = true end

        for _, sid in ipairs(GetPlayers()) do
            local s = tonumber(sid)
            if s and jobs[GetPlayerJobName(s)] then
                TriggerClientEvent('distortionz_weedfarm:client:heat', s, {
                    code   = Config.Heat.alertCode,
                    label  = Config.Heat.alertLabel,
                    coords = { x = pc.x, y = pc.y, z = pc.z },
                })
            end
        end
    end)
end

-- ─── Harvest ────────────────────────────────────────────────────────

lib.callback.register('distortionz_weedfarm:server:harvest', function(source, index)
    local src = source
    index = tonumber(index)
    local coords = index and Config.Field.plants[index]
    if not coords then return { ok = false, reason = 'Invalid plant.' } end

    if not IsNear(src, coords, Config.Field.target.distance + 3.0) then
        return { ok = false, reason = 'Get to the plant.' }
    end

    if (os.time() - (lastHarvest[index] or 0)) < Config.Field.regrowSeconds then
        return { ok = false, reason = 'That plant is still growing.' }
    end

    local amount = math.random(Config.Field.yield.min, Config.Field.yield.max)
    if not CanCarry(src, Config.Items.nugget, amount) then
        return { ok = false, reason = 'You can\'t carry that much.' }
    end

    lastHarvest[index] = os.time()
    AddItem(src, Config.Items.nugget, amount)

    DebugPrint(('harvest src=%s idx=%s amount=%s'):format(src, index, amount))
    return { ok = true, amount = amount }
end)

-- ─── Roll ───────────────────────────────────────────────────────────

lib.callback.register('distortionz_weedfarm:server:roll', function(source)
    local src  = source
    local need = Config.Roll.nuggetsPerJoint

    if CountItem(src, Config.Items.nugget) < need then
        return { ok = false, reason = ('Need %d nuggets.'):format(need) }
    end
    if Config.Roll.paperItem and CountItem(src, Config.Roll.paperItem) < 1 then
        return { ok = false, reason = ('Need %s.'):format(Config.Roll.paperItem) }
    end
    if not CanCarry(src, Config.Items.joint, 1) then
        return { ok = false, reason = 'No room for a joint.' }
    end

    if not RemoveItem(src, Config.Items.nugget, need) then
        return { ok = false, reason = 'Failed to take nuggets.' }
    end
    if Config.Roll.paperItem and not RemoveItem(src, Config.Roll.paperItem, 1) then
        AddItem(src, Config.Items.nugget, need)  -- rollback
        return { ok = false, reason = ('Failed to take %s.'):format(Config.Roll.paperItem) }
    end

    AddItem(src, Config.Items.joint, 1)
    return { ok = true, reason = 'Rolled a joint.' }
end)

-- ─── Street deal ────────────────────────────────────────────────────

lib.callback.register('distortionz_weedfarm:server:sell', function(source)
    local src = source

    if (GetGameTimer() - (lastDeal[src] or 0)) < Config.Sell.cooldownMs then
        return { ok = false, reason = 'Too soon — play it cool.' }
    end
    lastDeal[src] = GetGameTimer()

    local have = CountItem(src, Config.Items.nugget)
    if have <= 0 then
        return { ok = false, reason = 'You have nothing to sell.' }
    end

    local amount = math.random(Config.Sell.perDeal.min, Config.Sell.perDeal.max)
    if amount > have then amount = have end

    if math.random() > Config.Sell.acceptChance then
        if math.random() < Config.Sell.snitchChance then FireHeat(src) end
        return { ok = true, accepted = false }
    end

    if not RemoveItem(src, Config.Items.nugget, amount) then
        return { ok = false, reason = 'Deal fell through.' }
    end

    local per    = math.random(Config.Sell.pricePerNugget.min, Config.Sell.pricePerNugget.max)
    local payout = per * amount
    AddItem(src, Config.Items.money, payout)

    if math.random() < (Config.Heat.sellChance or 0) then FireHeat(src) end

    DebugPrint(('deal src=%s amount=%s payout=%s'):format(src, amount, payout))
    return { ok = true, accepted = true, amount = amount, payout = payout }
end)

-- ─── dz_joint useable -> smoke ──────────────────────────────────────

CreateThread(function()
    if GetResourceState('qbx_core') ~= 'started' then return end
    pcall(function()
        exports.qbx_core:CreateUseableItem(Config.Items.joint, function(source)
            if RemoveItem(source, Config.Items.joint, 1) then
                TriggerClientEvent('distortionz_weedfarm:client:smoke', source)
            end
        end)
    end)
end)

AddEventHandler('playerDropped', function()
    lastDeal[source] = nil
end)
