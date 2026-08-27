--!strict

--[[
	InventoryClient

	Capa de cliente mínima: pide su estado de inventario al servidor y lo
	muestra por print. No decide cantidades ni identidades de item: como
	mucho propone una acción (p. ej. "usar Wood") que el servidor valida y
	resuelve por completo.
]]

local Players = game:GetService("Players") :: Players
local ReplicatedStorage = game:GetService("ReplicatedStorage") :: Instance

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local InventoryCore = require(game:GetService("ReplicatedStorage").Shared.InventoryCore)

type SerializedInventory = InventoryCore.SerializedInventory

local localPlayer = Players.LocalPlayer :: Player

-- El Folder de remotos lo crea el servidor en tiempo de ejecución, así que
-- aquí sí hace falta esperar a que aparezca (no es un require estático).
local remotesFolder = ReplicatedStorage:WaitForChild(Remotes.FOLDER_NAME) :: Instance
local getInventoryFunction = remotesFolder:WaitForChild(Remotes.FUNCTIONS.GET_INVENTORY_SNAPSHOT) :: RemoteFunction
local useItemFunction = remotesFolder:WaitForChild(Remotes.FUNCTIONS.USE_ITEM) :: RemoteFunction
local inventoryChangedEvent = remotesFolder:WaitForChild(Remotes.EVENTS.INVENTORY_CHANGED) :: RemoteEvent

local function printInventory(snapshot: SerializedInventory?): ()
	if snapshot == nil then
		print(string.format("[Inventario de %s] sin datos todavía", localPlayer.Name))
		return
	end

	print(
		string.format(
			"[Inventario de %s] capacidad=%d slots usados=%d",
			localPlayer.Name,
			snapshot.capacity,
			#snapshot.slots
		)
	)
	for _, slot in snapshot.slots do
		print(string.format("  - %s x%d", slot.itemId, slot.quantity))
	end
end

local function requestSnapshot(): ()
	local ok, result = pcall(function()
		return getInventoryFunction:InvokeServer()
	end)
	if ok then
		printInventory(result :: SerializedInventory?)
	else
		warn("no se pudo obtener el inventario: " .. tostring(result))
	end
end

-- El servidor empuja el estado tras cada cambio; el cliente solo lo imprime.
inventoryChangedEvent.OnClientEvent:Connect(function(...: any): ()
	local snapshot = ...
	printInventory(snapshot :: SerializedInventory)
end)

requestSnapshot()

-- Ejemplo: proponer usar un item. El cliente solo indica la identidad; el
-- servidor decide si es válido y cuánta cantidad se consume de verdad.
task.spawn(function()
	task.wait(2)
	local usedOk, usedErr = useItemFunction:InvokeServer("Wood")
	if usedOk then
		print("[Inventario] el servidor confirmó el uso de 1x Wood")
	else
		print("[Inventario] no se pudo usar Wood: " .. tostring(usedErr))
	end
end)
