--!strict

--[[
	ProfileStore

	Capa de persistencia sobre DataStoreService, con bloqueo de sesión: solo
	un servidor puede tener el perfil de un jugador "abierto" para escritura
	a la vez. Esto evita que dos servidores (p. ej. tras un teleport o una
	reconexión rápida) se pisen los mismos datos.

	El bloqueo se guarda DENTRO del propio registro del DataStore (campo
	`session`) y se reclama con UpdateAsync, que es atómico: dos servidores
	compitiendo por la misma clave nunca pueden "ganar" los dos a la vez.
	Si un servidor se cae sin liberar la sesión, esta expira sola pasado
	SESSION_TIMEOUT_SECONDS gracias al `lastHeartbeat`.
]]

local DataStoreService = game:GetService("DataStoreService") :: DataStoreService

local InventoryCore = require(game:GetService("ReplicatedStorage").Shared.InventoryCore)

type SerializedInventory = InventoryCore.SerializedInventory

export type SessionMeta = {
	jobId: string,
	placeId: number,
	lastHeartbeat: number,
}

export type StoredProfile = {
	inventory: SerializedInventory,
	session: SessionMeta?,
}

-- Si un servidor no renueva el heartbeat de su sesión en este tiempo (en
-- segundos), se considera abandonada y otro servidor puede reclamarla.
local SESSION_TIMEOUT_SECONDS = 120

local PROFILE_STORE_NAME = "InventoryProfiles_v1"
local DEFAULT_CAPACITY = 30

local profileStore: DataStore = DataStoreService:GetDataStore(PROFILE_STORE_NAME) :: DataStore

local ProfileStore = {}

local function keyForUser(userId: number): string
	return "Player_" .. tostring(userId)
end

local function now(): number
	return DateTime.now().UnixTimestamp
end

local function isSessionActive(session: SessionMeta?): boolean
	if session == nil then
		return false
	end
	return (now() - (session :: SessionMeta).lastHeartbeat) < SESSION_TIMEOUT_SECONDS
end

local function freshProfile(): StoredProfile
	return {
		inventory = InventoryCore.serialize(InventoryCore.new(DEFAULT_CAPACITY)),
		session = nil,
	}
end

-- Intenta reclamar, para ESTE servidor, la sesión del perfil de `userId`.
-- Devuelve el inventario serializado (creando uno nuevo la primera vez) o
-- nil + un motivo si otro servidor tiene la sesión activa o hay un error de
-- DataStore.
function ProfileStore.claimSession(userId: number): (SerializedInventory?, string?)
	local ok, updateResult = pcall(function(): StoredProfile
		local result = profileStore:UpdateAsync(keyForUser(userId), function(current: any): (any, { number }?, {}?)
			local stored: StoredProfile = if type(current) == "table" then current :: StoredProfile else freshProfile()

			if isSessionActive(stored.session) and (stored.session :: SessionMeta).jobId ~= game.JobId then
				error("SESSION_LOCKED")
			end

			stored.session = {
				jobId = game.JobId,
				placeId = game.PlaceId,
				lastHeartbeat = now(),
			}

			return stored, { userId }, nil
		end)
		return result :: StoredProfile
	end)

	if not ok then
		local message = tostring(updateResult)
		if string.find(message, "SESSION_LOCKED", 1, true) ~= nil then
			return nil, "el perfil está en uso por otro servidor"
		end
		return nil, "error de DataStore al reclamar la sesión: " .. message
	end

	local stored = updateResult :: StoredProfile
	local state, deserializeErr = InventoryCore.deserialize(stored.inventory)
	if state == nil then
		warn("perfil corrupto para " .. keyForUser(userId) .. ": " .. tostring(deserializeErr) .. " -- se reinicia")
		return InventoryCore.serialize(InventoryCore.new(DEFAULT_CAPACITY)), nil
	end

	return InventoryCore.serialize(state), nil
end

-- Guarda `inventory` si y solo si esta sesión (este servidor) sigue siendo
-- la propietaria del perfil. También renueva el heartbeat.
function ProfileStore.save(userId: number, inventory: SerializedInventory): (boolean, string?)
	local ok, err = pcall(function()
		profileStore:UpdateAsync(keyForUser(userId), function(current: any): (any, { number }?, {}?)
			if type(current) ~= "table" then
				error("PROFILE_MISSING")
			end

			local stored = current :: StoredProfile
			if stored.session == nil or (stored.session :: SessionMeta).jobId ~= game.JobId then
				error("SESSION_NOT_OWNED")
			end

			stored.inventory = inventory
			;(stored.session :: SessionMeta).lastHeartbeat = now()

			return stored, { userId }, nil
		end)
	end)

	if not ok then
		return false, "error de DataStore al guardar: " .. tostring(err)
	end
	return true, nil
end

-- Libera la sesión de `userId` si pertenece a este servidor. Se llama al
-- desconectar el jugador y desde BindToClose al apagar el servidor.
function ProfileStore.releaseSession(userId: number): (boolean, string?)
	local ok, err = pcall(function()
		profileStore:UpdateAsync(keyForUser(userId), function(current: any): (any, { number }?, {}?)
			if type(current) ~= "table" then
				return current, nil, nil
			end
			local stored = current :: StoredProfile
			if stored.session ~= nil and (stored.session :: SessionMeta).jobId == game.JobId then
				stored.session = nil
			end
			return stored, { userId }, nil
		end)
	end)

	if not ok then
		return false, "error de DataStore al liberar la sesión: " .. tostring(err)
	end
	return true, nil
end

return ProfileStore
