local ESX = nil
local trunkOpen = false
local currentVehicle = nil
local trunkItems = {}

-- Configuration
local openKey = 182 -- Touche L
local maxTrunkWeight = {
    [0] = 10000, -- Compact
    [1] = 15000, -- Sedan
    [2] = 20000, -- SUV
    [3] = 10000, -- Coupes
    [4] = 15000, -- Muscle
    [5] = 10000, -- Sports Classic
    [6] = 10000, -- Sports
    [7] = 5000,  -- Super
    [8] = 5000,  -- Motorbike
    [9] = 30000, -- Off-road
    [10] = 40000, -- Industrial
    [11] = 35000, -- Utility
    [12] = 50000, -- Van
    [13] = 0,    -- Bike
    [14] = 0,    -- Boat
    [15] = 0,    -- Helicopter
    [16] = 0,    -- Plane
    [17] = 35000, -- Service
    [18] = 35000, -- Emergency
    [19] = 50000, -- Military
    [20] = 50000  -- Commercial
}

-- Fonctions utilitaires
function table.length(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Charger ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Fonction pour ouvrir/fermer le coffre
local function toggleTrunk()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = ESX.Game.GetClosestVehicle(coords)
    
    if vehicle ~= nil and vehicle ~= 0 then
        local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.5, 0)
        
        if #(coords - trunkpos) < 2.0 then
            local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
            local vehClass = GetVehicleClass(vehicle)
            local maxWeight = maxTrunkWeight[vehClass] or 20000
            
            if not trunkOpen then
                -- Ouvrir le coffre
                SetVehicleDoorOpen(vehicle, 5, false, false)
                TriggerServerEvent('esx_vehicletrunk:loadTrunk', plate)
                
                -- Créer le menu
                openTrunkMenu(plate, maxWeight)
                trunkOpen = true
                currentVehicle = vehicle
            else
                -- Fermer le coffre
                SetVehicleDoorShut(vehicle, 5, false)
                trunkOpen = false
                currentVehicle = nil
                ESX.UI.Menu.CloseAll()
            end
        else
            ESX.ShowNotification('Vous devez être près du coffre')
        end
    else
        ESX.ShowNotification('Aucun véhicule à proximité')
    end
end

-- Fonction pour créer le menu du coffre
function openTrunkMenu(plate, maxWeight)
    ESX.TriggerServerCallback('esx_vehicletrunk:getTrunkMoney', function(cleanMoney, dirtyMoney)
        local elements = {
            {label = 'Déposer un objet', value = 'deposit_item'},
            {label = ('Retirer un objet (%s objets)'):format(table.length(trunkItems)), value = 'withdraw_item'},
            {label = ('Déposer argent propre ($%s)'):format(ESX.Math.GroupDigits(cleanMoney)), value = 'deposit_clean'},
            {label = ('Retirer argent propre ($%s)'):format(ESX.Math.GroupDigits(cleanMoney)), value = 'withdraw_clean'},
            {label = ('Déposer argent sale ($%s)'):format(ESX.Math.GroupDigits(dirtyMoney)), value = 'deposit_dirty'},
            {label = ('Retirer argent sale ($%s)'):format(ESX.Math.GroupDigits(dirtyMoney)), value = 'withdraw_dirty'},
            {label = 'Fermer le coffre', value = 'close_trunk'}
        }
        
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_trunk_main',
        {
            title = 'Coffre - '..plate,
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'deposit_item' then
                menu.close()
                openDepositMenu(plate, function() 
                    openTrunkMenu(plate, maxWeight) 
                end)
            elseif data.current.value == 'withdraw_item' then
                menu.close()
                openWithdrawMenu(plate, function() 
                    openTrunkMenu(plate, maxWeight) 
                end)
            elseif data.current.value == 'deposit_clean' then
                menu.close()
                depositMoney(plate, 'clean', function() 
                    openTrunkMenu(plate, maxWeight) 
                end)
            elseif data.current.value == 'withdraw_clean' then
                menu.close()
                withdrawMoney(plate, 'clean', function() 
                    openTrunkMenu(plate, maxWeight) 
                end)
            elseif data.current.value == 'deposit_dirty' then
                menu.close()
                depositMoney(plate, 'dirty', function() 
                    openTrunkMenu(plate, maxWeight) 
                end)
            elseif data.current.value == 'withdraw_dirty' then
                menu.close()
                withdrawMoney(plate, 'dirty', function() 
                    openTrunkMenu(plate, maxWeight) 
                end)
            elseif data.current.value == 'close_trunk' then
                menu.close()
                if currentVehicle then
                    SetVehicleDoorShut(currentVehicle, 5, false)
                end
                trunkOpen = false
                currentVehicle = nil
            end
        end, function(data, menu)
            menu.close()
            if currentVehicle then
                SetVehicleDoorShut(currentVehicle, 5, false)
            end
            trunkOpen = false
            currentVehicle = nil
        end)
    end, plate)
end

