local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Callback pour récupérer l'argent du coffre
ESX.RegisterServerCallback('esx_vehicletrunk:getTrunkMoney', function(source, cb, plate)
    MySQL.Async.fetchAll('SELECT clean_money, dirty_money FROM vehicle_trunks WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result[1] then
            cb(result[1].clean_money or 0, result[1].dirty_money or 0)
        else
            cb(0, 0)
        end
    end)
end)

-- Événement pour charger le contenu du coffre
RegisterNetEvent('esx_vehicletrunk:loadTrunk')
AddEventHandler('esx_vehicletrunk:loadTrunk', function(plate)
    local src = source
    MySQL.Async.fetchScalar('SELECT items FROM vehicle_trunks WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result then
            TriggerClientEvent('esx_vehicletrunk:setTrunk', src, json.decode(result))
        else
            -- Créer une entrée vide si le véhicule n'existe pas encore
            MySQL.Async.execute('INSERT INTO vehicle_trunks (plate, items, clean_money, dirty_money) VALUES (@plate, @items, 0, 0)', {
                ['@plate'] = plate,
                ['@items'] = json.encode({})
            }, function()
                TriggerClientEvent('esx_vehicletrunk:setTrunk', src, {})
            end)
        end
    end)
end)

-- Gestion de l'argent propre (avec callback)
RegisterNetEvent('esx_vehicletrunk:depositMoney')
AddEventHandler('esx_vehicletrunk:depositMoney', function(plate, amount, moneyType, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    amount = ESX.Math.Round(tonumber(amount))
    
    if moneyType == 'clean' then
        if xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount)
            MySQL.Async.execute('UPDATE vehicle_trunks SET clean_money = clean_money + @amount WHERE plate = @plate', {
                ['@plate'] = plate,
                ['@amount'] = amount
            }, function()
                TriggerClientEvent('esx:showNotification', src, ('Vous avez déposé $%s propre'):format(ESX.Math.GroupDigits(amount)))
                if cb then cb() end
            end)
        else
            TriggerClientEvent('esx:showNotification', src, 'Vous n\'avez pas assez d\'argent propre')
            if cb then cb() end
        end
    elseif moneyType == 'dirty' then
        if xPlayer.getAccount('black_money').money >= amount then
            xPlayer.removeAccountMoney('black_money', amount)
            MySQL.Async.execute('UPDATE vehicle_trunks SET dirty_money = dirty_money + @amount WHERE plate = @plate', {
                ['@plate'] = plate,
                ['@amount'] = amount
            }, function()
                TriggerClientEvent('esx:showNotification', src, ('Vous avez déposé $%s sale'):format(ESX.Math.GroupDigits(amount)))
                if cb then cb() end
            end)
        else
            TriggerClientEvent('esx:showNotification', src, 'Vous n\'avez pas assez d\'argent sale')
            if cb then cb() end
        end
    end
end)

