--!strict

--[[
	Capa de cliente mínima: pide el estado del inventario al servidor
	y lo muestra por print. No decide cantidades ni identidades de
	item; solo lee y muestra lo que el servidor le da.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestInventoryRemote = Remotes:WaitForChild("RequestInventory") :: RemoteFunction
local inventoryUpdatedRemote = Remotes:WaitForChild("InventoryUpdated") :: RemoteEvent

local function printInventory(serialized: InventoryCore.SerializedInventory?): ()
	if serialized == nil then
		print("[Inventario] no disponible todavía")
		return
	end

	print(("[Inventario] %d/%d slots ocupados"):format(#serialized.slots, serialized.capacitySlots))
	for _, entry in ipairs(serialized.slots) do
		print(("  slot %d: %s x%d"):format(entry.slot, entry.itemId, entry.quantity))
	end
end

local function requestAndPrint(): ()
	local serialized = requestInventoryRemote:InvokeServer() :: InventoryCore.SerializedInventory?
	printInventory(serialized)
end

inventoryUpdatedRemote.OnClientEvent:Connect(function(serialized: InventoryCore.SerializedInventory)
	printInventory(serialized)
end)

requestAndPrint()
