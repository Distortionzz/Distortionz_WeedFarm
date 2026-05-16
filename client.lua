-- =====================================================================
--  Distortionz Weed Farm - Client
--  Harvest field plants -> nuggets. Roll nuggets -> dz_joint. Smoke a
--  joint to cut stress. Deal nuggets to spawned street NPCs.
-- =====================================================================

local plants      = {}     -- [index] = { prop = entity, ripe = bool }
local dealing     = false
local pedCooldown = {}     -- [pedNetOrHandle] = GetGameTimer() until

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:client] %s'):format(Config.ResourceName, message))
    end
end

-- ─── Notify wrapper ─────────────────────────────────────────────────

local function Notify(message, status, duration)
    status   = status or 'info'
    duration = duration or 5000

    if Config.Notify.useDistortionzNotify and GetResourceState('distortionz_notify') == 'started' then
        local ok = pcall(function()
            exports['distortionz_notify']:Notify(message, status, duration)
        end)
        if ok then return end
        ok = pcall(function()
            exports['distortionz_notify']:Send(message, status, duration)
        end)
        if ok then return end
        ok = pcall(function()
            TriggerEvent('distortionz_notify:client:notify', message, status, duration)
        end)
        if ok then return end
    end

    lib.notify({
        title       = Config.Notify.title,
        description = message,
        type        = status,
        duration    = duration,
    })
end

RegisterNetEvent('distortionz_weedfarm:client:notify', function(message, status, duration)
    Notify(message, status, duration)
end)

-- ─── Helpers ────────────────────────────────────────────────────────

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        Wait(25)
        if GetGameTimer() > deadline then return nil end
    end
    return hash
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 8000
    while not HasAnimDictLoaded(dict) do
        Wait(25)
        if GetGameTimer() > deadline then return false end
    end
    return true
end

