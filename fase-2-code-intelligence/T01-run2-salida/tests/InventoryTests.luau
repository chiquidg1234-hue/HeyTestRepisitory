--!strict

--[[
	InventoryTests.luau

	Tests del núcleo puro de inventario. Se ejecutan sin Roblox, con el
	intérprete standalone de Luau:

		luau tests/InventoryTests.luau

	Si cualquier comprobación falla, el script termina con `error(...)`,
	lo que hace que el proceso salga con código distinto de cero.
]]

local Inventory = require("../src/Shared/Inventory")

type ItemDefinitions = Inventory.ItemDefinitions

local defs: ItemDefinitions = {
	Wood = { id = "Wood", maxStack = 10 },
	Sword = { id = "Sword", maxStack = 1 },
	Potion = { id = "Potion", maxStack = 5 },
}

local passed = 0
local failed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		table.insert(failures, name)
	end
end

-- 1. new / getQuantity en inventario vacío
do
	local inv = Inventory.new(4)
	check("new: capacidad correcta", inv.capacity == 4)
	check("new: sin slots ocupados", #inv.slots == 0)
	check("getQuantity: 0 en inventario vacío", Inventory.getQuantity(inv, "Wood") == 0)
end

-- 2. addItem apila hasta el máximo antes de abrir un slot nuevo
do
	local inv = Inventory.new(4)
	local ok1, added1 = Inventory.addItem(inv, defs, "Wood", 7)
	check("addItem: éxito dentro del stack", ok1 == true and added1 == 7)
	check("addItem: una sola slot ocupada", #inv.slots == 1)

	-- 7 + 6 = 13, maxStack 10 -> el primer slot llega a 10 (añade 3) y
	-- sobran 3 unidades en un slot nuevo.
	local ok2, added2 = Inventory.addItem(inv, defs, "Wood", 6)
	check("addItem: éxito al abrir un segundo slot", ok2 == true and added2 == 6)
	check("addItem: dos slots ocupados", #inv.slots == 2)
	check("getQuantity: total correcto tras apilar", Inventory.getQuantity(inv, "Wood") == 13)
end

-- 3. addItem respeta maxStack = 1 (item no apilable): un slot por unidad
do
	local inv = Inventory.new(4)
	local ok, added = Inventory.addItem(inv, defs, "Sword", 3)
	check("addItem: no apilable abre un slot por unidad", #inv.slots == 3)
	check("addItem: no apilable añade todo lo que cabe", ok == true and added == 3)
end

-- 4. addItem falla cuando no hay espacio suficiente
do
	local inv = Inventory.new(1)
	local ok1 = Inventory.addItem(inv, defs, "Potion", 5)
	check("addItem: llena el único slot", ok1 == true)

	local ok2, added2 = Inventory.addItem(inv, defs, "Potion", 5)
	check("addItem: sin espacio -> falla", ok2 == false)
	check("addItem: sin espacio -> no añade nada", added2 == 0)
end

-- 5. addItem con item desconocido o cantidades inválidas
do
	local inv = Inventory.new(4)

	local ok1, added1, err1 = Inventory.addItem(inv, defs, "Unknown", 1)
	check("addItem: item desconocido falla", ok1 == false and added1 == 0 and err1 ~= nil)

	local ok2, added2, err2 = Inventory.addItem(inv, defs, "Wood", 0)
	check("addItem: cantidad 0 falla", ok2 == false and added2 == 0 and err2 ~= nil)

	local ok3, added3, err3 = Inventory.addItem(inv, defs, "Wood", -1)
	check("addItem: cantidad negativa falla", ok3 == false and added3 == 0 and err3 ~= nil)

	local ok4, added4, err4 = Inventory.addItem(inv, defs, "Wood", 1.5)
	check("addItem: cantidad no entera falla", ok4 == false and added4 == 0 and err4 ~= nil)
end

-- 6. hasSpaceFor no muta el inventario
do
	local inv = Inventory.new(1)
	Inventory.addItem(inv, defs, "Wood", 5)

	local fits = Inventory.hasSpaceFor(inv, defs, "Wood", 5)
	check("hasSpaceFor: cabe en el mismo slot", fits == true)

	local fitsTooMuch = Inventory.hasSpaceFor(inv, defs, "Wood", 6)
	check("hasSpaceFor: no cabe más del máximo del slot", fitsTooMuch == false)

	check("hasSpaceFor: no muta el inventario", Inventory.getQuantity(inv, "Wood") == 5)
end

-- 7. removeItem quita cantidades y limpia los slots que quedan vacíos
do
	local inv = Inventory.new(4)
	Inventory.addItem(inv, defs, "Wood", 13) -- 2 slots: 10 + 3

	local ok, removed = Inventory.removeItem(inv, "Wood", 4)
	check("removeItem: quita del último slot primero", ok == true and removed == 4)
	check("getQuantity: total correcto tras quitar", Inventory.getQuantity(inv, "Wood") == 9)

	local ok2, removed2 = Inventory.removeItem(inv, "Wood", 100)
	check("removeItem: quitar más de lo que hay falla parcialmente", ok2 == false and removed2 == 9)
	check("removeItem: el inventario queda vacío", #inv.slots == 0)
	check("getQuantity: 0 tras vaciar", Inventory.getQuantity(inv, "Wood") == 0)
end

-- 8. removeItem con cantidad inválida
do
	local inv = Inventory.new(4)
	Inventory.addItem(inv, defs, "Wood", 5)

	local ok, removed, err = Inventory.removeItem(inv, "Wood", 0)
	check("removeItem: cantidad 0 falla", ok == false and removed == 0 and err ~= nil)
end

-- 9. serialize / deserialize hacen un roundtrip fiel
do
	local inv = Inventory.new(4)
	Inventory.addItem(inv, defs, "Wood", 13)
	Inventory.addItem(inv, defs, "Potion", 2)

	local serialized = Inventory.serialize(inv)
	check("serialize: capacidad correcta", serialized.capacity == 4)
	check("serialize: número de slots correcto", #serialized.slots == 3)

	local restored, err = Inventory.deserialize(serialized, defs)
	check("deserialize: no da error", restored ~= nil and err == nil)
	if restored ~= nil then
		check("deserialize: capacidad restaurada", restored.capacity == 4)
		check("deserialize: cantidad de Wood restaurada", Inventory.getQuantity(restored, "Wood") == 13)
		check("deserialize: cantidad de Potion restaurada", Inventory.getQuantity(restored, "Potion") == 2)
	end
end

-- 10. deserialize rechaza datos corruptos
do
	local bad1, err1 = Inventory.deserialize("not a table")
	check("deserialize: rechaza algo que no es tabla", bad1 == nil and err1 ~= nil)

	local bad2, err2 = Inventory.deserialize({ capacity = -1, slots = {} })
	check("deserialize: rechaza capacidad negativa", bad2 == nil and err2 ~= nil)

	local bad3, err3 = Inventory.deserialize({
		capacity = 1,
		slots = { { itemId = "Wood", quantity = 1 }, { itemId = "Wood", quantity = 1 } },
	})
	check("deserialize: rechaza más slots que capacidad", bad3 == nil and err3 ~= nil)

	local bad4, err4 = Inventory.deserialize({
		capacity = 1,
		slots = { { itemId = "Unknown", quantity = 1 } },
	}, defs)
	check("deserialize: rechaza item desconocido si se pasan defs", bad4 == nil and err4 ~= nil)
end

print(string.format("[InventoryTests] %d OK, %d FALLOS", passed, failed))

if failed > 0 then
	for _, name in ipairs(failures) do
		print("  FALLO: " .. name)
	end
	error(string.format("InventoryTests: %d test(s) fallaron", failed))
end
