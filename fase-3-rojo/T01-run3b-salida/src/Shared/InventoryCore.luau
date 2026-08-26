--!strict

--[[
	InventoryCore
	=================
	Lógica PURA del sistema de inventario. Este fichero no requiere
	ningún otro módulo, no usa `game`, `script`, `workspace` ni ningún
	servicio de Roblox: puede requerirse y ejecutarse tanto dentro de
	Roblox (vía Rojo) como con un intérprete de Luau independiente.

	Ver `tests/InventoryCore.test.luau` para un conjunto de pruebas que
	se ejecuta fuera de Roblox.
]]

local InventoryCore = {}

export type ItemId = string

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	maxStack: number,
}

export type ItemCatalog = { [ItemId]: ItemDefinition }

export type InventorySlot = {
	itemId: ItemId,
	quantity: number,
}

-- Inventario de slots fijos. `slots` es un mapa disperso: los índices
-- van de 1 a `capacitySlots`, y un índice ausente representa un slot
-- vacío.
export type Inventory = {
	capacitySlots: number,
	slots: { [number]: InventorySlot },
}

export type AddOutcome = {
	ok: boolean,
	added: number,
	remaining: number,
	errorMessage: string?,
}

export type RemoveOutcome = {
	ok: boolean,
	removed: number,
	errorMessage: string?,
}

export type SerializedSlot = {
	slot: number,
	itemId: ItemId,
	quantity: number,
}

-- Forma "plana" del inventario, sin huecos ni claves dispersas: apta
-- para guardar directamente en un DataStore.
export type SerializedInventory = {
	capacitySlots: number,
	slots: { SerializedSlot },
}

-- ---------------------------------------------------------------------
-- Utilidades internas
-- ---------------------------------------------------------------------

local function cloneInventory(inventory: Inventory): Inventory
	local slots: { [number]: InventorySlot } = {}
	for index, slot in pairs(inventory.slots) do
		slots[index] = { itemId = slot.itemId, quantity = slot.quantity }
	end
	return {
		capacitySlots = inventory.capacitySlots,
		slots = slots,
	}
end

local function isPositiveInteger(value: number): boolean
	return type(value) == "number"
		and value == value -- descarta NaN
		and value % 1 == 0
		and value > 0
end

-- ---------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------

function InventoryCore.new(capacitySlots: number): Inventory
	assert(isPositiveInteger(capacitySlots), "capacitySlots debe ser un entero positivo")
	return {
		capacitySlots = capacitySlots,
		slots = {},
	}
end

function InventoryCore.isValidItem(catalog: ItemCatalog, itemId: ItemId): boolean
	return catalog[itemId] ~= nil
end

function InventoryCore.getDefinition(catalog: ItemCatalog, itemId: ItemId): ItemDefinition?
	return catalog[itemId]
end

function InventoryCore.countItem(inventory: Inventory, itemId: ItemId): number
	local total = 0
	for _, slot in pairs(inventory.slots) do
		if slot.itemId == itemId then
			total += slot.quantity
		end
	end
	return total
end

-- Cuántas unidades más de `itemId` cabrían ahora mismo (stacks
-- parciales existentes + slots vacíos * maxStack).
function InventoryCore.getFreeSpaceFor(inventory: Inventory, catalog: ItemCatalog, itemId: ItemId): number
	local definition = catalog[itemId]
	if definition == nil then
		return 0
	end

	local free = 0

	for _, slot in pairs(inventory.slots) do
		if slot.itemId == itemId and slot.quantity < definition.maxStack then
			free += definition.maxStack - slot.quantity
		end
	end

	for index = 1, inventory.capacitySlots do
		if inventory.slots[index] == nil then
			free += definition.maxStack
		end
	end

	return free
end

function InventoryCore.hasSpaceFor(inventory: Inventory, catalog: ItemCatalog, itemId: ItemId, quantity: number): boolean
	if not isPositiveInteger(quantity) then
		return false
	end
	return InventoryCore.getFreeSpaceFor(inventory, catalog, itemId) >= quantity
end

