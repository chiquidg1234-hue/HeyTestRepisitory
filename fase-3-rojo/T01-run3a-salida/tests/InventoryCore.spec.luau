--!strict
--[[
	InventoryCore.spec
	===================

	Tests del núcleo puro. No dependen de Roblox: se pueden ejecutar con
	cualquier intérprete de Luau standalone, por ejemplo:

		luau tests/InventoryCore.spec.luau
		lune run tests/InventoryCore.spec.luau

	Sale con código de salida distinto de cero si alguna comprobación
	falla, para poder usarse en CI.
]]

local InventoryCore = require("../src/Shared/Inventory/InventoryCore")

local passCount = 0
local failCount = 0

local function check(condition: boolean, message: string)
	if condition then
		passCount += 1
	else
		failCount += 1
		print(`FALLO: {message}`)
	end
end

local function checkEqual(actual: unknown, expected: unknown, message: string)
	check(actual == expected, `{message} (esperado {tostring(expected)}, obtenido {tostring(actual)})`)
end

-- InventoryCore.new -----------------------------------------------------

do
	local inventory = InventoryCore.new(3)
	checkEqual(inventory.capacity, 3, "new: guarda la capacidad")
	checkEqual(#inventory.slots, 0, "new: empieza sin slots ocupados")
end

do
	local ok = pcall(function()
		InventoryCore.new(-1)
	end)
	check(not ok, "new: rechaza capacidad negativa")
end

-- InventoryCore.addItem: apilado -----------------------------------------

do
	local inventory = InventoryCore.new(2)
	local potion: InventoryCore.ItemDefinition = { id = "Potion", maxStack = 10 }

	local result1 = InventoryCore.addItem(inventory, potion, 4)
	checkEqual(result1.added, 4, "addItem: añade la cantidad pedida cuando hay sitio")
	checkEqual(result1.overflow, 0, "addItem: sin overflow cuando cabe todo")
	checkEqual(#inventory.slots, 1, "addItem: usa un solo slot para el primer añadido")

	local result2 = InventoryCore.addItem(inventory, potion, 3)
	checkEqual(result2.added, 3, "addItem: apila en el slot existente del mismo item")
	checkEqual(#inventory.slots, 1, "addItem: sigue usando un único slot tras apilar")
	checkEqual(inventory.slots[1].quantity, 7, "addItem: la cantidad apilada es correcta")
end

-- InventoryCore.addItem: overflow y nuevas ranuras -----------------------

do
	local inventory = InventoryCore.new(2)
	local sword: InventoryCore.ItemDefinition = { id = "Sword", maxStack = 1 }

	InventoryCore.addItem(inventory, sword, 1)
	InventoryCore.addItem(inventory, sword, 1)
	checkEqual(#inventory.slots, 2, "addItem: cada espada (maxStack 1) ocupa su propio slot")

	local result = InventoryCore.addItem(inventory, sword, 1)
	checkEqual(result.added, 0, "addItem: no añade nada si no hay sitio")
	checkEqual(result.overflow, 1, "addItem: reporta el overflow correcto")
	checkEqual(#inventory.slots, 2, "addItem: no crea slots por encima de la capacidad")
end

do
	local inventory = InventoryCore.new(1)
	local coin: InventoryCore.ItemDefinition = { id = "Coin", maxStack = 10 }

	local result = InventoryCore.addItem(inventory, coin, 15)
	checkEqual(result.added, 10, "addItem: añade parcialmente cuando solo cabe un stack")
	checkEqual(result.overflow, 5, "addItem: el resto queda como overflow")
end

-- InventoryCore.hasSpaceFor ------------------------------------------------

do
	local inventory = InventoryCore.new(1)
	local coin: InventoryCore.ItemDefinition = { id = "Coin", maxStack = 100 }

	check(InventoryCore.hasSpaceFor(inventory, coin, 100), "hasSpaceFor: true cuando cabe justo")
	check(not InventoryCore.hasSpaceFor(inventory, coin, 101), "hasSpaceFor: false cuando no cabe")
	check(InventoryCore.hasSpaceFor(inventory, coin, 100), "hasSpaceFor: no muta el inventario")
	checkEqual(#inventory.slots, 0, "hasSpaceFor: confirmado que no mutó el inventario")
end

-- InventoryCore.removeItem -------------------------------------------------

do
	local inventory = InventoryCore.new(2)
	local coin: InventoryCore.ItemDefinition = { id = "Coin", maxStack = 100 }
	InventoryCore.addItem(inventory, coin, 50)

	local ok, err = InventoryCore.removeItem(inventory, "Coin", 20)
	check(ok, "removeItem: elimina una cantidad válida")
	checkEqual(err, nil, "removeItem: no hay mensaje de error en el caso correcto")
	checkEqual(InventoryCore.getTotalQuantity(inventory, "Coin"), 30, "removeItem: la cantidad restante es correcta")

	local ok2, err2 = InventoryCore.removeItem(inventory, "Coin", 999)
	check(not ok2, "removeItem: falla si no hay cantidad suficiente")
	check(err2 ~= nil, "removeItem: da un mensaje de error al fallar")
	checkEqual(InventoryCore.getTotalQuantity(inventory, "Coin"), 30, "removeItem: no muta nada si falla")
end

do
	local inventory = InventoryCore.new(2)
	local coin: InventoryCore.ItemDefinition = { id = "Coin", maxStack = 100 }
	InventoryCore.addItem(inventory, coin, 10)

	local ok = InventoryCore.removeItem(inventory, "Coin", 10)
	check(ok, "removeItem: puede vaciar un slot por completo")
	checkEqual(#inventory.slots, 0, "removeItem: el slot vacío se elimina de la lista")
end

do
	local inventory = InventoryCore.new(1)

	local ok, err = InventoryCore.removeItem(inventory, "Coin", 1)
	check(not ok, "removeItem: falla sobre un item que no está en el inventario")
	check(err ~= nil, "removeItem: mensaje de error cuando el item no existe")
end

-- InventoryCore.serialize / deserialize: ida y vuelta ----------------------

do
	local inventory = InventoryCore.new(5)
	local coin: InventoryCore.ItemDefinition = { id = "Coin", maxStack = 100 }
	InventoryCore.addItem(inventory, coin, 42)

	local serialized = InventoryCore.serialize(inventory)
	checkEqual(serialized.capacity, 5, "serialize: conserva la capacidad")
	checkEqual(#serialized.slots, 1, "serialize: conserva el número de slots")

	local restored, err = InventoryCore.deserialize(serialized)
	check(restored ~= nil, "deserialize: reconstruye sin error datos válidos")
	checkEqual(err, nil, "deserialize: no hay mensaje de error en el caso correcto")

	if restored then
		checkEqual(restored.capacity, 5, "deserialize: la capacidad reconstruida es correcta")
		checkEqual(InventoryCore.getTotalQuantity(restored, "Coin"), 42, "deserialize: la cantidad reconstruida es correcta")
	end
end

-- InventoryCore.deserialize: rechaza datos corruptos -----------------------

do
	local restored, err = InventoryCore.deserialize("esto no es una tabla")
	check(restored == nil, "deserialize: rechaza un valor que no es tabla")
	check(err ~= nil, "deserialize: da mensaje de error para un valor no-tabla")
end

do
	local restored = InventoryCore.deserialize({ capacity = -1, slots = {} })
	check(restored == nil, "deserialize: rechaza capacidad negativa")
end

do
	local restored = InventoryCore.deserialize({
		capacity = 1,
		slots = { { itemId = "Coin", quantity = 5 }, { itemId = "Coin", quantity = 5 } },
	})
	check(restored == nil, "deserialize: rechaza más slots ocupados que capacidad")
end

do
	local restored = InventoryCore.deserialize({
		capacity = 1,
		slots = { { itemId = "Coin", quantity = -5 } },
	})
	check(restored == nil, "deserialize: rechaza cantidades negativas o no enteras")
end

-- InventoryCore.deserialize: validación contra el catálogo de items -------

do
	local definitions: InventoryCore.ItemDefinitions = {
		Coin = { id = "Coin", maxStack = 10 },
	}

	local restored, err = InventoryCore.deserialize({
		capacity = 1,
		slots = { { itemId = "Coin", quantity = 50 } },
	}, definitions)
	check(restored == nil, "deserialize: rechaza una cantidad que excede maxStack del catálogo")
	check(err ~= nil, "deserialize: da mensaje de error al exceder maxStack")

	local restoredUnknown = InventoryCore.deserialize({
		capacity = 1,
		slots = { { itemId = "ItemInventado", quantity = 1 } },
	}, definitions)
	check(restoredUnknown == nil, "deserialize: rechaza un itemId que no está en el catálogo")

	local restoredOk = InventoryCore.deserialize({
		capacity = 1,
		slots = { { itemId = "Coin", quantity = 5 } },
	}, definitions)
	check(restoredOk ~= nil, "deserialize: acepta datos válidos contra el catálogo")
end

-- Resultado ------------------------------------------------------------

print(`{passCount} comprobaciones OK, {failCount} fallos`)

if failCount > 0 then
	-- `os.exit` no existe en las definiciones de tipos de Roblox (por
	-- sandboxing, el runtime de Roblox no lo expone), pero sí en los
	-- intérpretes standalone (luau, lune) con los que se ejecuta este
	-- fichero. El cast a `any` evita el falso error de tipos al analizar
	-- este fichero con `--platform=roblox` sin afectar al runtime real.
	(os :: any).exit(1)
end
