--!strict
--[[
	InventoryServer
	================

	Script de arranque del servidor: conecta el ciclo de vida de los
	jugadores con InventoryService y expone la API remota.

	Regla de oro de toda esta capa: el cliente nunca decide cantidades ni
	identidades de item. Cada remota valida el TIPO de lo que llega y
	delega la decisión de "cuánto"/"si es válido" a InventoryService, que
	a su vez consulta el ItemDatabase del servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryService = require(script.Parent.InventoryService)
local InventoryCore = require(ReplicatedStorage.Shared.Inventory.InventoryCore)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local requestInventoryRemote = remotesFolder:WaitForChild("RequestInventory") :: RemoteFunction
local inventoryUpdatedRemote = remotesFolder:WaitForChild("InventoryUpdated") :: RemoteEvent
local useItemRemote = remotesFolder:WaitForChild("UseItem") :: RemoteEvent

local AUTOSAVE_INTERVAL_SECONDS = 60

local function pushInventory(player: Player)
	local snapshot = InventoryService.GetInventorySnapshot(player.UserId)
	if snapshot then
		inventoryUpdatedRemote:FireClient(player, snapshot)
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	local profile, err = InventoryService.LoadProfile(player.UserId)
	if not profile then
		warn(`no se pudo cargar el inventario de {player.Name} ({player.UserId}): {tostring(err)}`)
		player:Kick("No se pudo cargar tu inventario. Vuelve a intentarlo en unos segundos.")
		return
	end
	pushInventory(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	InventoryService.ReleaseProfile(player.UserId)
end)

-- El cliente solo puede pedir SU PROPIO estado; el servidor decide qué
-- hay en él, el cliente no manda ningún dato aquí.
requestInventoryRemote.OnServerInvoke = function(player: Player): InventoryCore.SerializedInventory?
	return InventoryService.GetInventorySnapshot(player.UserId)
end

-- El cliente solo indica QUÉ item quiere usar (una identidad, un string).
-- Cuánto se consume y si es siquiera un item válido lo decide siempre el
-- servidor a través de InventoryService/ItemDatabase.
useItemRemote.OnServerEvent:Connect(function(player: Player, itemIdArgument: unknown)
	if type(itemIdArgument) ~= "string" then
		warn(`{player.Name} envió un itemId con tipo inválido a UseItem`)
		return
	end

	local ok, err = InventoryService.UseItem(player.UserId, itemIdArgument)
	if ok then
		pushInventory(player)
	else
		warn(`{player.Name} no pudo usar '{itemIdArgument}': {tostring(err)}`)
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in Players:GetPlayers() do
			local ok, err = InventoryService.SaveProfile(player.UserId)
			if not ok then
				warn(`autoguardado fallido para {player.Name}: {tostring(err)}`)
			end
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		InventoryService.ReleaseProfile(player.UserId)
	end
	-- Da margen a las peticiones UpdateAsync del release para completarse
	-- antes de que el servidor se apague del todo (no aplica en Studio).
	if not RunService:IsStudio() then
		task.wait(1)
	end
end)
