--!strict

--[[
	InventoryClient.client.luau

	Capa de cliente mínima: pide el estado del inventario al servidor (por
	RemoteFunction y por push de RemoteEvent) y lo muestra por print. No
	decide ninguna cantidad ni identidad de item; solo consume y muestra lo
	que el servidor confirma.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getInventoryFunction = remotes:WaitForChild("GetInventory") :: RemoteFunction
local inventoryChangedEvent = remotes:WaitForChild("InventoryChanged") :: RemoteEvent

type SerializedStack = {
	itemId: string,
	quantity: number,
}

type SerializedInventory = {
	capacity: number,
	slots: { SerializedStack },
}

local function printInventory(inventory: SerializedInventory?)
	if inventory == nil then
		print("[InventoryClient] no se pudo obtener el inventario")
		return
	end

	print(string.format("[InventoryClient] Inventario (%d/%d slots):", #inventory.slots, inventory.capacity))
	for _, stack in ipairs(inventory.slots) do
		print(string.format("  - %s x%d", stack.itemId, stack.quantity))
	end
end

local function requestState()
	local ok, result = pcall(function()
		return getInventoryFunction:InvokeServer()
	end)
	if ok then
		printInventory(result :: SerializedInventory?)
	else
		warn("[InventoryClient] error al pedir el inventario: " .. tostring(result))
	end
end

inventoryChangedEvent.OnClientEvent:Connect(function(inventory: SerializedInventory)
	printInventory(inventory)
end)

requestState()
