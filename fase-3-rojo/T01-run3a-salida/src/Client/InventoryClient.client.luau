--!strict
--[[
	InventoryClient
	================

	Capa de cliente mínima: pide al servidor el estado del inventario y lo
	muestra por `print`. No contiene ninguna lógica de negocio: el cliente
	nunca calcula cantidades ni decide qué items existen, solo pinta lo
	que el servidor le manda.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryCore = require(ReplicatedStorage.Shared.Inventory.InventoryCore)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local requestInventoryRemote = remotesFolder:WaitForChild("RequestInventory") :: RemoteFunction
local inventoryUpdatedRemote = remotesFolder:WaitForChild("InventoryUpdated") :: RemoteEvent

local localPlayer = Players.LocalPlayer

local function printInventory(snapshot: InventoryCore.SerializedInventory)
	print(`--- Inventario de {localPlayer.Name} ({#snapshot.slots}/{snapshot.capacity} ranuras) ---`)
	if #snapshot.slots == 0 then
		print("(vacío)")
	end
	for index, slot in snapshot.slots do
		print(`[{index}] {slot.itemId} x{slot.quantity}`)
	end
end

local function requestAndPrintInventory()
	local ok, result = pcall(function()
		return requestInventoryRemote:InvokeServer()
	end)

	if not ok then
		warn(`fallo al pedir el inventario al servidor: {tostring(result)}`)
		return
	end

	if result == nil then
		warn("el servidor no tiene un inventario cargado todavía para este jugador")
		return
	end

	printInventory(result :: InventoryCore.SerializedInventory)
end

-- El servidor empuja el inventario cada vez que cambia (p. ej. tras usar
-- un item); simplemente lo volvemos a imprimir.
inventoryUpdatedRemote.OnClientEvent:Connect(function(snapshot: InventoryCore.SerializedInventory)
	printInventory(snapshot)
end)

requestAndPrintInventory()
