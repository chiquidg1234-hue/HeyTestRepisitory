--!strict
--[[
	InventoryClient.client.luau

	Capa de cliente MINIMA: pide su estado de inventario al servidor y lo
	muestra por print. No calcula ni decide nada sobre cantidades o
	identidades de item: solo lee y muestra lo que el servidor le manda.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local getInventoryRemote = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local inventoryUpdatedRemote = Remotes:WaitForChild("InventoryUpdated") :: RemoteEvent

local function printInventory(serialized: string)
	local state, err = InventoryCore.deserialize(serialized)
	if state == nil then
		warn(("[InventoryClient] No se pudo leer el inventario: %s"):format(err or "error desconocido"))
		return
	end

	local usedSlots = state.capacity - InventoryCore.getFreeSlotCount(state)
	print(("[InventoryClient] Inventario (%d/%d slots usados):"):format(usedSlots, state.capacity))

	for index = 1, state.capacity do
		local slot = state.slots[index]
		if slot ~= nil then
			print(("  [%d] %s x%d"):format(index, slot.itemId, slot.quantity))
		end
	end
end

local function requestInventoryState()
	local ok, serializedOrErr = pcall(function()
		return getInventoryRemote:InvokeServer()
	end)

	if not ok then
		warn("[InventoryClient] Fallo al pedir el inventario: " .. tostring(serializedOrErr))
		return
	end

	printInventory(serializedOrErr :: string)
end

-- El servidor empuja el estado tras cargarlo y despues de cada accion
-- valida (p.ej. usar un item); el cliente solo refleja lo recibido.
inventoryUpdatedRemote.OnClientEvent:Connect(function(serialized: string)
	printInventory(serialized)
end)

requestInventoryState()
