--!strict

--[[
	InventoryServer.server.luau

	Punto de entrada del servidor: crea los RemoteEvents/RemoteFunction de
	inventario y valida en el servidor toda petición del cliente.

	Regla clave (requisito 3): el cliente NUNCA decide cantidades ni
	identidades de item. Como mucho puede enviar un id opaco (de una
	recogida del mundo, o de un item que ya posee); es siempre el
	servidor quien resuelve, a partir de sus propias tablas, qué itemId y
	qué quantity corresponden antes de tocar el inventario.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent.InventoryService)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local ItemDatabase = require(ReplicatedStorage.Shared.ItemDatabase)

type ItemId = Inventory.ItemId

type PickupDefinition = {
	itemId: ItemId,
	quantity: number,
}

-- Catálogo de recogidas del mundo, controlado 100% por el servidor. El
-- cliente solo puede enviar el id opaco de una recogida (p. ej. al pulsar
-- E junto a un cofre); nunca elige item ni cantidad.
local PickupDefinitions: { [string]: PickupDefinition } = {
	ForestChest = { itemId = "Wood", quantity = 5 },
	QuarryVein = { itemId = "Stone", quantity = 3 },
	StarterSword = { itemId = "IronSword", quantity = 1 },
	SmallPotionPickup = { itemId = "HealthPotion", quantity = 1 },
}

-- La cantidad que se suelta por cada petición de "drop" también la decide
-- el servidor: nunca viene del cliente.
local DROP_QUANTITY = 1

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local getInventoryFunction = Instance.new("RemoteFunction")
getInventoryFunction.Name = "GetInventory"
getInventoryFunction.Parent = remotesFolder

local requestPickupEvent = Instance.new("RemoteEvent")
requestPickupEvent.Name = "RequestPickup"
requestPickupEvent.Parent = remotesFolder

local requestDropEvent = Instance.new("RemoteEvent")
requestDropEvent.Name = "RequestDrop"
requestDropEvent.Parent = remotesFolder

local inventoryChangedEvent = Instance.new("RemoteEvent")
inventoryChangedEvent.Name = "InventoryChanged"
inventoryChangedEvent.Parent = remotesFolder

local function pushInventory(player: Player)
	local serialized = InventoryService.getSerializedInventory(player.UserId)
	if serialized ~= nil then
		inventoryChangedEvent:FireClient(player, serialized)
	end
end

getInventoryFunction.OnServerInvoke = function(player: Player): Inventory.SerializedInventory?
	return InventoryService.getSerializedInventory(player.UserId)
end

requestPickupEvent.OnServerEvent:Connect(function(player: Player, ...: any)
	local rawPickupId = ...
	if typeof(rawPickupId) ~= "string" then
		return
	end

	local pickup = PickupDefinitions[rawPickupId]
	if pickup == nil then
		return
	end

	-- itemId y quantity salen siempre de PickupDefinitions (servidor),
	-- jamás de lo que haya mandado el cliente.
	local success = InventoryService.addItem(player.UserId, pickup.itemId, pickup.quantity)
	if success then
		pushInventory(player)
	end
end)

requestDropEvent.OnServerEvent:Connect(function(player: Player, ...: any)
	local rawItemId = ...
	if typeof(rawItemId) ~= "string" then
		return
	end
	if ItemDatabase[rawItemId] == nil then
		return
	end

	-- La cantidad NUNCA viene del cliente: siempre es DROP_QUANTITY.
	local success = InventoryService.removeItem(player.UserId, rawItemId, DROP_QUANTITY)
	if success then
		pushInventory(player)
	end
end)

InventoryService.init()
