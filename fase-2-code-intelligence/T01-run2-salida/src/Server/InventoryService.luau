--!strict

--[[
	InventoryService.luau

	Capa de servidor: mantiene los inventarios de los jugadores en memoria
	(usando el núcleo puro de Inventory.luau) y los persiste en un
	DataStore, con un bloqueo de sesión (session lock) para que dos
	servidores distintos no puedan escribir el mismo perfil a la vez
	(por ejemplo durante un teleport entre servidores o un despliegue con
	servidores solapados).

	El bloqueo funciona por "claim and release": al cargar un perfil se
	intenta reclamar escribiendo {serverId, updatedAt} de forma atómica
	con UpdateAsync; si otro servidor activo ya lo tiene (mismo campo con
	timestamp reciente), la carga falla. Al guardar se libera el bloqueo
	explícitamente, y si nadie lo libera (crash del servidor) expira solo
	pasado SESSION_LOCK_TIMEOUT_SECONDS.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local ItemDatabase = require(ReplicatedStorage.Shared.ItemDatabase)

type InventoryState = Inventory.InventoryState
type SerializedInventory = Inventory.SerializedInventory
type ItemId = Inventory.ItemId

local InventoryService = {}

local INVENTORY_STORE_NAME = "PlayerInventory_v1"
local DEFAULT_CAPACITY = 30
local SESSION_LOCK_TIMEOUT_SECONDS = 90
local AUTOSAVE_INTERVAL_SECONDS = 60
local MAX_RETRIES = 5

local dataStore = DataStoreService:GetDataStore(INVENTORY_STORE_NAME)

-- Identificador único de este servidor. game.JobId está vacío en Studio,
-- así que en ese caso generamos un GUID para no colisionar con otras
-- sesiones de Studio abiertas a la vez.
local serverId: string = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

type SessionLock = {
	serverId: string,
	updatedAt: number,
}

type PersistedProfile = {
	inventory: SerializedInventory,
	sessionLock: SessionLock,
}

type Profile = {
	userId: number,
	inventory: InventoryState,
	sessionLock: SessionLock,
	loaded: boolean,
	dirty: boolean,
}

local profiles: { [number]: Profile } = {}

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

-- Reintenta una llamada UpdateAsync con backoff simple. Devuelve
-- (ok, resultadoOError).
local function updateWithRetries(key: string, transform: (any) -> any): (boolean, any)
	local attempt = 0
	local lastError: any = nil
	while attempt < MAX_RETRIES do
		attempt += 1
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt * 0.5)
	end
	return false, lastError
end

-- Transform de UpdateAsync usado al cargar: crea el perfil si no existe,
-- o reclama el bloqueo de sesión si está libre/expirado. Si otro servidor
-- activo lo tiene, devuelve nil para abortar la escritura.
local function claimTransform(raw: any): any
	if raw == nil then
		local fresh: PersistedProfile = {
			inventory = Inventory.serialize(Inventory.new(DEFAULT_CAPACITY)),
			sessionLock = { serverId = serverId, updatedAt = os.time() },
		}
		return fresh
	end

	local existing = raw :: PersistedProfile
	local lock = existing.sessionLock
	local lockedByOtherActiveServer = lock ~= nil
		and lock.serverId ~= serverId
		and (os.time() - lock.updatedAt) < SESSION_LOCK_TIMEOUT_SECONDS

	if lockedByOtherActiveServer then
		return nil
	end

	existing.sessionLock = { serverId = serverId, updatedAt = os.time() }
	return existing
end

--- Carga (y reclama) el perfil de `userId`. Si ya está cargado en memoria,
--- no vuelve a golpear el DataStore. Falla si otro servidor activo tiene
--- el bloqueo de sesión, o si los datos guardados están corruptos.
function InventoryService.loadProfile(userId: number): (boolean, string?)
	local cached = profiles[userId]
	if cached ~= nil and cached.loaded then
		return true, nil
	end

	local ok, result = updateWithRetries(keyFor(userId), claimTransform)
	if not ok then
		return false, "datastore error: " .. tostring(result)
	end
	if result == nil then
		return false, "profile is locked by another server"
	end

	local persisted = result :: PersistedProfile
	local inventoryState, err = Inventory.deserialize(persisted.inventory, ItemDatabase)
	if inventoryState == nil then
		return false, "corrupt inventory data: " .. tostring(err)
	end

	profiles[userId] = {
		userId = userId,
		inventory = inventoryState,
		sessionLock = persisted.sessionLock,
		loaded = true,
		dirty = false,
	}

	return true, nil
end

local function makeSaveTransform(profile: Profile, releaseLock: boolean): (any) -> any
	return function(raw: any): any
		if raw ~= nil then
			local existing = raw :: PersistedProfile
			local lock = existing.sessionLock
			if lock ~= nil and lock.serverId ~= serverId then
				-- Otro servidor reclamó el perfil mientras tanto: no lo pisamos.
				return nil
			end
		end

		local nextLock: SessionLock
		if releaseLock then
			nextLock = { serverId = "", updatedAt = 0 }
		else
			nextLock = { serverId = serverId, updatedAt = os.time() }
		end

		local persisted: PersistedProfile = {
			inventory = Inventory.serialize(profile.inventory),
			sessionLock = nextLock,
		}
		return persisted
	end
end

--- Guarda el perfil de `userId` en el DataStore. Si `releaseLock` es true,
--- libera el bloqueo de sesión para que otro servidor pueda reclamarlo de
--- inmediato (se usa al desconectar al jugador o al cerrar el servidor).
function InventoryService.saveProfile(userId: number, releaseLock: boolean?): (boolean, string?)
	local profile = profiles[userId]
	if profile == nil then
		return false, "profile not loaded"
	end

	local ok, result = updateWithRetries(keyFor(userId), makeSaveTransform(profile, releaseLock == true))
	if not ok then
		return false, "datastore error: " .. tostring(result)
	end
	if result == nil then
		return false, "lock lost to another server; save skipped"
	end

	profile.dirty = false
	return true, nil
end

--- Devuelve una copia serializada del inventario de `userId`, o nil si su
--- perfil no está cargado en este servidor.
function InventoryService.getSerializedInventory(userId: number): SerializedInventory?
	local profile = profiles[userId]
	if profile == nil then
		return nil
	end
	return Inventory.serialize(profile.inventory)
end

--- Añade un item al inventario de `userId`. `itemId` y `quantity` deben
--- venir siempre de código de servidor de confianza (nunca directamente
--- de lo que envíe el cliente por un remoto).
function InventoryService.addItem(userId: number, itemId: ItemId, quantity: number): (boolean, number, string?)
	local profile = profiles[userId]
	if profile == nil then
		return false, 0, "profile not loaded"
	end

	local success, added, err = Inventory.addItem(profile.inventory, ItemDatabase, itemId, quantity)
	if added > 0 then
		profile.dirty = true
	end
	return success, added, err
end

--- Quita un item del inventario de `userId`.
function InventoryService.removeItem(userId: number, itemId: ItemId, quantity: number): (boolean, number, string?)
	local profile = profiles[userId]
	if profile == nil then
		return false, 0, "profile not loaded"
	end

	local success, removed, err = Inventory.removeItem(profile.inventory, itemId, quantity)
	if removed > 0 then
		profile.dirty = true
	end
	return success, removed, err
end

--- Arranca los listeners de ciclo de vida de jugador y el autoguardado.
--- Debe llamarse una única vez, desde un Script del servidor.
function InventoryService.init()
	Players.PlayerAdded:Connect(function(player: Player)
		local ok, err = InventoryService.loadProfile(player.UserId)
		if not ok then
			warn(string.format("[InventoryService] no se pudo cargar el perfil de %s: %s", player.Name, tostring(err)))
			player:Kick("No se pudo cargar tu inventario. Vuelve a intentarlo en unos segundos.")
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		InventoryService.saveProfile(player.UserId, true)
		profiles[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			for userId, profile in pairs(profiles) do
				if profile.dirty then
					InventoryService.saveProfile(userId, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		for userId in pairs(profiles) do
			InventoryService.saveProfile(userId, true)
		end
	end)
end

return InventoryService
