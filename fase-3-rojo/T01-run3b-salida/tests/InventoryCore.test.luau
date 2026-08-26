--!strict

--[[
	Tests del núcleo puro de inventario. No dependen de Roblox: se
	ejecutan con un intérprete de Luau independiente, por ejemplo:

		luau tests/InventoryCore.test.luau

	Termina con código de salida 0 si todo pasa, o 1 si algo falla.
]]

local InventoryCore = require("../src/Shared/InventoryCore")

type ItemCatalog = InventoryCore.ItemCatalog

local catalog: ItemCatalog = {
	potion = { id = "potion", displayName = "Poción", maxStack = 5 },
	coin = { id = "coin", displayName = "Moneda", maxStack = 100 },
	sword = { id = "sword", displayName = "Espada", maxStack = 1 },
}

local total = 0
local failures = 0

local function check(name: string, condition: boolean, detail: string?): ()
	total += 1
	if condition then
		print("  [OK] " .. name)
	else
		failures += 1
		print("  [FAIL] " .. name .. (if detail then " -- " .. detail else ""))
	end
end

local function section(name: string): ()
	print("\n" .. name)
end

section("InventoryCore.new")
do
	local inventory = InventoryCore.new(4)
	check("crea con la capacidad pedida", inventory.capacitySlots == 4)
	check("empieza vacío", InventoryCore.countItem(inventory, "potion") == 0)
end

section("addItem: apilado básico")
do
	local inventory = InventoryCore.new(4)
	local next1, outcome1 = InventoryCore.addItem(inventory, catalog, "potion", 3)
	check("añade toda la cantidad cuando cabe", outcome1.ok and outcome1.added == 3)
	check("cuenta correctamente tras añadir", InventoryCore.countItem(next1, "potion") == 3)

	-- maxStack de potion es 5: el primer slot admite 2 más, y el resto
	-- abre un segundo slot con las 2 unidades restantes.
	local next2, outcome2 = InventoryCore.addItem(next1, catalog, "potion", 4)
	check("apila en el slot parcial antes de abrir uno nuevo", outcome2.ok and outcome2.added == 4)
	check("total tras segunda adición", InventoryCore.countItem(next2, "potion") == 7)
end

section("addItem: espacio insuficiente")
do
	local inventory = InventoryCore.new(1)
	local next1, outcome1 = InventoryCore.addItem(inventory, catalog, "coin", 150)
	check("añade lo que cabe y reporta el resto", outcome1.added == 100 and outcome1.remaining == 50)
	check("marca ok=false si no cupo todo", outcome1.ok == false)
	check("no pierde lo que sí cupo", InventoryCore.countItem(next1, "coin") == 100)
end

section("addItem: validaciones")
do
	local inventory = InventoryCore.new(4)

	local _, badItem = InventoryCore.addItem(inventory, catalog, "dragon_egg", 1)
	check("rechaza item desconocido", badItem.ok == false and badItem.errorMessage ~= nil)

	local _, badQty1 = InventoryCore.addItem(inventory, catalog, "coin", 0)
	check("rechaza cantidad cero", badQty1.ok == false)

	local _, badQty2 = InventoryCore.addItem(inventory, catalog, "coin", -5)
	check("rechaza cantidad negativa", badQty2.ok == false)

	local _, badQty3 = InventoryCore.addItem(inventory, catalog, "coin", 1.5)
	check("rechaza cantidad no entera", badQty3.ok == false)
end

section("hasSpaceFor / getFreeSpaceFor")
do
	local inventory = InventoryCore.new(2)
	inventory = (InventoryCore.addItem(inventory, catalog, "sword", 1))

	check("un slot libre queda tras ocupar uno", InventoryCore.getFreeSpaceFor(inventory, catalog, "sword") == 1)
	check("hasSpaceFor es true dentro del límite", InventoryCore.hasSpaceFor(inventory, catalog, "sword", 1))
	check("hasSpaceFor es false por encima del límite", not InventoryCore.hasSpaceFor(inventory, catalog, "sword", 2))
end

section("removeItem")
do
	local inventory = InventoryCore.new(4)
	inventory = (InventoryCore.addItem(inventory, catalog, "coin", 250))

	local next1, outcome1 = InventoryCore.removeItem(inventory, "coin", 150)
	check("quita la cantidad pedida repartida entre slots", outcome1.ok and outcome1.removed == 150)
	check("deja el resto correcto", InventoryCore.countItem(next1, "coin") == 100)

	local _, outcomeFail = InventoryCore.removeItem(inventory, "coin", 999)
	check("rechaza quitar más de lo que hay", outcomeFail.ok == false)
end

section("removeFromSlot")
do
	local inventory = InventoryCore.new(2)
	inventory = (InventoryCore.addItem(inventory, catalog, "sword", 1))

	local _, outOfRange = InventoryCore.removeFromSlot(inventory, 99, 1)
	check("rechaza un slot fuera de rango", outOfRange.ok == false)

	local _, emptySlot = InventoryCore.removeFromSlot(inventory, 2, 1)
	check("rechaza quitar de un slot vacío", emptySlot.ok == false)

	local next1, ok1 = InventoryCore.removeFromSlot(inventory, 1, 1)
	check("quita del slot indicado", ok1.ok and ok1.removed == 1)
	check("el slot queda vacío tras vaciarlo", InventoryCore.countItem(next1, "sword") == 0)
end

section("serialize / deserialize")
do
	local inventory = InventoryCore.new(3)
	inventory = (InventoryCore.addItem(inventory, catalog, "potion", 5))
	inventory = (InventoryCore.addItem(inventory, catalog, "coin", 40))

	local serialized = InventoryCore.serialize(inventory)
	check("serializa la capacidad", serialized.capacitySlots == 3)
	check("serializa solo los slots ocupados", #serialized.slots == 2)

	local restored = InventoryCore.deserialize(serialized)
	check("restaura la capacidad", restored.capacitySlots == inventory.capacitySlots)
	check(
		"restaura las cantidades",
		InventoryCore.countItem(restored, "potion") == 5 and InventoryCore.countItem(restored, "coin") == 40
	)
end

print(("\n%d/%d comprobaciones correctas"):format(total - failures, total))

if failures > 0 then
	print(failures .. " comprobación(es) fallida(s)")
	os.exit(1)
end

os.exit(0)
