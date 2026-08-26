--!strict
--[[
	InventoryService
	=================

	Capa de servidor: envuelve InventoryCore (lógica pura) con persistencia
	en DataStoreService y bloqueo de sesión, para que dos servidores del
	mismo juego (p. ej. tras un teleport o un despliegue con servidores
	solapados) no puedan escribir el mismo perfil a la vez y pisarse los
	datos.

	El bloqueo se implementa guardando, dentro del propio registro del
	DataStore, un `sessionLock` con el JobId del servidor que lo posee y
	la hora de la última renovación. `UpdateAsync` garantiza que la
	lectura+comprobación+escritura del lock es atómica a nivel de
	DataStore, así que dos servidores compitiendo por el mismo perfil no
	pueden "ganar" los dos a la vez.
]]

local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryCore = require(ReplicatedStorage.Shared.Inventory.InventoryCore)
local ItemDatabase = require(ReplicatedStorage.Shared.Inventory.ItemDatabase)

local InventoryService = {}

local DATASTORE_NAME = "PlayerInventory_v1"
local DEFAULT_CAPACITY = 30

-- Si el lock lleva más de esto sin renovarse, se considera abandonado
-- (el servidor que lo tenía probablemente crasheó) y puede reclamarse.
local SESSION_LOCK_TIMEOUT_SECONDS = 10 * 60

local inventoryStore = DataStoreService:GetDataStore(DATASTORE_NAME)

export type SessionLock = {
	placeId: number,
	jobId: string,
	updatedAt: number,
}

export type ProfileData = {
	sessionLock: SessionLock?,
	inventory: InventoryCore.SerializedInventory,
}

export type Profile = {
	userId: number,
	inventory: InventoryCore.Inventory,
	released: boolean,
}

local profiles: { [number]: Profile } = {}

local function now(): number
	return DateTime.now().UnixTimestamp
end

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function newProfileData(): ProfileData
	return {
		sessionLock = nil,
		inventory = InventoryCore.serialize(InventoryCore.new(DEFAULT_CAPACITY)),
	}
end

--[[
	Intenta reclamar el lock de sesión de `userId` de forma atómica.
	Devuelve los datos del perfil (ya con el lock puesto a nuestro
	nombre) si tiene éxito, o `nil` + mensaje de error si el perfil está
	bloqueado por otro servidor activo o si falla el acceso al
	DataStore.
]]
local function claimLock(userId: number): (ProfileData?, string?)
	local key = keyFor(userId)
	local claimed: ProfileData? = nil
	local lockError: string? = nil

	local ok, updateErr = pcall(function()
		inventoryStore:UpdateAsync(key, function(existing: ProfileData?): ProfileData?
			local data: ProfileData = existing or newProfileData()

			local lock = data.sessionLock
			local isOwnedByUs = lock ~= nil and lock.jobId == game.JobId
			local isStale = lock == nil or (now() - lock.updatedAt) > SESSION_LOCK_TIMEOUT_SECONDS

			if lock ~= nil and not isOwnedByUs and not isStale then
				lockError = "perfil bloqueado por otra sesión de servidor activa"
				return nil -- Devolver nil aborta el UpdateAsync: no se escribe nada.
			end

			data.sessionLock = {
				placeId = game.PlaceId,
				jobId = game.JobId,
				updatedAt = now(),
			}
			claimed = data
			return data
		end)
	end)

	if not ok then
		return nil, `fallo al acceder al DataStore: {tostring(updateErr)}`
	end
	if lockError then
		return nil, lockError
	end
	if not claimed then
		return nil, "no se pudo reclamar el lock de sesión"
	end
	return claimed, nil
end

--[[
	Carga (o devuelve, si ya estaba cargado en este servidor) el perfil
	de `userId`, reclamando el lock de sesión primero.
]]
function InventoryService.LoadProfile(userId: number): (Profile?, string?)
	local existingProfile = profiles[userId]
	if existingProfile then
		return existingProfile, nil
	end

	local data, err = claimLock(userId)
	if not data then
		return nil, err
	end

	local inventory, deserializeErr = InventoryCore.deserialize(data.inventory, ItemDatabase.toCoreDefinitions())
	if not inventory then
		warn(`inventario corrupto para el usuario {userId} ({tostring(deserializeErr)}), se reinicia vacío`)
		inventory = InventoryCore.new(DEFAULT_CAPACITY)
	end

	local profile: Profile = {
		userId = userId,
		inventory = inventory :: InventoryCore.Inventory,
		released = false,
	}
	profiles[userId] = profile
	return profile, nil
end