-- Añade `quantity` unidades de `itemId`, apilando primero en stacks
-- parciales y abriendo slots vacíos después. Es pura: no muta
-- `inventory`, devuelve un inventario nuevo.
function InventoryCore.addItem(
	inventory: Inventory,
	catalog: ItemCatalog,
	itemId: ItemId,
	quantity: number
): (Inventory, AddOutcome)
	if not isPositiveInteger(quantity) then
		return inventory, { ok = false, added = 0, remaining = 0, errorMessage = "cantidad inválida" }
	end

	local definition = catalog[itemId]
	if definition == nil then
		return inventory,
			{ ok = false, added = 0, remaining = quantity, errorMessage = "item desconocido: " .. itemId }
	end

	local result = cloneInventory(inventory)
	local remaining = quantity
	local added = 0

	-- 1) apilar en slots parciales existentes
	for index = 1, result.capacitySlots do
		if remaining <= 0 then
			break
		end
		local slot = result.slots[index]
		if slot ~= nil and slot.itemId == itemId and slot.quantity < definition.maxStack then
			local space = definition.maxStack - slot.quantity
			local toAdd = math.min(space, remaining)
			slot.quantity += toAdd
			remaining -= toAdd
			added += toAdd
		end
	end

	-- 2) usar slots vacíos
	for index = 1, result.capacitySlots do
		if remaining <= 0 then
			break
		end
		if result.slots[index] == nil then
			local toAdd = math.min(definition.maxStack, remaining)
			result.slots[index] = { itemId = itemId, quantity = toAdd }
			remaining -= toAdd
			added += toAdd
		end
	end

	local outcome: AddOutcome = {
		ok = added > 0 and remaining == 0,
		added = added,
		remaining = remaining,
		errorMessage = if remaining > 0 then "espacio insuficiente" else nil,
	}

	return result, outcome
end

-- Quita `quantity` unidades de `itemId` de donde sea, empezando por
-- los slots con menor índice. Todo o nada: si no hay suficiente
-- cantidad total, no quita nada.
function InventoryCore.removeItem(inventory: Inventory, itemId: ItemId, quantity: number): (Inventory, RemoveOutcome)
	if not isPositiveInteger(quantity) then
		return inventory, { ok = false, removed = 0, errorMessage = "cantidad inválida" }
	end

	local available = InventoryCore.countItem(inventory, itemId)
	if available < quantity then
		return inventory, { ok = false, removed = 0, errorMessage = "cantidad insuficiente en inventario" }
	end

	local result = cloneInventory(inventory)
	local remaining = quantity

	for index = 1, result.capacitySlots do
		if remaining <= 0 then
			break
		end
		local slot = result.slots[index]
		if slot ~= nil and slot.itemId == itemId then
			local toRemove = math.min(slot.quantity, remaining)
			slot.quantity -= toRemove
			remaining -= toRemove
			if slot.quantity <= 0 then
				result.slots[index] = nil
			end
		end
	end

	return result, { ok = true, removed = quantity - remaining, errorMessage = nil }
end

-- Quita `quantity` unidades de un slot concreto por índice. Útil para
-- el servidor cuando el cliente solo puede referenciar "mi slot N",
-- nunca un itemId o cantidad arbitrarios.
function InventoryCore.removeFromSlot(inventory: Inventory, slotIndex: number, quantity: number): (Inventory, RemoveOutcome)
	if not isPositiveInteger(quantity) then
		return inventory, { ok = false, removed = 0, errorMessage = "cantidad inválida" }
	end
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > inventory.capacitySlots then
		return inventory, { ok = false, removed = 0, errorMessage = "slot fuera de rango" }
	end

	local slot = inventory.slots[slotIndex]
	if slot == nil then
		return inventory, { ok = false, removed = 0, errorMessage = "slot vacío" }
	end
	if slot.quantity < quantity then
		return inventory, { ok = false, removed = 0, errorMessage = "cantidad insuficiente en el slot" }
	end

	local result = cloneInventory(inventory)
	local resultSlot = result.slots[slotIndex] :: InventorySlot
	resultSlot.quantity -= quantity
	if resultSlot.quantity <= 0 then
		result.slots[slotIndex] = nil
	end

	return result, { ok = true, removed = quantity, errorMessage = nil }
end

-- Convierte el inventario a una forma plana, sin huecos, apta para
-- DataStoreService o para enviar al cliente.
function InventoryCore.serialize(inventory: Inventory): SerializedInventory
	local slots: { SerializedSlot } = {}
	for index = 1, inventory.capacitySlots do
		local slot = inventory.slots[index]
		if slot ~= nil then
			table.insert(slots, { slot = index, itemId = slot.itemId, quantity = slot.quantity })
		end
	end
	return {
		capacitySlots = inventory.capacitySlots,
		slots = slots,
	}
end

-- Reconstruye un inventario a partir de su forma serializada. Ignora
-- entradas con índices fuera de rango o cantidades inválidas en lugar
-- de fallar, para tolerar datos guardados con una capacidad distinta.
function InventoryCore.deserialize(data: SerializedInventory): Inventory
	local inventory = InventoryCore.new(data.capacitySlots)
	for _, entry in ipairs(data.slots) do
		if entry.slot >= 1 and entry.slot <= inventory.capacitySlots and isPositiveInteger(entry.quantity) then
			inventory.slots[entry.slot] = { itemId = entry.itemId, quantity = entry.quantity }
		end
	end
	return inventory
end

return InventoryCore
