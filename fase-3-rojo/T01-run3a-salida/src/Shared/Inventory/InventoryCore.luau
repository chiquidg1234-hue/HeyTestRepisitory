--!strict
--[[
	InventoryCore
	=============

	Lógica PURA de inventario. No requiere ni importa ningún servicio de
	Roblox (nada de `game:GetService`, `DataStoreService`, `Instance.new`,
	etc.), por lo que este módulo puede ejecutarse tal cual con cualquier
	intérprete de Luau (por ejemplo `luau` o `lune`) fuera de Roblox, lo
	que permite testearlo sin arrancar el motor.

	Toda función que muta un `Inventory` lo hace in-place y también lo
	devuelve implícitamente a través de los argumentos (no se copia salvo
	que se llame explícitamente a `clone`).
]]

local InventoryCore = {}

export type ItemId = string

-- Definición "de catálogo" de un item. La capa de servidor es quien decide
-- qué definiciones existen; el núcleo solo confía en lo que se le pasa.
export type ItemDefinition = {
	id: ItemId,
	maxStack: number,
}

export type ItemDefinitions = { [ItemId]: ItemDefinition }

export type Slot = {
	itemId: ItemId,
	quantity: number,
}

export type Inventory = {
	capacity: number,
	slots: { Slot },
}

export type SerializedSlot = {
	itemId: ItemId,
	quantity: number,
}

export type SerializedInventory = {
	capacity: number,
	slots: { SerializedSlot },
}

export type AddResult = {
	added: number,
	overflow: number,
}

local function isPositiveInteger(value: number): boolean
	return value > 0 and value % 1 == 0
end

local function isNonNegativeInteger(value: number): boolean
	return value >= 0 and value % 1 == 0
end

--[[
	Crea un inventario vacío con la capacidad (número de ranuras) dada.
]]
function InventoryCore.new(capacity: number): Inventory
	assert(type(capacity) == "number" and isNonNegativeInteger(capacity), "capacity debe ser un entero no negativo")
	return {
		capacity = capacity,
		slots = {},
	}
end