--[[
	Guarda el estado actual del perfil en el DataStore, pero solo si
	seguimos siendo dueños del lock de sesión (comprobado de forma
	atómica dentro del propio UpdateAsync). Si otro servidor nos quitó
	el lock, no sobreescribe sus datos.
]]
function InventoryService.SaveProfile(userId: number): (boolean, string?)
	local profile = profiles[userId]
	if not profile then
		return false, "el perfil no está cargado en este servidor"
	end

	local key = keyFor(userId)
	local snapshot = InventoryCore.serialize(profile.inventory)
	local saveError: string? = nil

	local ok, updateErr = pcall(function()
		inventoryStore:UpdateAsync(key, function(existing: ProfileData?): ProfileData?
			local lock = existing and existing.sessionLock
			if existing == nil or lock == nil or lock.jobId ~= game.JobId then
				saveError = "ya no tenemos el lock de sesión: no se sobreescribe"
				return nil
			end

			existing.inventory = snapshot
			existing.sessionLock = {
				placeId = game.PlaceId,
				jobId = game.JobId,
				updatedAt = now(),
			}
			return existing
		end)
	end)

	if not ok then
		return false, `fallo al guardar en el DataStore: {tostring(updateErr)}`
	end
	if saveError then
		return false, saveError
	end
	return true, nil
end

--[[
	Guarda el perfil y libera su lock de sesión, para que otro servidor
	(p. ej. tras un teleport) pueda reclamarlo. Debe llamarse siempre en
	PlayerRemoving y en BindToClose.
]]
function InventoryService.ReleaseProfile(userId: number)
	local profile = profiles[userId]
	if not profile or profile.released then
		return
	end

	InventoryService.SaveProfile(userId)

	local key = keyFor(userId)
	pcall(function()
		inventoryStore:UpdateAsync(key, function(existing: ProfileData?): ProfileData?
			local lock = existing and existing.sessionLock
			if existing == nil or lock == nil or lock.jobId ~= game.JobId then
				return nil
			end
			existing.sessionLock = nil
			return existing
		end)
	end)

	profile.released = true
	profiles[userId] = nil
end

--[[
	Snapshot serializable del inventario de `userId`, listo para enviar
	al cliente por una remota. `nil` si el perfil no está cargado.
]]
function InventoryService.GetInventorySnapshot(userId: number): InventoryCore.SerializedInventory?
	local profile = profiles[userId]
	if not profile then
		return nil
	end
	return InventoryCore.serialize(profile.inventory)
end

--[[
	Concede `quantity` unidades de `itemId` a `userId`. SOLO debe
	llamarse desde código de servidor de confianza (recompensas, tienda,
	drops...), nunca a partir de una cantidad o item elegidos por el
	cliente.
]]
function InventoryService.GrantItem(userId: number, itemId: InventoryCore.ItemId, quantity: number): (boolean, string?)
	local profile = profiles[userId]
	if not profile then
		return false, "el perfil no está cargado en este servidor"
	end

	local itemDef = ItemDatabase.get(itemId)
	if not itemDef then
		return false, `itemId desconocido: {itemId}`
	end

	if type(quantity) ~= "number" or quantity <= 0 or quantity % 1 ~= 0 then
		return false, "quantity debe ser un entero positivo"
	end

	local result = InventoryCore.addItem(profile.inventory, itemDef, quantity)
	if result.overflow > 0 then
		return result.added > 0, "inventario lleno: no cupieron todas las unidades"
	end
	return true, nil
end

--[[
	Quita `quantity` unidades de `itemId` a `userId`. Uso de servidor de
	confianza (crafteo, comercio, penalizaciones...).
]]
function InventoryService.RemoveItem(userId: number, itemId: InventoryCore.ItemId, quantity: number): (boolean, string?)
	local profile = profiles[userId]
	if not profile then
		return false, "el perfil no está cargado en este servidor"
	end
	return InventoryCore.removeItem(profile.inventory, itemId, quantity)
end

--[[
	Punto de entrada para la remota "usar item": el cliente solo indica
	QUÉ item quiere usar (`itemId`), nunca cuánto se consume ni si es
	válido. Esa decisión sale siempre del ItemDatabase del servidor.
]]
function InventoryService.UseItem(userId: number, itemId: InventoryCore.ItemId): (boolean, string?)
	local profile = profiles[userId]
	if not profile then
		return false, "el perfil no está cargado en este servidor"
	end

	local itemDef = ItemDatabase.get(itemId)
	if not itemDef then
		return false, `itemId desconocido: {itemId}`
	end

	if not itemDef.usable or itemDef.consumeOnUse == nil then
		return false, `el item {itemId} no es usable`
	end

	return InventoryCore.removeItem(profile.inventory, itemId, itemDef.consumeOnUse)
end

return InventoryService
