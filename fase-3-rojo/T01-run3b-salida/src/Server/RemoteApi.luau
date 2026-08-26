--!strict

--[[
	RemoteApi
	=========
	Expone la API remota al cliente. Toda decisión sobre QUÉ item y
	QUÉ cantidad se mueve la toma el servidor:

	- El cliente nunca envía un itemId ni una cantidad que el servidor
	  vaya a aceptar sin más: solo referencia "mi slot N" (para usar o
	  soltar algo que ya es suyo) o un identificador de recogida fijo
	  definido en `pickupCatalog` (para recoger algo del mundo).
	- El servidor resuelve esas referencias contra el inventario real
	  del jugador o contra el catálogo, y solo entonces llama a
	  InventoryCore con la identidad y cantidad reales.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))

type Inventory = InventoryCore.Inventory

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestInventoryRemote = Remotes:WaitForChild("RequestInventory") :: RemoteFunction
local useItemRemote = Remotes:WaitForChild("UseItem") :: RemoteEvent
local dropItemRemote = Remotes:WaitForChild("DropItem") :: RemoteEvent
local pickupRequestRemote = Remotes:WaitForChild("PickupRequest") :: RemoteEvent
local inventoryUpdatedRemote = Remotes:WaitForChild("InventoryUpdated") :: RemoteEvent

export type PlayerInventoryGetter = (player: Player) -> Inventory?
export type PlayerInventorySetter = (player: Player, inventory: Inventory) -> ()

export type PickupDefinition = {
	itemId: InventoryCore.ItemId,
	quantity: number,
}

export type PickupCatalog = { [string]: PickupDefinition }

local RemoteApi = {}

-- Catálogo de recogidas: SOLO el servidor decide qué produce cada
-- identificador. El cliente únicamente indica cuál tocó.
local pickupCatalog: PickupCatalog = {
	pickup_potion_small = { itemId = "potion", quantity = 1 },
	pickup_coin_pile = { itemId = "coin", quantity = 25 },
	pickup_sword_common = { itemId = "sword", quantity = 1 },
}

local function notifyClient(player: Player, inventory: Inventory): ()
	inventoryUpdatedRemote:FireClient(player, InventoryCore.serialize(inventory))
end

function RemoteApi.Init(getInventory: PlayerInventoryGetter, setInventory: PlayerInventorySetter): ()
	requestInventoryRemote.OnServerInvoke = function(player: Player): InventoryCore.SerializedInventory?
		local inventory = getInventory(player)
		if inventory == nil then
			return nil
		end
		return InventoryCore.serialize(inventory)
	end

	-- El cliente solo aporta el índice de slot: la identidad y la
	-- cantidad a quitar las decide el servidor mirando ese slot.
	useItemRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any)
		if type(slotIndex) ~= "number" then
			return
		end
		local inventory = getInventory(player)
		if inventory == nil then
			return
		end

		local newInventory, outcome = InventoryCore.removeFromSlot(inventory, slotIndex, 1)
		if outcome.ok then
			setInventory(player, newInventory)
			notifyClient(player, newInventory)
		end
	end)

	-- El cliente propone una cantidad a soltar, pero el servidor la
	-- recorta a lo que realmente hay en ese slot.
	dropItemRemote.OnServerEvent:Connect(function(player: Player, slotIndex: any, requestedQuantity: any)
		if type(slotIndex) ~= "number" or type(requestedQuantity) ~= "number" then
			return
		end
		local inventory = getInventory(player)
		if inventory == nil then
			return
		end

		local slot = inventory.slots[slotIndex]
		if slot == nil then
			return
		end
		local safeQuantity = math.clamp(math.floor(requestedQuantity), 1, slot.quantity)

		local newInventory, outcome = InventoryCore.removeFromSlot(inventory, slotIndex, safeQuantity)
		if outcome.ok then
			setInventory(player, newInventory)
			notifyClient(player, newInventory)
		end
	end)

	-- El cliente solo dice qué recogida tocó; itemId y cantidad salen
	-- del catálogo del servidor, nunca del cliente.
	pickupRequestRemote.OnServerEvent:Connect(function(player: Player, pickupId: any)
		if type(pickupId) ~= "string" then
			return
		end
		local definition = pickupCatalog[pickupId]
		if definition == nil then
			return
		end
		local inventory = getInventory(player)
		if inventory == nil then
			return
		end

		local newInventory, outcome =
			InventoryCore.addItem(inventory, ItemCatalog, definition.itemId, definition.quantity)
		if outcome.added > 0 then
			setInventory(player, newInventory)
			notifyClient(player, newInventory)
		end
	end)
end

return RemoteApi
