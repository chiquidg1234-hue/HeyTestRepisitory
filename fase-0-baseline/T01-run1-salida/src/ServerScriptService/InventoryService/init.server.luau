--!strict
--[[
	init.server.luau

	Punto de entrada del servicio de inventario: conecta PlayerAdded /
	PlayerRemoving / BindToClose y expone la API remota con validacion
	completa en servidor. El cliente NUNCA decide cantidades ni identidades
	de item: solo puede pedir su estado y, como mucho, indicar el itemId
	que quiere "usar" (el servidor decide si es valido y cuanto se
	consume).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))

local InventoryServer = require(script:WaitForChild("InventoryServer"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local getInventoryRemote = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local useItemRemote = Remotes:WaitForChild("UseItem") :: RemoteEvent
local inventoryUpdatedRemote = Remotes:WaitForChild("InventoryUpdated") :: RemoteEvent

local EMPTY_FALLBACK_PAYLOAD = InventoryCore.serialize(InventoryCore.new(1))

local service = InventoryServer.new()

local function pushSnapshot(player: Player)
	local snapshot = service:GetSerializedSnapshot(player.UserId)
	if snapshot ~= nil then
		inventoryUpdatedRemote:FireClient(player, snapshot)
	end
end

local function onPlayerAdded(player: Player)
	local outcome = service:LoadForUser(player.UserId)
	if not outcome.ok then
		warn(("[InventoryService] No se pudo cargar el inventario de %s: %s"):format(
			player.Name,
			outcome.errorMessage or "error desconocido"
		))
		player:Kick("No se pudo cargar tu inventario. Vuelve a intentarlo en unos minutos.")
		return
	end

	pushSnapshot(player)
end

local function onPlayerRemoving(player: Player)
	service:ReleaseForUser(player.UserId)
end

-- --- API remota ----------------------------------------------------------

-- El cliente pide su estado; el servidor es la unica fuente de verdad y
-- responde con SU copia serializada, nunca con nada que el cliente aporte.
getInventoryRemote.OnServerInvoke = function(player: Player): string
	local snapshot = service:GetSerializedSnapshot(player.UserId)
	if snapshot == nil then
		-- Condicion de carrera improbable (peticion antes de terminar de
		-- cargar): devolvemos un inventario vacio en vez de fallar.
		return EMPTY_FALLBACK_PAYLOAD
	end
	return snapshot
end

-- El cliente solo puede pedir "usar" un item por su IDENTIDAD (itemId).
-- Cualquier otro dato que el cliente intente colar se ignora: la cantidad
-- consumida la fija siempre InventoryServer:RequestUseItem en servidor.
useItemRemote.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" then
		return
	end

	local outcome = service:RequestUseItem(player.UserId, itemId)
	if not outcome.ok then
		warn(("[InventoryService] UseItem rechazado para %s (%s): %s"):format(
			player.Name,
			itemId,
			outcome.errorMessage or "error desconocido"
		))
	end

	pushSnapshot(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		service:ReleaseForUser(player.UserId)
	end
end)

-- Cubre el caso de recarga de script / jugadores ya presentes al arrancar.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
