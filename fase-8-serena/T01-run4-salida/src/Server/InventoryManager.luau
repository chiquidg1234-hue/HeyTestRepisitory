--!strict

--[[
	InventoryManager

	Único punto de entrada que el resto del código de servidor debe usar
	para tocar inventarios. Mantiene el estado en memoria por jugador (cargado
	vía ProfileStore) y aplica siempre InventoryCore para las mutaciones, así
	que las reglas de apilado/espacio se comparten con el núcleo puro y sus
	tests.
]]

local ProfileStore = require(script.Parent.ProfileStore)
local InventoryCore = require(game:GetService("ReplicatedStorage").Shared.InventoryCore)
local ItemDatabase = require(game:GetService("ReplicatedStorage").Shared.ItemDatabase)

type InventoryState = InventoryCore.InventoryState
type ItemId = InventoryCore.ItemId
type SerializedInventory = InventoryCore.SerializedInventory

type PlayerEntry = {
	state: InventoryState,
	dirty: boolean,
}

local entries: { [number]: PlayerEntry } = {}

local InventoryManager = {}

-- Reclama la sesión y carga (o crea) el inventario del jugador en memoria.
function InventoryManager.load(userId: number): (boolean, string?)
	local serialized, claimErr = ProfileStore.claimSession(userId)
	if serialized == nil then
		return false, claimErr
	end

	local state, deserializeErr = InventoryCore.deserialize(serialized)
	if state == nil then
		return false, deserializeErr
	end

	entries[userId] = { state = state, dirty = false }
	return true, nil
end

function InventoryManager.isLoaded(userId: number): boolean
	return entries[userId] ~= nil
end

function InventoryManager.getSnapshot(userId: number): SerializedInventory?
	local entry = entries[userId]
	if entry == nil then
		return nil
	end
	return InventoryCore.serialize(entry.state)
end

-- Añade cantidades DECIDIDAS POR EL SERVIDOR (nunca por el cliente).
function InventoryManager.addItem(userId: number, itemId: ItemId, quantity: number): (number, string?)
	local entry = entries[userId]
	if entry == nil then
		return 0, "inventario no cargado"
	end

	local newState, added, err = InventoryCore.addItem(entry.state, ItemDatabase, itemId, quantity)
	entry.state = newState
	if added > 0 then
		entry.dirty = true
	end
	return added, err
end

-- Quita cantidades DECIDIDAS POR EL SERVIDOR (nunca por el cliente).
function InventoryManager.removeItem(userId: number, itemId: ItemId, quantity: number): (boolean, string?)
	local entry = entries[userId]
	if entry == nil then
		return false, "inventario no cargado"
	end

	local newState, ok, err = InventoryCore.removeItem(entry.state, itemId, quantity)
	entry.state = newState
	if ok then
		entry.dirty = true
	end
	return ok, err
end

-- Guarda si hay cambios pendientes. No hace ninguna llamada de red si no
-- hace falta.
function InventoryManager.save(userId: number): (boolean, string?)
	local entry = entries[userId]
	if entry == nil then
		return true, nil
	end
	if not entry.dirty then
		return true, nil
	end

	local ok, err = ProfileStore.save(userId, InventoryCore.serialize(entry.state))
	if ok then
		entry.dirty = false
	end
	return ok, err
end

-- Guarda (si procede), libera la sesión y borra el estado en memoria.
function InventoryManager.unload(userId: number): (boolean, string?)
	local saveOk, saveErr = InventoryManager.save(userId)
	entries[userId] = nil

	local releaseOk, releaseErr = ProfileStore.releaseSession(userId)

	if not saveOk then
		return false, saveErr
	end
	if not releaseOk then
		return false, releaseErr
	end
	return true, nil
end

return InventoryManager
