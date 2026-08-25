--!strict
--[[
	InventoryCore.luau

	Nucleo PURO del sistema de inventario.

	No requiere NINGUN servicio ni API de Roblox (game, workspace, Instance,
	DataStoreService, HttpService, etc.), por lo que puede ejecutarse tanto
	dentro de Roblox (como ModuleScript, vía Rojo) como fuera de Roblox con
	cualquier interprete de Luau (por ejemplo: `luau tests/InventoryCore.spec.luau`).

	Todas las funciones son deterministas y trabajan sobre tablas de datos
	planas (InventoryState). Las funciones de mutacion modifican el estado
	recibido "in place" (por conveniencia del llamador, p.ej. el servidor) y
	devuelven un resultado describiendo que ha pasado; nunca leen variables
	globales ni hacen I/O.
]]

local InventoryCore = {}

-- ============================================================================
-- Tipos
-- ============================================================================

export type ItemId = string

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	maxStack: number,
}

export type ItemDefinitions = { [ItemId]: ItemDefinition }

export type InventorySlot = {
	itemId: ItemId,
	quantity: number,
}

export type InventoryState = {
	capacity: number,
	slots: { [number]: InventorySlot },
}

export type AddItemResult = {
	ok: boolean,
	added: number,
	leftover: number,
	errorMessage: string?,
}

export type RemoveItemResult = {
	ok: boolean,
	removed: number,
	errorMessage: string?,
}

-- ============================================================================
-- Utilidades internas
-- ============================================================================

local function isPositiveInteger(value: number): boolean
	return type(value) == "number" and value == math.floor(value) and value > 0
end

-- ============================================================================
-- Construccion / copia
-- ============================================================================

function InventoryCore.new(capacity: number): InventoryState
	assert(isPositiveInteger(capacity), "capacity debe ser un entero positivo")
	return {
		capacity = capacity,
		slots = {},
	}
end

function InventoryCore.clone(inventory: InventoryState): InventoryState
	local slotsCopy: { [number]: InventorySlot } = {}
	for index, slot in pairs(inventory.slots) do
		slotsCopy[index] = { itemId = slot.itemId, quantity = slot.quantity }
	end
	return {
		capacity = inventory.capacity,
		slots = slotsCopy,
	}
end

-- ============================================================================
-- Consultas
-- ============================================================================

function InventoryCore.getFreeSlotCount(inventory: InventoryState): number
	local used = 0
	for _ in pairs(inventory.slots) do
		used += 1
	end
	return inventory.capacity - used
end

function InventoryCore.getItemCount(inventory: InventoryState, itemId: ItemId): number
	local total = 0
	for _, slot in pairs(inventory.slots) do
		if slot.itemId == itemId then
			total += slot.quantity
		end
	end
	return total
end

function InventoryCore.findFirstEmptySlot(inventory: InventoryState): number?
	for index = 1, inventory.capacity do
		if inventory.slots[index] == nil then
			return index
		end
	end
	return nil
end

-- Calcula, SIN mutar nada, si `quantity` unidades de `itemId` caben en el
-- inventario y cuantas se podrian anadir como maximo.
function InventoryCore.canAddItem(
	inventory: InventoryState,
	itemDefs: ItemDefinitions,
	itemId: ItemId,
	quantity: number
): (boolean, number)
	local definition = itemDefs[itemId]
	if definition == nil or not isPositiveInteger(quantity) then
		return false, 0
	end

	local remaining = quantity
	local maxStack = definition.maxStack

	-- 1) espacio en stacks existentes del mismo item
	for index = 1, inventory.capacity do
		if remaining <= 0 then
			break
		end
		local slot = inventory.slots[index]
		if slot ~= nil and slot.itemId == itemId then
			local room = maxStack - slot.quantity
			if room > 0 then
				remaining -= math.min(room, remaining)
			end
		end
	end

	-- 2) espacio en slots vacios
	if remaining > 0 then
		for index = 1, inventory.capacity do
			if remaining <= 0 then
				break
			end
			if inventory.slots[index] == nil then
				remaining -= math.min(maxStack, remaining)
			end
		end
	end

	local fits = remaining <= 0
	local addable = quantity - remaining
	return fits, addable
end

function InventoryCore.hasSpaceFor(
	inventory: InventoryState,
	itemDefs: ItemDefinitions,
	itemId: ItemId,
	quantity: number
): boolean
	local fits = InventoryCore.canAddItem(inventory, itemDefs, itemId, quantity)
	return fits
end

-- ============================================================================
-- Mutaciones
-- ============================================================================

