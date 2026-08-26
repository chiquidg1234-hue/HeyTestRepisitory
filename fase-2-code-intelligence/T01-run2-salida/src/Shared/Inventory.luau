--!strict

--[[
	Inventory.luau

	Núcleo de lógica PURA del sistema de inventario.

	Este módulo NO hace `require` de ningún servicio de Roblox ni usa
	`game`, `script` ni `workspace`. Puede ejecutarse y probarse con
	cualquier intérprete de Luau standalone (ver tests/InventoryTests.luau).

	El estado del inventario es una tabla de datos simple (InventoryState).
	Todas las reglas de negocio (apilado, límites de espacio, serialización)
	viven aquí, para que sean 100% testeables fuera de Roblox. Las capas de
	servidor y cliente solo deben leer/mutar el estado a través de las
	funciones públicas de este módulo.
]]

local Inventory = {}

export type ItemId = string

export type ItemDefinition = {
	id: ItemId,
	maxStack: number,
}

export type ItemDefinitions = { [ItemId]: ItemDefinition }

export type ItemStack = {
	itemId: ItemId,
	quantity: number,
}

export type InventoryState = {
	capacity: number,
	slots: { ItemStack },
}

export type SerializedStack = {
	itemId: ItemId,
	quantity: number,
}

export type SerializedInventory = {
	capacity: number,
	slots: { SerializedStack },
}

local function isPositiveInteger(value: number): boolean
	return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function isNonNegativeInteger(value: number): boolean
	return type(value) == "number" and value >= 0 and value == math.floor(value)
end

--- Crea un inventario nuevo y vacío con la capacidad (número de slots) dada.
function Inventory.new(capacity: number): InventoryState
	assert(isNonNegativeInteger(capacity), "capacity must be a non-negative integer")
	return {
		capacity = capacity,
		slots = {},
	}
end

--- Devuelve la cantidad total de `itemId` que hay en el inventario, sumando
--- todos los slots en los que aparece.
function Inventory.getQuantity(state: InventoryState, itemId: ItemId): number
	local total = 0
	for _, stack in ipairs(state.slots) do
		if stack.itemId == itemId then
			total += stack.quantity
		end
	end
	return total
end

--- Devuelve cuántos slots libres (sin usar) quedan en el inventario.
function Inventory.freeSlots(state: InventoryState): number
	return state.capacity - #state.slots
end

type FillOperation = {
	index: number,
	amount: number,
}

type AdditionPlan = {
	fills: { FillOperation },
	newStacks: { number },
	added: number,
	remaining: number,
}

-- Calcula, SIN mutar `state`, cómo se repartiría `quantity` unidades de
-- `itemId`: primero rellenando slots existentes hasta `maxStack` y después
-- abriendo slots nuevos mientras haya capacidad libre. Es la base tanto de
-- `hasSpaceFor` (solo lectura) como de `addItem` (aplica el plan).
local function planAddition(
	state: InventoryState,
	defs: ItemDefinitions,
	itemId: ItemId,
	quantity: number
): (AdditionPlan?, string?)
	local definition = defs[itemId]
	if definition == nil then
		return nil, "unknown item id: " .. tostring(itemId)
	end
	if not isPositiveInteger(quantity) then
		return nil, "quantity must be a positive integer"
	end

	local maxStack = definition.maxStack
	local remaining = quantity
	local fills: { FillOperation } = {}

	for index, stack in ipairs(state.slots) do
		if remaining <= 0 then
			break
		end
		if stack.itemId == itemId and stack.quantity < maxStack then
			local space = maxStack - stack.quantity
			local amount = math.min(space, remaining)
			if amount > 0 then
				table.insert(fills, { index = index, amount = amount })
				remaining -= amount
			end
		end
	end

	local newStacks: { number } = {}
	local freeSlotCount = Inventory.freeSlots(state)
	while remaining > 0 and #newStacks < freeSlotCount do
		local amount = math.min(maxStack, remaining)
		table.insert(newStacks, amount)
		remaining -= amount
	end

	return {
		fills = fills,
		newStacks = newStacks,
		added = quantity - remaining,
		remaining = remaining,
	}, nil
end

--- Comprueba si `quantity` unidades de `itemId` caben en el inventario, sin
--- modificarlo. Devuelve también un mensaje de error si `itemId`/`quantity`
--- son inválidos.
function Inventory.hasSpaceFor(
	state: InventoryState,
	defs: ItemDefinitions,
	itemId: ItemId,
	quantity: number
): (boolean, string?)
	local plan, err = planAddition(state, defs, itemId, quantity)
	if plan == nil then
		return false, err
	end
	return plan.remaining == 0, nil
