--!strict

--[[
	InventoryServer

	Punto de arranque del servidor: crea los remotos, conecta el ciclo de
	vida de los jugadores con InventoryManager y expone la API remota con
	validación completa. El cliente NUNCA decide cantidades ni identidades
	de item: como mucho propone qué item quiere usar, y el servidor decide
	si es válido y cuánto se consume.
]]

local Players = game:GetService("Players") :: Players
local ReplicatedStorage = game:GetService("ReplicatedStorage") :: Instance

local InventoryManager = require(script.Parent.InventoryManager)
local InventoryCore = require(game:GetService("ReplicatedStorage").Shared.InventoryCore)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

type SerializedInventory = InventoryCore.SerializedInventory

-- ============================================================================
-- Creación de los remotos
-- ============================================================================

local remotesFolder = Instance.new("Folder", ReplicatedStorage) :: Folder
remotesFolder.Name = Remotes.FOLDER_NAME

local getInventoryFunction = Instance.new("RemoteFunction", remotesFolder) :: RemoteFunction
getInventoryFunction.Name = Remotes.FUNCTIONS.GET_INVENTORY_SNAPSHOT

local useItemFunction = Instance.new("RemoteFunction", remotesFolder) :: RemoteFunction
useItemFunction.Name = Remotes.FUNCTIONS.USE_ITEM

local inventoryChangedEvent = Instance.new("RemoteEvent", remotesFolder) :: RemoteEvent
inventoryChangedEvent.Name = Remotes.EVENTS.INVENTORY_CHANGED

-- ============================================================================
-- Reglas de juego (SOLO el servidor las decide)
-- ============================================================================

-- Cantidad fija que se consume al "usar" un item consumible. El cliente
-- puede pedir usar un item, pero nunca decide cuántas unidades se gastan.
local USE_ITEM_QUANTITY = 1

-- Regalo de bienvenida al entrar; cantidad e identidad fijadas en servidor.
local WELCOME_ITEM_ID = "Wood"
local WELCOME_ITEM_QUANTITY = 5

local function pushSnapshot(player: Player): ()
	local snapshot = InventoryManager.getSnapshot(player.UserId)
	if snapshot ~= nil then
		inventoryChangedEvent:FireClient(player, snapshot)
	end
end

-- ============================================================================
-- Ciclo de vida del jugador
-- ============================================================================

Players.PlayerAdded:Connect(function(player: Player)
	local ok, err = InventoryManager.load(player.UserId)
	if not ok then
		warn(string.format("no se pudo cargar el inventario de %s: %s", player.Name, tostring(err)))
		player:Kick("No se pudo cargar tu inventario. Vuelve a intentarlo en unos segundos.")
		return
	end

	InventoryManager.addItem(player.UserId, WELCOME_ITEM_ID, WELCOME_ITEM_QUANTITY)
	pushSnapshot(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local ok, err = InventoryManager.unload(player.UserId)
	if not ok then
		warn(string.format("no se pudo descargar limpiamente el inventario de %s: %s", player.Name, tostring(err)))
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		InventoryManager.unload(player.UserId)
	end
end)

-- ============================================================================
-- Autoguardado periódico (también renueva el bloqueo de sesión)
-- ============================================================================

local AUTOSAVE_INTERVAL_SECONDS = 60

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in Players:GetPlayers() do
			local ok, err = InventoryManager.save(player.UserId)
			if not ok then
				warn(string.format("fallo al autoguardar el inventario de %s: %s", player.Name, tostring(err)))
			end
		end
	end
end)

-- ============================================================================
-- API remota, con validación completa en el servidor
-- ============================================================================

getInventoryFunction.OnServerInvoke = function(player: Player, ...: any): SerializedInventory?
	-- No se leen argumentos del cliente: el snapshot siempre es el del
	-- jugador que hace la llamada, tal y como lo tiene el servidor.
	if not InventoryManager.isLoaded(player.UserId) then
		return nil
	end
	return InventoryManager.getSnapshot(player.UserId)
end

useItemFunction.OnServerInvoke = function(player: Player, requestedItemId: any, ...: any): (boolean, string?)
	if typeof(requestedItemId) ~= "string" then
		return false, "identidad de item inválida"
	end
	local itemId = requestedItemId :: string

	if not InventoryManager.isLoaded(player.UserId) then
		return false, "inventario no cargado"
	end

	-- La cantidad NUNCA sale del cliente: siempre es USE_ITEM_QUANTITY.
	local ok, err = InventoryManager.removeItem(player.UserId, itemId, USE_ITEM_QUANTITY)
	if ok then
		pushSnapshot(player)
	end
	return ok, err
end
