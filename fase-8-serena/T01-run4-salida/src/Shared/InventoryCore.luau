--!strict

--[[
	InventoryCore

	Núcleo de lógica de inventario, puro: no requiere ningún servicio de
	Roblox ni la variable global `game`/`script`. Puede ejecutarse tanto
	dentro de un ModuleScript de Roblox como con el intérprete standalone
	`luau`, lo que permite testearlo por completo fuera del motor.

	Todas las funciones de mutación devuelven un ESTADO NUEVO en vez de
	modificar el que reciben, para que el resultado sea fácil de razonar y
	de testear.
]]

local InventoryCore = {}

export type ItemId = string

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	-- Máximo de unidades que puede acumular un único slot de este item.
	maxStack: number,
}

export type ItemDatabase = { [ItemId]: ItemDefinition }

export type InventorySlot = {
	itemId: ItemId,
	quantity: number,
}

export type InventoryState = {
	-- Número máximo de slots que puede ocupar el inventario.
	capacity: number,
	slots: { InventorySlot },
}

export type SerializedSlot = {
	itemId: ItemId,
	quantity: number,
}

export type SerializedInventory = {
	capacity: number,
	slots: { SerializedSlot },
}

-- ============================================================================
-- Utilidades internas
-- ============================================================================

local function cloneSlot(slot: InventorySlot): InventorySlot
	return { itemId = slot.itemId, quantity = slot.quantity }
end