end

--- Añade `quantity` unidades de `itemId` al inventario, apilando primero en
--- slots existentes y abriendo slots nuevos solo si hace falta y hay hueco.
--- Devuelve (huboExitoTotal, cantidadRealmenteAñadida, mensajeDeError?).
--- Si no cabe todo, añade lo que quepa y `huboExitoTotal` es false.
function Inventory.addItem(
	state: InventoryState,
	defs: ItemDefinitions,
	itemId: ItemId,
	quantity: number
): (boolean, number, string?)
	local plan, err = planAddition(state, defs, itemId, quantity)
	if plan == nil then
		return false, 0, err
	end

	for _, fill in ipairs(plan.fills) do
		local stack = state.slots[fill.index]
		stack.quantity += fill.amount
	end

	for _, amount in ipairs(plan.newStacks) do
		table.insert(state.slots, { itemId = itemId, quantity = amount })
	end

	return plan.remaining == 0, plan.added, nil
end

--- Quita `quantity` unidades de `itemId` del inventario (empezando por los
--- últimos slots) y elimina los slots que queden a 0. Devuelve
--- (huboExitoTotal, cantidadRealmenteQuitada, mensajeDeError?).
function Inventory.removeItem(state: InventoryState, itemId: ItemId, quantity: number): (boolean, number, string?)
	if not isPositiveInteger(quantity) then
		return false, 0, "quantity must be a positive integer"
	end

	local remaining = quantity
	local removed = 0
	local index = #state.slots

	while index >= 1 and remaining > 0 do
		local stack = state.slots[index]
		if stack.itemId == itemId then
			local amount = math.min(stack.quantity, remaining)
			stack.quantity -= amount
			remaining -= amount
			removed += amount
			if stack.quantity <= 0 then
				table.remove(state.slots, index)
			end
		end
		index -= 1
	end

	return remaining == 0, removed, nil
end

--- Convierte el estado a una tabla de datos "plana" (sin metatablas ni
--- funciones), apta para DataStoreService:SetAsync/UpdateAsync o para
--- volcar a JSON con HttpService.
function Inventory.serialize(state: InventoryState): SerializedInventory
	local slots: { SerializedStack } = {}
	for i, stack in ipairs(state.slots) do
		slots[i] = { itemId = stack.itemId, quantity = stack.quantity }
	end
	return {
		capacity = state.capacity,
		slots = slots,
	}
end

--- Reconstruye un InventoryState a partir de datos serializados (por
--- ejemplo, los que devuelve DataStoreService:GetAsync). Valida la forma
--- de los datos y, si se pasa `defs`, también que cada itemId sea
--- conocido. Devuelve nil + mensaje de error si los datos son inválidos,
--- en vez de lanzar una excepción, para que el llamador decida qué hacer
--- con un perfil corrupto.
function Inventory.deserialize(data: any, defs: ItemDefinitions?): (InventoryState?, string?)
	if type(data) ~= "table" then
		return nil, "serialized data must be a table"
	end

	local raw = data :: { [string]: any }
	local capacity = raw.capacity
	if type(capacity) ~= "number" or not isNonNegativeInteger(capacity) then
		return nil, "invalid capacity"
	end

	local rawSlots = raw.slots
	if type(rawSlots) ~= "table" then
		return nil, "invalid slots"
	end

	local slots: { ItemStack } = {}
	for i, rawStack in ipairs(rawSlots :: { any }) do
		if type(rawStack) ~= "table" then
			return nil, "invalid stack at index " .. tostring(i)
		end
		local s = rawStack :: { [string]: any }
		local itemId = s.itemId
		local quantity = s.quantity
		if type(itemId) ~= "string" then
			return nil, "invalid itemId at index " .. tostring(i)
		end
		if type(quantity) ~= "number" or not isPositiveInteger(quantity) then
			return nil, "invalid quantity at index " .. tostring(i)
		end
		if defs ~= nil and defs[itemId] == nil then
			return nil, "unknown item id at index " .. tostring(i) .. ": " .. itemId
		end
		slots[i] = { itemId = itemId, quantity = quantity }
	end

	if #slots > capacity then
		return nil, "slots exceed capacity"
	end

	return {
		capacity = capacity,
		slots = slots,
	}, nil
end

return Inventory
