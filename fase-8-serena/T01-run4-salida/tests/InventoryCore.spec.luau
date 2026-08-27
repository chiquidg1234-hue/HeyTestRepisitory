--!strict

--[[
	Tests del núcleo puro InventoryCore.

	Se ejecuta SIN Roblox, con el intérprete standalone `luau`:

		luau tests/InventoryCore.spec.luau

	No usa ninguna librería de testing externa: solo `assert`/`error`, que
	son parte del Luau base. Si alguna comprobación falla, el script termina
	llamando a `error(...)`, lo que hace que el proceso `luau` salga con
	código distinto de cero (y con el intérprete de referencia, `assert`
	fallido también aborta con código distinto de cero).
]]

local InventoryCore = require("../src/Shared/InventoryCore")

type ItemDatabase = InventoryCore.ItemDatabase

local database: ItemDatabase = {
	Wood = { id = "Wood", displayName = "Madera", maxStack = 10 },
	GoldCoin = { id = "GoldCoin", displayName = "Moneda de oro", maxStack = 999 },
	Sword = { id = "Sword", displayName = "Espada", maxStack = 1 },
}

local totalChecks = 0
local failedChecks = 0

local function check(name: string, condition: boolean, detail: string?): ()
	totalChecks += 1
	if condition then
		print(string.format("[OK]   %s", name))
	else
		failedChecks += 1
		local suffix = if detail ~= nil then " -- " .. detail else ""
		print(string.format("[FAIL] %s%s", name, suffix))
	end
end