local function DeleteEntitySafe(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

-- ─── Field plants ───────────────────────────────────────────────────

local function makePlant(index)
    local data  = plants[index]
    local coords = Config.Field.plants[index]
    local model  = data.ripe and Config.Field.ripeProp or Config.Field.regrowProp

    local hash = LoadModel(model)
    if not hash then
        print(('[%s] plant %s: prop model failed to load (%s)'):format(
            Config.ResourceName, index, tostring(model)))
        return
    end

    -- Ground-snap with fallback + sanity clamp. Collision is often not
    -- streamed when the resource starts, so PlaceObjectOnGroundProperly
    -- alone leaves the prop off-Z (same trap as the scrapper ped).
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
    local z = coords.z
    if foundGround and math.abs(groundZ - coords.z) <= 5.0 then
        z = groundZ
    end

    local prop = CreateObject(hash, coords.x, coords.y, z, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetEntityAsMissionEntity(prop, false, false)
    SetModelAsNoLongerNeeded(hash)
    data.prop = prop

    if data.ripe then
        if GetResourceState('ox_target') ~= 'started' then
            print(('[%s] ox_target is NOT started — no harvest option can appear.'):format(
                Config.ResourceName))
            return
        end
        exports.ox_target:addLocalEntity(prop, {
            {
                name        = ('dz_weed_plant_%s'):format(index),
                label       = Config.Field.target.label,
                icon        = Config.Field.target.icon,
                distance    = Config.Field.target.distance,
                onSelect    = function() HarvestPlant(index) end,
            },
        })
        DebugPrint(('plant %s ready @ %.2f %.2f %.2f (snapZ=%s) target added'):format(
            index, coords.x, coords.y, z, tostring(foundGround)))
    end
end

local function clearPlant(index)
    local data = plants[index]
    if not data then return end
    if data.prop and DoesEntityExist(data.prop) then
        pcall(function() exports.ox_target:removeLocalEntity(data.prop) end)
        DeleteEntitySafe(data.prop)
    end
    data.prop = nil
end

function HarvestPlant(index)
    local data = plants[index]
    if not data or not data.ripe then return end

    if lib.progressBar({
        duration    = Config.Field.harvestMs,
        label       = 'Harvesting…',
        useWhileDead = false,
        canCancel   = true,
        disable     = { move = true, car = true, combat = true },
        anim        = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
    }) then
        local res = lib.callback.await('distortionz_weedfarm:server:harvest', false, index)
        if not res or not res.ok then
            Notify((res and res.reason) or 'Nothing to harvest.', 'error', 4000)
            return
        end

        data.ripe = false
        clearPlant(index)
        makePlant(index)

        Notify(('Harvested %d nuggets.'):format(res.amount), 'success', 4000)

        SetTimeout(Config.Field.regrowSeconds * 1000, function()
            if not plants[index] then return end
            plants[index].ripe = true
            clearPlant(index)
            makePlant(index)
        end)
    end
end

CreateThread(function()
    Wait(500)
    for i = 1, #Config.Field.plants do
        plants[i] = { prop = nil, ripe = true }
        makePlant(i)
    end
    local spawned = 0
    for _, d in pairs(plants) do
        if d.prop and DoesEntityExist(d.prop) then spawned += 1 end
    end
    print(('[%s] field bootstrap: %d/%d plant props spawned'):format(
        Config.ResourceName, spawned, #Config.Field.plants))
end)

-- ─── Rolling ────────────────────────────────────────────────────────

RegisterCommand(Config.Roll.command, function()
    if lib.progressBar({
        duration    = Config.Roll.durationMs,
        label       = 'Rolling a joint…',
        useWhileDead = false,
        canCancel   = true,
        disable     = { move = true, car = true, combat = true },
        anim        = { dict = 'mp_common', clip = 'givetake1_a' },
    }) then
        local res = lib.callback.await('distortionz_weedfarm:server:roll', false)
        Notify((res and res.reason) or (res and res.ok and 'Rolled a joint.') or 'Could not roll.',
            (res and res.ok) and 'success' or 'error', 4000)
    end
end, false)

-- ─── Street dealing (cornersell-style) ──────────────────────────────

local function findBuyerPed()
    local pc   = GetEntityCoords(cache.ped)
    local best, bestDist
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped
            and DoesEntityExist(ped)
            and not IsPedAPlayer(ped)
            and not IsPedDeadOrDying(ped, true)
            and not IsPedInAnyVehicle(ped, false)
            and (not pedCooldown[ped] or GetGameTimer() > pedCooldown[ped]) then
            local d = #(pc - GetEntityCoords(ped))
            if d <= Config.Sell.scanRadius and (not bestDist or d < bestDist) then
                best, bestDist = ped, d
            end
        end
    end
    return best, bestDist
end

local function attachBag(targetPed)
    local bag = Config.Sell.bag
    local hash = LoadModel(bag.model)
    if not hash then return nil end

    local c = GetEntityCoords(targetPed)
    local prop = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    AttachEntityToEntity(prop, targetPed, GetPedBoneIndex(targetPed, bag.bone),
        bag.pos.x, bag.pos.y, bag.pos.z,
        bag.rot.x, bag.rot.y, bag.rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function doDeal(ped)
    local res = lib.callback.await('distortionz_weedfarm:server:sell', false)
    if not res or not res.ok then
        Notify((res and res.reason) or 'Deal failed.', 'error', 3500)
        return
    end

    local anim = Config.Sell.dealAnim
    LoadAnimDict(anim.dict)
    TaskTurnPedToFaceEntity(ped, cache.ped, anim.durationMs)
    TaskTurnPedToFaceEntity(cache.ped, ped, anim.durationMs)
    Wait(600)
    TaskPlayAnim(cache.ped, anim.dict, anim.clipPlayer, 3.0, -3.0, anim.durationMs, 49, 0.0, false, false, false)
    TaskPlayAnim(ped, anim.dict, anim.clipPed, 3.0, -3.0, anim.durationMs, 49, 0.0, false, false, false)

    local bags = {}
    if Config.Sell.bag.enabled then
        local who = Config.Sell.bag.attachTo
        if who == 'ped' or who == 'both' then
            bags[#bags + 1] = attachBag(ped)
        end
        if who == 'player' or who == 'both' then
            bags[#bags + 1] = attachBag(cache.ped)
        end
    end

    Wait(anim.durationMs)

    for _, b in ipairs(bags) do
        if b and DoesEntityExist(b) then DeleteEntity(b) end
    end

    pedCooldown[ped] = GetGameTimer() + Config.Sell.pedCooldownMs

    if res.accepted then
        Notify(('Sold %d for $%d.'):format(res.amount, res.payout), 'success', 4000)
    else
        Notify('They turned you down.', 'error', 3500)
        ClearPedTasks(ped)
        TaskSmartFleePed(ped, cache.ped, 60.0, -1, false, false)
    end
end

RegisterCommand(Config.Sell.command, function()
    dealing = not dealing
    Notify(dealing and 'Dealing mode ON — approach someone and press [E].'
        or 'Dealing mode OFF.', dealing and 'info' or 'inform', 3500)
end, false)

CreateThread(function()
    while true do
        local wait = 800
        if dealing then
            wait = 0
            local ped, dist = findBuyerPed()
            if ped and dist and dist <= Config.Sell.offerDistance then
                lib.showTextUI('[E] Offer a deal', { position = 'bottom-center' })
                if IsControlJustPressed(0, Config.Sell.offerKey) then
                    lib.hideTextUI()
                    doDeal(ped)
                end
            else
                lib.hideTextUI()
            end
        else
            lib.hideTextUI()
        end
        Wait(wait)
    end
end)

-- ─── Joint smoking ──────────────────────────────────────────────────

RegisterNetEvent('distortionz_weedfarm:client:smoke', function()
    local useScully = Config.Joint.emote
        and GetResourceState('scully_emotemenu') == 'started'

    if useScully then
        pcall(function()
            exports.scully_emotemenu:playEmoteByCommand(Config.Joint.emote)
        end)
    else
        local anim = Config.Joint.smokeAnim
        if LoadAnimDict(anim.dict) then
            TaskPlayAnim(cache.ped, anim.dict, anim.clip, 4.0, -4.0, -1, 49, 0.0, false, false, false)
        end
    end

    CreateThread(function()
        for _ = 1, Config.Joint.cycles do
            Wait(Config.Joint.intervalMs)
            local amount = math.random(Config.Joint.relief.min, Config.Joint.relief.max)
            TriggerServerEvent('hud:server:RelieveStress', amount)
        end
        if useScully then
            pcall(function() exports.scully_emotemenu:cancelEmote() end)
        else
            ClearPedTasks(cache.ped)
        end
    end)
end)

-- ─── Police heat receiver ───────────────────────────────────────────

RegisterNetEvent('distortionz_weedfarm:client:heat', function(payload)
    if not payload then return end

    Notify(('%s — %s'):format(payload.code or '10-66', payload.label or 'Narcotics activity'),
        'police', 9000)

    if payload.coords then
        local b = AddBlipForCoord(payload.coords.x, payload.coords.y, payload.coords.z)
        SetBlipSprite(b, 51)
        SetBlipColour(b, 1)
        SetBlipScale(b, 0.9)
        SetBlipAsShortRange(b, false)
        SetBlipFlashes(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(payload.label or 'Narcotics activity')
        EndTextCommandSetBlipName(b)
        SetTimeout(60000, function()
            if DoesBlipExist(b) then RemoveBlip(b) end
        end)
    end
end)

-- ─── Cleanup ────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i = 1, #Config.Field.plants do
        clearPlant(i)
    end
    lib.hideTextUI()
    if IsEntityPlayingAnim(cache.ped, Config.Joint.smokeAnim.dict, Config.Joint.smokeAnim.clip, 3) then
        ClearPedTasks(cache.ped)
    end
end)