-- Fonction pour le menu de dépôt d'items
function openDepositMenu(plate, cb)
    ESX.TriggerServerCallback('esx_vehicletrunk:getPlayerInventory', function(inventory)
        local elements = {}
        
        for i=1, #inventory.items, 1 do
            local item = inventory.items[i]
            
            if item.count > 0 then
                table.insert(elements, {
                    label = ('%s x%s'):format(item.label, ESX.Math.GroupDigits(item.count)),
                    value = item.name,
                    count = item.count
                })
            end
        end
        
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'trunk_deposit_item',
        {
            title = 'Déposer un objet',
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            local itemName = data.current.value
            local maxCount = data.current.count
            
            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'trunk_deposit_item_count', {
                title = ('Quantité à déposer (max: %s)'):format(ESX.Math.GroupDigits(maxCount))
            }, function(data2, menu2)
                local count = tonumber(data2.value)
                
                if count and count > 0 and count <= maxCount then
                    menu2.close()
                    menu.close()
                    TriggerServerEvent('esx_vehicletrunk:depositItem', plate, itemName, count, function()
                        if cb then cb() end
                    end)
                else
                    ESX.ShowNotification(('Quantité invalide. Maximum: %s'):format(ESX.Math.GroupDigits(maxCount)))
                end
            end, function(data2, menu2)
                menu2.close()
                if cb then cb() end
            end)
        end, function(data, menu)
            menu.close()
            if cb then cb() end
        end)
    end)
end

-- Fonction pour le menu de retrait d'items
function openWithdrawMenu(plate, cb)
    if not trunkItems or table.length(trunkItems) == 0 then
        ESX.ShowNotification('Le coffre est vide')
        if cb then cb() end
        return
    end

    local elements = {}
    
    for itemName, count in pairs(trunkItems) do
        if count > 0 then
            table.insert(elements, {
                label = ('%s x%d'):format(itemName, count),
                value = itemName,
                count = count
            })
        end
    end
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'trunk_withdraw_item',
    {
        title = 'Retirer un objet',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        local itemName = data.current.value
        local maxCount = data.current.count
        
        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'trunk_withdraw_item_count', {
            title = ('Quantité à retirer (max: %d)'):format(maxCount)
        }, function(data2, menu2)
            local count = tonumber(data2.value)
            
            if count and count > 0 and count <= maxCount then
                menu2.close()
                menu.close()
                TriggerServerEvent('esx_vehicletrunk:withdrawItem', plate, itemName, count, function()
                    if cb then cb() end
                end)
            else
                ESX.ShowNotification(('Quantité invalide. Maximum: %d'):format(maxCount))
            end
        end, function(data2, menu2)
            menu2.close()
        end)
    end, function(data, menu)
        menu.close()
        if cb then cb() end
    end)
end

-- Fonction pour déposer de l'argent
function depositMoney(plate, moneyType, cb)
    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'trunk_deposit_money', {
        title = 'Montant à déposer'
    }, function(data, menu)
        local amount = tonumber(data.value)
        
        if amount and amount > 0 then
            menu.close()
            TriggerServerEvent('esx_vehicletrunk:depositMoney', plate, amount, moneyType, function()
                if cb then cb() end
            end)
        else
            ESX.ShowNotification('Montant invalide')
        end
    end, function(data, menu)
        menu.close()
        if cb then cb() end
    end)
end

-- Fonction pour retirer de l'argent
function withdrawMoney(plate, moneyType, cb)
    ESX.TriggerServerCallback('esx_vehicletrunk:getTrunkMoney', function(cleanMoney, dirtyMoney)
        local maxAmount = (moneyType == 'clean') and cleanMoney or dirtyMoney
        local moneyLabel = (moneyType == 'clean') and 'propre' or 'sale'
        
        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'trunk_withdraw_money', {
            title = ('Montant à retirer (max: $%s)'):format(ESX.Math.GroupDigits(maxAmount))
        }, function(data, menu)
            local amount = tonumber(data.value)
            
            if amount and amount > 0 and amount <= maxAmount then
                menu.close()
                TriggerServerEvent('esx_vehicletrunk:withdrawMoney', plate, amount, moneyType, function()
                    if cb then cb() end
                end)
            else
                ESX.ShowNotification(('Montant invalide. Maximum: $%s %s'):format(ESX.Math.GroupDigits(maxAmount), moneyLabel))
            end
        end, function(data, menu)
            menu.close()
            if cb then cb() end
        end)
    end, plate)
end

-- Gestion de la touche L
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustReleased(0, openKey) then
            toggleTrunk()
        end
    end
end)

-- Synchronisation avec le serveur
RegisterNetEvent('esx_vehicletrunk:setTrunk')
AddEventHandler('esx_vehicletrunk:setTrunk', function(items)
    trunkItems = items or {}
end)

-- Nettoyage quand le joueur quitte
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and trunkOpen and currentVehicle then
        SetVehicleDoorShut(currentVehicle, 5, false)
    end
end)

-- Fonction pour rafraîchir le coffre
function refreshTrunk(plate)
    TriggerServerEvent('esx_vehicletrunk:refreshTrunk', plate)
end