-- Gestion du retrait d'argent (avec callback)
RegisterNetEvent('esx_vehicletrunk:withdrawMoney')
AddEventHandler('esx_vehicletrunk:withdrawMoney', function(plate, amount, moneyType, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    amount = ESX.Math.Round(tonumber(amount))
    
    if moneyType == 'clean' then
        MySQL.Async.fetchScalar('SELECT clean_money FROM vehicle_trunks WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(currentAmount)
            if currentAmount and currentAmount >= amount then
                xPlayer.addMoney(amount)
                MySQL.Async.execute('UPDATE vehicle_trunks SET clean_money = clean_money - @amount WHERE plate = @plate', {
                    ['@plate'] = plate,
                    ['@amount'] = amount
                }, function()
                    TriggerClientEvent('esx:showNotification', src, ('Vous avez retiré $%s propre'):format(ESX.Math.GroupDigits(amount)))
                    if cb then cb() end
                end)
            else
                TriggerClientEvent('esx:showNotification', src, 'Pas assez d\'argent propre dans le coffre')
                if cb then cb() end
            end
        end)
    elseif moneyType == 'dirty' then
        MySQL.Async.fetchScalar('SELECT dirty_money FROM vehicle_trunks WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(currentAmount)
            if currentAmount and currentAmount >= amount then
                xPlayer.addAccountMoney('black_money', amount)
                MySQL.Async.execute('UPDATE vehicle_trunks SET dirty_money = dirty_money - @amount WHERE plate = @plate', {
                    ['@plate'] = plate,
                    ['@amount'] = amount
                }, function()
                    TriggerClientEvent('esx:showNotification', src, ('Vous avez retiré $%s sale'):format(ESX.Math.GroupDigits(amount)))
                    if cb then cb() end
                end)
            else
                TriggerClientEvent('esx:showNotification', src, 'Pas assez d\'argent sale dans le coffre')
                if cb then cb() end
            end
        end)
    end
end)

-- Gestion des items (dépôt avec callback)
RegisterNetEvent('esx_vehicletrunk:depositItem')
AddEventHandler('esx_vehicletrunk:depositItem', function(plate, itemName, count, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    count = tonumber(count)
    
    if count and count > 0 then
        local sourceItem = xPlayer.getInventoryItem(itemName)
        
        if sourceItem and sourceItem.count >= count then
            xPlayer.removeInventoryItem(itemName, count)
            
            MySQL.Async.fetchScalar('SELECT items FROM vehicle_trunks WHERE plate = @plate', {
                ['@plate'] = plate
            }, function(result)
                local items = json.decode(result) or {}
                items[itemName] = (items[itemName] or 0) + count
                
                MySQL.Async.execute('UPDATE vehicle_trunks SET items = @items WHERE plate = @plate', {
                    ['@plate'] = plate,
                    ['@items'] = json.encode(items)
                }, function()
                    TriggerClientEvent('esx_vehicletrunk:setTrunk', src, items)
                    TriggerClientEvent('esx:showNotification', src, ('Vous avez déposé %s %s'):format(count, itemName))
                    if cb then cb() end
                end)
            end)
        else
            TriggerClientEvent('esx:showNotification', src, 'Quantité invalide')
            if cb then cb() end
        end
    else
        TriggerClientEvent('esx:showNotification', src, 'Quantité invalide')
        if cb then cb() end
    end
end)

-- Gestion des items (retrait avec callback)
RegisterNetEvent('esx_vehicletrunk:withdrawItem')
AddEventHandler('esx_vehicletrunk:withdrawItem', function(plate, itemName, count, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    count = tonumber(count)
    
    if count and count > 0 then
        MySQL.Async.fetchScalar('SELECT items FROM vehicle_trunks WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(result)
            local items = json.decode(result) or {}
            
            if items[itemName] and items[itemName] >= count then
                local item = xPlayer.getInventoryItem(itemName)
                
                -- Vérification alternative pour les anciennes versions d'ESX
                if item.limit == -1 or (item.count + count) <= item.limit then
                    items[itemName] = items[itemName] - count
                    if items[itemName] <= 0 then
                        items[itemName] = nil
                    end
                    
                    xPlayer.addInventoryItem(itemName, count)
                    
                    MySQL.Async.execute('UPDATE vehicle_trunks SET items = @items WHERE plate = @plate', {
                        ['@plate'] = plate,
                        ['@items'] = json.encode(items)
                    }, function()
                        TriggerClientEvent('esx_vehicletrunk:setTrunk', src, items)
                        TriggerClientEvent('esx:showNotification', src, ('Vous avez retiré %s %s'):format(count, itemName))
                        if cb then cb() end
                    end)
                else
                    TriggerClientEvent('esx:showNotification', src, 'Vous ne pouvez pas porter plus de cet item')
                    if cb then cb() end
                end
            else
                TriggerClientEvent('esx:showNotification', src, 'Quantité invalide dans le coffre')
                if cb then cb() end
            end
        end)
    else
        TriggerClientEvent('esx:showNotification', src, 'Quantité invalide')
        if cb then cb() end
    end
end)

-- Callback pour l'inventaire du joueur
ESX.RegisterServerCallback('esx_vehicletrunk:getPlayerInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    cb({
        items = xPlayer.inventory
    })
end)

-- Événement pour rafraîchir le coffre
RegisterNetEvent('esx_vehicletrunk:refreshTrunk')
AddEventHandler('esx_vehicletrunk:refreshTrunk', function(plate)
    local src = source
    MySQL.Async.fetchScalar('SELECT items FROM vehicle_trunks WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(result)
        if result then
            TriggerClientEvent('esx_vehicletrunk:setTrunk', src, json.decode(result))
        end
    end)
end)