--[[
	Devuelve una copia profunda e independiente del inventario, para que
	quien la reciba pueda mutarla sin afectar al original.
]]
function InventoryCore.clone(inventory: Inventory): Inventory
	local slots: { Slot } = table.create(#inventory.slots)
	for index, slot in inventory.slots do
		slots[index] = { itemId = slot.itemId, quantity = slot.quantity }
	end
	return {
		capacity = inventory.capacity,
		slots = slots,
	}
end

--[[
	Cantidad total de un item concreto sumando todas las ranuras que lo
	contienen.
]]
function InventoryCore.getTotalQuantity(inventory: Inventory, itemId: ItemId): number
	local total = 0
	for _, slot in inventory.slots do
		if slot.itemId == itemId then
			total += slot.quantity
		end
	end
	return total
end

function InventoryCore.countUsedSlots(inventory: Inventory): number
	return #inventory.slots
end

function InventoryCore.countFreeSlots(inventory: Inventory): number
	return inventory.capacity - #inventory.slots
end

--[[
	Comprueba, SIN mutar el inventario, si cabría `quantity` unidades del
	item descrito por `itemDef`: primero rellenando huecos en ranuras ya
	existentes de ese mismo item y luego usando ranuras libres.
]]
function InventoryCore.hasSpaceFor(inventory: Inventory, itemDef: ItemDefinition, quantity: number): boolean
	assert(isPositiveInteger(quantity), "quantity debe ser un entero positivo")

	local capacityAvailable = 0
	for _, slot in inventory.slots do
		if slot.itemId == itemDef.id then
			capacityAvailable += (itemDef.maxStack - slot.quantity)
		end
	end

	local freeSlots = InventoryCore.countFreeSlots(inventory)
	capacityAvailable += freeSlots * itemDef.maxStack

	return capacityAvailable >= quantity
end

--[[
	Añade `quantity` unidades de `itemDef` al inventario, apilando primero
	en ranuras existentes del mismo item y abriendo ranuras nuevas después,
	hasta agotar la capacidad. Muta `inventory` in-place.

	Devuelve cuánto se pudo añadir realmente (`added`) y cuánto sobró por
	falta de espacio (`overflow`). Nunca lanza error por falta de espacio:
	el llamador decide qué hacer con el overflow.
]]
function InventoryCore.addItem(inventory: Inventory, itemDef: ItemDefinition, quantity: number): AddResult
	assert(isPositiveInteger(quantity), "quantity debe ser un entero positivo")
	assert(isPositiveInteger(itemDef.maxStack), "itemDef.maxStack debe ser un entero positivo")

	local remaining = quantity

	for _, slot in inventory.slots do
		if remaining <= 0 then
			break
		end
		if slot.itemId == itemDef.id and slot.quantity < itemDef.maxStack then
			local space = itemDef.maxStack - slot.quantity
			local toAdd = math.min(space, remaining)
			slot.quantity += toAdd
			remaining -= toAdd
		end
	end

	while remaining > 0 and #inventory.slots < inventory.capacity do
		local toAdd = math.min(itemDef.maxStack, remaining)
		table.insert(inventory.slots, { itemId = itemDef.id, quantity = toAdd })
		remaining -= toAdd
	end

	return {
		added = quantity - remaining,
		overflow = remaining,
	}
end

--[[
	Quita `quantity` unidades de `itemId` del inventario, vaciando ranuras
	(y eliminándolas) según haga falta. Si no hay suficiente cantidad no
	muta nada y devuelve `false` con un mensaje de error.
]]
function InventoryCore.removeItem(inventory: Inventory, itemId: ItemId, quantity: number): (boolean, string?)
	if type(quantity) ~= "number" or not isPositiveInteger(quantity) then
		return false, "quantity debe ser un entero positivo"
	end

	local total = InventoryCore.getTotalQuantity(inventory, itemId)
	if total < quantity then
		return false, `cantidad insuficiente: hay {total}, se pidieron {quantity}`
	end

	local remaining = quantity
	local index = 1
	while index <= #inventory.slots and remaining > 0 do
		local slot = inventory.slots[index]
		if slot.itemId == itemId then
			local removeAmount = math.min(slot.quantity, remaining)
			slot.quantity -= removeAmount
			remaining -= removeAmount
			if slot.quantity == 0 then
				table.remove(inventory.slots, index)
				continue
			end
		end
		index += 1
	end

	return true, nil
end

--[[
	Convierte el inventario a datos planos (tablas y primitivos) aptos
	para persistir con DataStoreService o para enviar por una remota.
]]
function InventoryCore.serialize(inventory: Inventory): SerializedInventory
	local slots: { SerializedSlot } = table.create(#inventory.slots)
	for index, slot in inventory.slots do
		slots[index] = { itemId = slot.itemId, quantity = slot.quantity }
	end
	return {
		capacity = inventory.capacity,
		slots = slots,
	}
end

--[[
	Reconstruye un `Inventory` a partir de datos externos (DataStore, una
	remota, un fichero de guardado antiguo...) validando exhaustivamente
	su forma. Si se pasa `itemDefinitions`, además valida que cada
	`itemId` exista en el catálogo y que la cantidad no exceda su
	`maxStack`.

	Nunca lanza error: si algo no cuadra devuelve `nil` y un mensaje.
]]
function InventoryCore.deserialize(data: unknown, itemDefinitions: ItemDefinitions?): (Inventory?, string?)
	if type(data) ~= "table" then
		return nil, "data no es una tabla"
	end

	local raw = data :: { [string]: unknown }

	local capacity = raw.capacity
	if type(capacity) ~= "number" or not isNonNegativeInteger(capacity) then
		return nil, "capacity inválida: debe ser un entero no negativo"
	end

	local rawSlots = raw.slots
	if type(rawSlots) ~= "table" then
		return nil, "slots inválidos: debe ser una tabla"
	end

	local slots: { Slot } = {}
	for _, rawSlotValue in rawSlots :: { unknown } do
		if type(rawSlotValue) ~= "table" then
			return nil, "un slot no es una tabla"
		end
		local rawSlot = rawSlotValue :: { [string]: unknown }

		local itemId = rawSlot.itemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil, "itemId inválido en un slot"
		end

		local quantity = rawSlot.quantity
		if type(quantity) ~= "number" or not isPositiveInteger(quantity) then
			return nil, `quantity inválida en el slot de {itemId}`
		end

		if itemDefinitions then
			local itemDef = itemDefinitions[itemId]
			if not itemDef then
				return nil, `itemId desconocido: {itemId}`
			end
			if quantity > itemDef.maxStack then
				return nil, `quantity ({quantity}) excede maxStack ({itemDef.maxStack}) para {itemId}`
			end
		end

		table.insert(slots, { itemId = itemId, quantity = quantity })
	end

	if #slots > capacity then
		return nil, "hay más slots ocupados que capacidad"
	end

	return {
		capacity = capacity,
		slots = slots,
	}, nil
end

return InventoryCore