-- Anade hasta `quantity` unidades de `itemId`, apilando primero en stacks
-- existentes y despues abriendo slots nuevos. Es una operacion "best
-- effort": si no cabe todo, anade lo que quepa y reporta el sobrante en
-- `leftover` (ok = false en ese caso).
function InventoryCore.addItem(
	inventory: InventoryState,
	itemDefs: ItemDefinitions,
	itemId: ItemId,
	quantity: number
): AddItemResult
	local definition = itemDefs[itemId]
	if definition == nil then
		return { ok = false, added = 0, leftover = quantity, errorMessage = "unknown_item" }
	end
	if not isPositiveInteger(quantity) then
		return { ok = false, added = 0, leftover = quantity, errorMessage = "invalid_quantity" }
	end

	local maxStack = definition.maxStack
	local remaining = quantity
	local added = 0

	-- 1) rellenar stacks existentes del mismo item
	for index = 1, inventory.capacity do
		if remaining <= 0 then
			break
		end
		local slot = inventory.slots[index]
		if slot ~= nil and slot.itemId == itemId then
			local room = maxStack - slot.quantity
			if room > 0 then
				local toAdd = math.min(room, remaining)
				slot.quantity += toAdd
				remaining -= toAdd
				added += toAdd
			end
		end
	end

	-- 2) usar slots vacios
	if remaining > 0 then
		for index = 1, inventory.capacity do
			if remaining <= 0 then
				break
			end
			if inventory.slots[index] == nil then
				local toAdd = math.min(maxStack, remaining)
				inventory.slots[index] = { itemId = itemId, quantity = toAdd }
				remaining -= toAdd
				added += toAdd
			end
		end
	end

	return {
		ok = remaining <= 0,
		added = added,
		leftover = remaining,
		errorMessage = if remaining > 0 then "not_enough_space" else nil,
	}
end

-- Quita `quantity` unidades de `itemId`. Es atomica: si no hay suficiente
-- cantidad disponible no se modifica nada y devuelve ok = false.
function InventoryCore.removeItem(inventory: InventoryState, itemId: ItemId, quantity: number): RemoveItemResult
	if not isPositiveInteger(quantity) then
		return { ok = false, removed = 0, errorMessage = "invalid_quantity" }
	end

	local available = InventoryCore.getItemCount(inventory, itemId)
	if available < quantity then
		return { ok = false, removed = 0, errorMessage = "insufficient_quantity" }
	end

	local remaining = quantity
	for index = 1, inventory.capacity do
		if remaining <= 0 then
			break
		end
		local slot = inventory.slots[index]
		if slot ~= nil and slot.itemId == itemId then
			local toRemove = math.min(slot.quantity, remaining)
			slot.quantity -= toRemove
			remaining -= toRemove
			if slot.quantity <= 0 then
				inventory.slots[index] = nil
			end
		end
	end

	return { ok = true, removed = quantity, errorMessage = nil }
end

-- ============================================================================
-- Serializacion
--
-- Formato interno propio, versionado, sin dependencias externas (ni JSON ni
-- HttpService):
--
--   "<version>|<capacity>|<slot>:<itemId>:<quantity>|<slot>:<itemId>:<quantity>|..."
--
--   Ejemplo: "1|20|1:Sword:2|3:Potion:5"
-- ============================================================================

local SERIALIZATION_VERSION = "1"

function InventoryCore.serialize(inventory: InventoryState): string
	local parts: { string } = { SERIALIZATION_VERSION, tostring(inventory.capacity) }
	for index = 1, inventory.capacity do
		local slot = inventory.slots[index]
		if slot ~= nil then
			table.insert(parts, string.format("%d:%s:%d", index, slot.itemId, slot.quantity))
		end
	end
	return table.concat(parts, "|")
end

function InventoryCore.deserialize(serialized: string): (InventoryState?, string?)
	if type(serialized) ~= "string" or serialized == "" then
		return nil, "empty_input"
	end

	local segments: { string } = {}
	for segment in serialized:gmatch("[^|]+") do
		table.insert(segments, segment)
	end

	if #segments < 2 then
		return nil, "malformed_header"
	end

	if segments[1] ~= SERIALIZATION_VERSION then
		return nil, "unsupported_version"
	end

	local capacity = tonumber(segments[2])
	if capacity == nil or not isPositiveInteger(capacity) then
		return nil, "invalid_capacity"
	end

	local inventory = InventoryCore.new(capacity)

	for i = 3, #segments do
		local indexStr, itemId, quantityStr = segments[i]:match("^(%d+):([%w_]+):(%d+)$")
		if indexStr == nil then
			return nil, "malformed_slot_entry"
		end

		local index = tonumber(indexStr) :: number
		local quantity = tonumber(quantityStr) :: number

		if index < 1 or index > capacity then
			return nil, "slot_out_of_range"
		end
		if quantity <= 0 then
			return nil, "invalid_slot_quantity"
		end

		inventory.slots[index] = { itemId = itemId :: string, quantity = quantity }
	end

	return inventory, nil
end

return InventoryCore
