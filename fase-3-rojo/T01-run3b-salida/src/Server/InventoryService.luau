--!strict

--[[
	InventoryService
	=================
	Capa de servidor: persiste el inventario de cada jugador con
	DataStoreService y aplica un bloqueo de sesión (session lock) para
	que dos servidores nunca escriban el mismo perfil a la vez.

	El bloqueo se implementa guardando, junto al inventario, qué
	sesión de servidor lo tiene abierto (`ownerSession`) y cuándo lo
	tocó por última vez (`lockedAt`). Cargar un perfil que otra sesión
	tiene bloqueado y vigente (`lockedAt` reciente) falla; el servidor
	dueño refresca el bloqueo periódicamente mientras el jugador está
	conectado.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))

type Inventory = InventoryCore.Inventory
type SerializedInventory = InventoryCore.SerializedInventory

local InventoryService = {}

local INVENTORY_STORE_NAME = "PlayerInventories_v1"
local DEFAULT_CAPACITY_SLOTS = 30
local LOCK_TTL_SECONDS = 30
local MAX_UPDATE_ATTEMPTS = 5

local inventoryStore = DataStoreService:GetDataStore(INVENTORY_STORE_NAME)

-- Identidad de ESTA sesión de servidor para el bloqueo. `game.JobId`
-- viene vacío en Studio, así que se usa un GUID como respaldo.
local SESSION_ID: string = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

export type ProfileRecord = {
	ownerSession: string,
	lockedAt: number,
	inventory: SerializedInventory,
}

export type LoadResult = { ok: true, inventory: Inventory } | { ok: false, errorMessage: string }
export type SaveResult = { ok: true } | { ok: false, errorMessage: string }

local activeLocks: { [number]: boolean } = {}

local function now(): number
	return os.time()
end

local function playerKey(userId: number): string
	return "Player_" .. tostring(userId)
end

-- Envuelve UpdateAsync con reintentos. `transform` recibe el registro
-- actual (o nil si no existe) y devuelve el nuevo registro más un
-- booleano: `false` cancela la escritura sin reintentar (por ejemplo,
-- porque otro servidor tiene el bloqueo).
local function updateWithRetry(
	key: string,
	transform: (ProfileRecord?) -> (ProfileRecord?, boolean)
): (boolean, string?)
	local attempts = 0
	local lastError: string? = nil

	while attempts < MAX_UPDATE_ATTEMPTS do
		attempts += 1

		local applied = false
		local success, err = pcall(function()
			inventoryStore:UpdateAsync(key, function(rawCurrent: any): any
				local current = rawCurrent :: ProfileRecord?
				local nextRecord, ok = transform(current)
				applied = ok
				if not ok then
					return nil
				end
				return nextRecord
			end)
		end)

		if success then
			if applied then
				return true, nil
			end
			return false, "bloqueado por otro servidor"
		end

		lastError = tostring(err)
		task.wait(attempts)
	end

	return false, lastError or "fallo desconocido al guardar"
end

-- Carga el perfil del jugador y toma el bloqueo de sesión. Falla si
-- otro servidor lo tiene bloqueado y ese bloqueo sigue vigente.
function InventoryService.LoadProfile(userId: number): LoadResult
	local key = playerKey(userId)
	local loadedInventory: Inventory? = nil

	local ok, err = updateWithRetry(key, function(current: ProfileRecord?)
		if current ~= nil and current.ownerSession ~= SESSION_ID and current.ownerSession ~= "" then
			if (now() - current.lockedAt) < LOCK_TTL_SECONDS then
				return current, false
			end
		end

		local inventory: Inventory
		if current ~= nil then
			inventory = InventoryCore.deserialize(current.inventory)
		else
			inventory = InventoryCore.new(DEFAULT_CAPACITY_SLOTS)
		end

		loadedInventory = inventory

		local record: ProfileRecord = {
			ownerSession = SESSION_ID,
			lockedAt = now(),
			inventory = InventoryCore.serialize(inventory),
		}
		return record, true
	end)

	if not ok or loadedInventory == nil then
		return { ok = false, errorMessage = err or "perfil bloqueado por otro servidor" }
	end

	activeLocks[userId] = true
	return { ok = true, inventory = loadedInventory }
end

-- Guarda el inventario. Si esta sesión ya no es dueña del bloqueo (lo
-- perdió, por ejemplo tras un TTL expirado y otra sesión lo tomó), no
-- sobrescribe. `release = true` libera el bloqueo tras guardar.
function InventoryService.SaveProfile(userId: number, inventory: Inventory, release: boolean?): SaveResult
	local key = playerKey(userId)

	local ok, err = updateWithRetry(key, function(current: ProfileRecord?)
		if current ~= nil and current.ownerSession ~= SESSION_ID and current.ownerSession ~= "" then
			return current, false
		end

		local record: ProfileRecord = {
			ownerSession = if release then "" else SESSION_ID,
			lockedAt = now(),
			inventory = InventoryCore.serialize(inventory),
		}
		return record, true
	end)

	if ok and release then
		activeLocks[userId] = nil
	end

	if not ok then
		return { ok = false, errorMessage = err or "no se pudo guardar el perfil" }
	end
	return { ok = true }
end

-- Libera el bloqueo sin tocar los datos guardados (por ejemplo, si la
-- carga falló y no llegamos a tener un inventario que guardar).
function InventoryService.ReleaseProfile(userId: number): ()
	local key = playerKey(userId)
	updateWithRetry(key, function(current: ProfileRecord?)
		if current == nil or current.ownerSession ~= SESSION_ID then
			return current, false
		end
		return {
			ownerSession = "",
			lockedAt = now(),
			inventory = current.inventory,
		}, true
	end)
	activeLocks[userId] = nil
end

function InventoryService.HasLock(userId: number): boolean
	return activeLocks[userId] == true
end

return InventoryService