local function cloneState(state: InventoryState): InventoryState
	local slots: { InventorySlot } = table.create(#state.slots)
	for index, slot in state.slots do
		slots[index] = cloneSlot(slot)
	end
	return { capacity = state.capacity, slots = slots }
end

local function isPositiveInteger(value: number): boolean
	return value > 0 and value % 1 == 0
end

-- ============================================================================
-- Construcción
-- ============================================================================

function InventoryCore.new(capacity: number): InventoryState
	assert(type(capacity) == "number" and capacity >= 0 and capacity % 1 == 0, "capacity debe ser un entero >= 0")
	return { capacity = capacity, slots = {} }
end

-- ============================================================================
-- Consultas
-- ============================================================================

function InventoryCore.getUsedSlots(state: InventoryState): number
	return #state.slots
end

function InventoryCore.getFreeSlotCount(state: InventoryState): number
	return state.capacity - #state.slots
end

function InventoryCore.getQuantity(state: InventoryState, itemId: ItemId): number
	local total = 0
	for _, slot in state.slots do
		if slot.itemId == itemId then
			total += slot.quantity
		end
	end
	return total
end

function InventoryCore.hasItem(state: InventoryState, itemId: ItemId, quantity: number?): boolean
	local needed = quantity or 1
	return InventoryCore.getQuantity(state, itemId) >= needed
end

-- Cuántas unidades más de `itemId` caben, contando tanto el hueco que queda
-- en slots ya apilados como el que darían los slots libres.
function InventoryCore.getAvailableSpace(state: InventoryState, database: ItemDatabase, itemId: ItemId): number
	local definition = database[itemId]
	if definition == nil then
		return 0
	end

	local space = 0
	for _, slot in state.slots do
		if slot.itemId == itemId then
			space += math.max(definition.maxStack - slot.quantity, 0)
		end
	end
	space += InventoryCore.getFreeSlotCount(state) * definition.maxStack
	return space
end

-- Comprueba si añadir `quantity` unidades de `itemId` es posible ahora mismo.
function InventoryCore.canAdd(
	state: InventoryState,
	database: ItemDatabase,
	itemId: ItemId,
	quantity: number
): (boolean, string?)
	if not isPositiveInteger(quantity) then
		return false, "quantity debe ser un entero positivo"
	end
	if database[itemId] == nil then
		return false, "item desconocido: " .. itemId
	end
	if InventoryCore.getAvailableSpace(state, database, itemId) < quantity then
		return false, "espacio insuficiente"
	end
	return true, nil
end

-- ============================================================================
-- Mutación (devuelven un ESTADO NUEVO, no modifican `state`)
-- ============================================================================

-- Añade hasta `quantity` unidades de `itemId`, apilando primero en slots
-- existentes y usando slots libres después. Devuelve el nuevo estado, cuántas
-- unidades se llegaron a añadir realmente (puede ser menor que `quantity` si
-- no cabían, aunque por defecto se rechaza la operación entera) y un error
-- opcional.
function InventoryCore.addItem(
	state: InventoryState,
	database: ItemDatabase,
	itemId: ItemId,
	quantity: number
): (InventoryState, number, string?)
	local ok, err = InventoryCore.canAdd(state, database, itemId, quantity)
	if not ok then
		return state, 0, err
	end

	local definition = database[itemId] :: ItemDefinition
	local newState = cloneState(state)
	local remaining = quantity

	for _, slot in newState.slots do
		if remaining <= 0 then
			break
		end
		if slot.itemId == itemId and slot.quantity < definition.maxStack then
			local moved = math.min(definition.maxStack - slot.quantity, remaining)
			slot.quantity += moved
			remaining -= moved
		end
	end

	while remaining > 0 and #newState.slots < newState.capacity do
		local moved = math.min(definition.maxStack, remaining)
		table.insert(newState.slots, { itemId = itemId, quantity = moved })
		remaining -= moved
	end

	return newState, quantity - remaining, nil
end

-- Quita `quantity` unidades de `itemId`. Es todo o nada: si no hay
-- suficientes unidades, no cambia nada y devuelve un error.
function InventoryCore.removeItem(state: InventoryState, itemId: ItemId, quantity: number): (InventoryState, boolean, string?)
	if not isPositiveInteger(quantity) then
		return state, false, "quantity debe ser un entero positivo"
	end
	if not InventoryCore.hasItem(state, itemId, quantity) then
		return state, false, "cantidad insuficiente de " .. itemId
	end

	local newState = cloneState(state)
	local remaining = quantity
	local index = 1
	while index <= #newState.slots and remaining > 0 do
		local slot = newState.slots[index]
		if slot.itemId == itemId then
			local taken = math.min(slot.quantity, remaining)
			slot.quantity -= taken
			remaining -= taken
			if slot.quantity == 0 then
				table.remove(newState.slots, index)
				continue
			end
		end
		index += 1
	end

	return newState, true, nil
end

-- ============================================================================
-- Serialización
-- ============================================================================

-- Convierte el estado a una tabla "plana" apta para guardarse tal cual en un
-- DataStore (solo strings, números y tablas anidadas de esos tipos).
function InventoryCore.serialize(state: InventoryState): SerializedInventory
	local slots: { SerializedSlot } = table.create(#state.slots)
	for index, slot in state.slots do
		slots[index] = { itemId = slot.itemId, quantity = slot.quantity }
	end
	return { capacity = state.capacity, slots = slots }
end

-- Reconstruye un InventoryState a partir de datos no confiables (por ejemplo
-- lo leído de un DataStore). Nunca lanza error: si algo no cuadra devuelve
-- nil y un mensaje describiendo el problema.
function InventoryCore.deserialize(data: any): (InventoryState?, string?)
	if type(data) ~= "table" then
		return nil, "datos de inventario inválidos: se esperaba una tabla"
	end

	local capacity = data.capacity
	if type(capacity) ~= "number" or capacity < 0 or capacity % 1 ~= 0 then
		return nil, "capacity inválida"
	end

	local rawSlots = data.slots
	if type(rawSlots) ~= "table" then
		return nil, "slots inválidos"
	end

	local slots: { InventorySlot } = {}
	for _, rawSlot in rawSlots :: { any } do
		if type(rawSlot) ~= "table" then
			return nil, "slot inválido"
		end
		local itemId = rawSlot.itemId
		local quantity = rawSlot.quantity
		if type(itemId) ~= "string" or type(quantity) ~= "number" or not isPositiveInteger(quantity) then
			return nil, "slot con datos inválidos"
		end
		table.insert(slots, { itemId = itemId, quantity = quantity })
	end

	if #slots > capacity then
		return nil, "hay más slots ocupados que capacity"
	end

	return { capacity = capacity, slots = slots }, nil
end

return InventoryCore
