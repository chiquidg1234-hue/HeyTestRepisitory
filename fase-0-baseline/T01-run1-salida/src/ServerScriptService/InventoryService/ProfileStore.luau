--!strict
--[[
	ProfileStore.luau

	Envoltorio sobre DataStoreService que anade "session locking": cada
	perfil guarda quien es su dueno actual (un identificador de sesion de
	servidor + marca de tiempo). Antes de escribir, un servidor comprueba
	que sigue siendo el dueno del candado (o que el candado anterior ha
	caducado por inactividad), evitando que dos servidores distintos con el
	mismo perfil abierto (p.ej. durante un teleport o un cuelgue) se pisen
	las escrituras entre si.

	Esta capa SI depende de servicios de Roblox (DataStoreService) y por
	tanto solo puede ejecutarse dentro de Roblox.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

export type SessionLock = {
	ownerId: string,
	updatedAt: number,
}

export type ProfileRecord = {
	payload: string,
	lock: SessionLock?,
}

export type OperationResult = {
	ok: boolean,
	payload: string?,
	errorMessage: string?,
}

-- Un candado sin renovar durante mas de esto se considera abandonado
-- (servidor caido sin liberar) y puede ser tomado por otro servidor.
local LOCK_TIMEOUT_SECONDS = 30 * 60

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type ProfileStoreInstance = typeof(setmetatable(
	{} :: {
		_dataStore: DataStore,
		_sessionId: string,
	},
	ProfileStore
))

function ProfileStore.new(dataStoreName: string): ProfileStoreInstance
	local self = setmetatable({}, ProfileStore) :: ProfileStoreInstance
	self._dataStore = DataStoreService:GetDataStore(dataStoreName)

	local jobId = game.JobId
	self._sessionId = if jobId ~= "" then jobId else HttpService:GenerateGUID(false)

	return self
end

-- Intenta tomar (o renovar) el candado de sesion y devolver el payload
-- actual (o `defaultPayload` si el perfil no existia todavia). Si otro
-- servidor tiene el candado activo, ok = false y no se escribe nada.
function ProfileStore:Load(key: string, defaultPayload: string): OperationResult
	local success, result = pcall(function()
		return self._dataStore:UpdateAsync(key, function(current: ProfileRecord?)
			local now = os.time()

			if current == nil then
				return {
					payload = defaultPayload,
					lock = { ownerId = self._sessionId, updatedAt = now },
				}
			end

			local lock = current.lock
			local lockIsFree = lock == nil
				or lock.ownerId == self._sessionId
				or (now - lock.updatedAt) > LOCK_TIMEOUT_SECONDS

			if not lockIsFree then
				return nil -- aborta: otro servidor sigue teniendo el perfil abierto
			end

			return {
				payload = current.payload,
				lock = { ownerId = self._sessionId, updatedAt = now },
			}
		end)
	end)

	if not success then
		return { ok = false, payload = nil, errorMessage = tostring(result) }
	end

	local record = result :: ProfileRecord?
	if record == nil then
		return { ok = false, payload = nil, errorMessage = "profile_locked_by_another_server" }
	end

	return { ok = true, payload = record.payload, errorMessage = nil }
end

-- Guarda `payload` solo si seguimos siendo el dueno del candado (o el
-- candado anterior ha caducado). Renueva el candado al guardar.
function ProfileStore:Save(key: string, payload: string): OperationResult
	local success, result = pcall(function()
		return self._dataStore:UpdateAsync(key, function(current: ProfileRecord?)
			local now = os.time()
			local lock = current and current.lock or nil

			local weOwnLock = lock ~= nil and lock.ownerId == self._sessionId
			local lockExpired = lock ~= nil and (now - lock.updatedAt) > LOCK_TIMEOUT_SECONDS
			local lockIsFree = lock == nil or weOwnLock or lockExpired

			if not lockIsFree then
				return nil -- aborta: no somos el dueno legitimo del perfil
			end

			return {
				payload = payload,
				lock = { ownerId = self._sessionId, updatedAt = now },
			}
		end)
	end)

	if not success then
		return { ok = false, payload = nil, errorMessage = tostring(result) }
	end

	local record = result :: ProfileRecord?
	if record == nil then
		return { ok = false, payload = nil, errorMessage = "profile_locked_by_another_server" }
	end

	return { ok = true, payload = record.payload, errorMessage = nil }
end

-- Libera el candado (llamar al desconectar al jugador o en BindToClose)
-- para que otro servidor pueda tomar el perfil de inmediato en vez de
-- esperar a que caduque.
function ProfileStore:ReleaseLock(key: string): boolean
	local success = pcall(function()
		self._dataStore:UpdateAsync(key, function(current: ProfileRecord?)
			if current == nil then
				return nil
			end
			if current.lock ~= nil and current.lock.ownerId ~= self._sessionId then
				return nil -- no es nuestro candado, no lo tocamos
			end
			return {
				payload = current.payload,
				lock = nil,
			}
		end)
	end)
	return success
end

return ProfileStore
