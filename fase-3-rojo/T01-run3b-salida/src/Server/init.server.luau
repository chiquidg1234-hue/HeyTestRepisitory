--!strict

--[[
	Bootstrap del servidor de inventario.

	- Carga el perfil de cada jugador con bloqueo de sesión al entrar.
	- Mantiene su inventario en memoria mientras está conectado.
	- Refresca el bloqueo periódicamente para que siga siendo válido.
	- Guarda y libera el bloqueo al salir o al cerrar el servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))

local InventoryService = require(script:WaitForChild("InventoryService"))
local RemoteApi = require(script:WaitForChild("RemoteApi"))

type Inventory = InventoryCore.Inventory

local LOCK_REFRESH_INTERVAL_SECONDS = 15

local playerInventories: { [Player]: Inventory } = {}

local function getInventory(player: Player): Inventory?
	return playerInventories[player]
end

local function setInventory(player: Player, inventory: Inventory): ()
	playerInventories[player] = inventory
end

local function saveAndRelease(player: Player): ()
	local inventory = playerInventories[player]
	if inventory == nil then
		return
	end
	playerInventories[player] = nil

	local result = InventoryService.SaveProfile(player.UserId, inventory, true)
	if not result.ok then
		warn(("No se pudo guardar el inventario de %s: %s"):format(player.Name, result.errorMessage))
	end
end

local function keepLockAlive(player: Player): ()
	while playerInventories[player] ~= nil do
		task.wait(LOCK_REFRESH_INTERVAL_SECONDS)
		local inventory = playerInventories[player]
		if inventory == nil then
			break
		end
		InventoryService.SaveProfile(player.UserId, inventory, false)
	end
end

local function onPlayerAdded(player: Player): ()
	local result = InventoryService.LoadProfile(player.UserId)
	if not result.ok then
		warn(("No se pudo cargar el inventario de %s: %s"):format(player.Name, result.errorMessage))
		player:Kick("No se pudo cargar tu inventario. Inténtalo de nuevo en unos minutos.")
		return
	end

	playerInventories[player] = result.inventory
	task.spawn(keepLockAlive, player)
end

RemoteApi.Init(getInventory, setInventory)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(saveAndRelease)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveAndRelease(player)
	end
end)