local function equalsDeep(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not equalsDeep(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- ============================================================================
-- new / consultas básicas
-- ============================================================================

do
	local inv = InventoryCore.new(5)
	check("new: capacidad correcta", inv.capacity == 5)
	check("new: empieza vacío", InventoryCore.getUsedSlots(inv) == 0)
	check("new: hueco libre = capacidad", InventoryCore.getFreeSlotCount(inv) == 5)
	check("new: cantidad de item inexistente es 0", InventoryCore.getQuantity(inv, "Wood") == 0)
end

-- ============================================================================
-- addItem: apilado dentro de un slot
-- ============================================================================

do
	local inv = InventoryCore.new(5)
	local inv2, added, err = InventoryCore.addItem(inv, database, "Wood", 4)
	check("addItem: añade la cantidad pedida", added == 4, tostring(err))
	check("addItem: no muta el original", InventoryCore.getUsedSlots(inv) == 0)
	check("addItem: crea un slot", InventoryCore.getUsedSlots(inv2) == 1)
	check("addItem: cantidad total correcta", InventoryCore.getQuantity(inv2, "Wood") == 4)
end

-- ============================================================================
-- addItem: crea varios slots cuando se supera maxStack
-- ============================================================================

do
	local inv = InventoryCore.new(5)
	local inv2 = InventoryCore.addItem(inv, database, "Wood", 25)
	check("addItem: reparte en varios slots (maxStack=10)", InventoryCore.getUsedSlots(inv2) == 3)
	check("addItem: cantidad total tras repartir", InventoryCore.getQuantity(inv2, "Wood") == 25)
end

-- ============================================================================
-- addItem: respeta la capacidad de slots
-- ============================================================================

do
	local inv = InventoryCore.new(1)
	local inv2, added, err = InventoryCore.addItem(inv, database, "Wood", 25) -- necesita 3 slots, solo hay 1
	check("addItem: rechaza si no cabe (todo o nada)", added == 0)
	check("addItem: devuelve un mensaje de error", err ~= nil)
	check("addItem: el estado no cambia si falla", InventoryCore.getUsedSlots(inv2) == 0)
end

-- ============================================================================
-- addItem: item desconocido
-- ============================================================================

do
	local inv = InventoryCore.new(5)
	local canAdd, err = InventoryCore.canAdd(inv, database, "ItemQueNoExiste", 1)
	check("canAdd: rechaza item desconocido", canAdd == false)
	check("canAdd: da un motivo", err ~= nil)
end

-- ============================================================================
-- comprobar espacio (getAvailableSpace)
-- ============================================================================

do
	local inv = InventoryCore.new(2)
	local inv2 = InventoryCore.addItem(inv, database, "Wood", 3) -- 1 slot con 3/10
	local space = InventoryCore.getAvailableSpace(inv2, database, "Wood")
	-- slot existente: 10-3=7 huecos + 1 slot libre * 10 = 17
	check("getAvailableSpace: cuenta hueco en slot existente + slots libres", space == 17, tostring(space))
end

-- ============================================================================
-- removeItem
-- ============================================================================

do
	local inv = InventoryCore.new(5)
	local inv2 = InventoryCore.addItem(inv, database, "Wood", 15) -- 2 slots: 10 + 5
	local inv3, ok, err = InventoryCore.removeItem(inv2, "Wood", 12)
	check("removeItem: quita la cantidad exacta", ok == true, tostring(err))
	check("removeItem: no muta el estado anterior", InventoryCore.getQuantity(inv2, "Wood") == 15)
	check("removeItem: cantidad restante correcta", InventoryCore.getQuantity(inv3, "Wood") == 3)
	check("removeItem: elimina slots vaciados", InventoryCore.getUsedSlots(inv3) == 1)
end

do
	local inv = InventoryCore.new(5)
	local inv2 = InventoryCore.addItem(inv, database, "Wood", 5)
	local inv3, ok, err = InventoryCore.removeItem(inv2, "Wood", 999)
	check("removeItem: rechaza si no hay suficiente", ok == false)
	check("removeItem: da un motivo", err ~= nil)
	check("removeItem: el estado no cambia si falla", InventoryCore.getQuantity(inv3, "Wood") == 5)
end

-- ============================================================================
-- serialize / deserialize
-- ============================================================================

do
	local inv = InventoryCore.new(5)
	inv = InventoryCore.addItem(inv, database, "Wood", 15)
	inv = InventoryCore.addItem(inv, database, "GoldCoin", 40)

	local serialized = InventoryCore.serialize(inv)
	local restored, err = InventoryCore.deserialize(serialized)

	check("deserialize: recupera un estado", restored ~= nil, tostring(err))
	if restored ~= nil then
		check("serialize/deserialize: viaje de ida y vuelta preserva los datos", equalsDeep(inv, restored))
	end
end

do
	local restored, err = InventoryCore.deserialize("esto no es una tabla")
	check("deserialize: rechaza datos que no son tabla", restored == nil)
	check("deserialize: da un motivo", err ~= nil)
end

do
	local restored, err = InventoryCore.deserialize({ capacity = "cinco", slots = {} })
	check("deserialize: rechaza capacity no numérica", restored == nil)
	check("deserialize: da un motivo", err ~= nil)
end

do
	-- 2 slots declarados pero capacity=1: inconsistente, debe rechazarse.
	local restored, err = InventoryCore.deserialize({
		capacity = 1,
		slots = { { itemId = "Wood", quantity = 3 }, { itemId = "GoldCoin", quantity = 1 } },
	})
	check("deserialize: rechaza más slots que capacity", restored == nil)
	check("deserialize: da un motivo", err ~= nil)
end

do
	local restored, err = InventoryCore.deserialize({
		capacity = 5,
		slots = { { itemId = "Wood", quantity = -3 } },
	})
	check("deserialize: rechaza cantidades negativas", restored == nil)
	check("deserialize: da un motivo", err ~= nil)
end

-- ============================================================================
-- resumen
-- ============================================================================

print(string.format("\n%d/%d pruebas superadas", totalChecks - failedChecks, totalChecks))

if failedChecks > 0 then
	error(string.format("%d prueba(s) fallida(s) en InventoryCore.spec.luau", failedChecks))
end
