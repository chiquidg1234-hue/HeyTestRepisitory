--!strict
--[[
	InventoryCore.spec.luau

	Tests del nucleo puro. No usa ningun servicio de Roblox (solo requiere
	InventoryCore.luau e ItemCatalog.luau, ambos puros), asi que se puede
	ejecutar directamente con el interprete Luau standalone:

		luau tests/InventoryCore.spec.luau

	El script termina llamando a error() (codigo de salida del proceso
	distinto de cero) si cualquier test falla, y termina normalmente
	(codigo 0) si todos pasan.
]]

local InventoryCore = require("../src/ReplicatedStorage/Shared/InventoryCore")
local ItemCatalog = require("../src/ReplicatedStorage/Shared/ItemCatalog")

type TestCase = {
	name: string,
	run: () -> (),
}

local tests: { TestCase } = {}
local failures: { string } = {}

local function test(name: string, run: () -> ())
	table.insert(tests, { name = name, run = run })
end

local function expectEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"%s (esperado=%s, obtenido=%s)",
				message or "valores distintos",
				tostring(expected),
				tostring(actual)
			),
			0
		)
	end
end

local function expectTrue(condition: boolean, message: string?)
	if not condition then
		error(message or "se esperaba 'true'", 0)
	end
end

-- ============================================================================
-- Casos de prueba
-- ============================================================================

test("new crea un inventario vacio con la capacidad indicada", function()
	local inv = InventoryCore.new(5)
	expectEqual(inv.capacity, 5, "capacidad incorrecta")
	expectEqual(InventoryCore.getFreeSlotCount(inv), 5, "slots libres incorrectos")
end)

test("addItem apila hasta el maximo antes de abrir un slot nuevo", function()
	local inv = InventoryCore.new(3)

	local result1 = InventoryCore.addItem(inv, ItemCatalog, "Potion", 4)
	expectTrue(result1.ok, "primer add deberia tener exito")
	expectEqual(result1.added, 4)
	expectEqual(inv.slots[1].quantity, 4)

	-- maxStack de Potion es 10 -> 6 caben en el slot 1, 2 abren un slot nuevo
	local result2 = InventoryCore.addItem(inv, ItemCatalog, "Potion", 8)
	expectTrue(result2.ok, "segundo add deberia tener exito")
	expectEqual(result2.added, 8)
	expectEqual(inv.slots[1].quantity, 10)
	expectEqual(inv.slots[2].quantity, 2)
end)

test("addItem devuelve error para item desconocido", function()
	local inv = InventoryCore.new(3)
	local result = InventoryCore.addItem(inv, ItemCatalog, "ItemQueNoExiste", 1)
	expectTrue(not result.ok, "deberia fallar")
	expectEqual(result.errorMessage, "unknown_item")
end)

test("addItem devuelve error para cantidad invalida", function()
	local inv = InventoryCore.new(3)

	local result = InventoryCore.addItem(inv, ItemCatalog, "Coin", 0)
	expectTrue(not result.ok, "cantidad 0 deberia fallar")
	expectEqual(result.errorMessage, "invalid_quantity")

	local result2 = InventoryCore.addItem(inv, ItemCatalog, "Coin", -3)
	expectTrue(not result2.ok, "cantidad negativa deberia fallar")
	expectEqual(result2.errorMessage, "invalid_quantity")
end)

test("addItem reporta sobrante cuando no hay espacio suficiente", function()
	local inv = InventoryCore.new(1) -- un unico slot

	local first = InventoryCore.addItem(inv, ItemCatalog, "Sword", 1) -- maxStack Sword = 1, llena el slot
	expectTrue(first.ok)

	local second = InventoryCore.addItem(inv, ItemCatalog, "Shield", 1)
	expectTrue(not second.ok, "no deberia caber, el inventario esta lleno")
	expectEqual(second.added, 0)
	expectEqual(second.leftover, 1)
	expectEqual(second.errorMessage, "not_enough_space")
end)

test("hasSpaceFor no muta el inventario", function()
	local inv = InventoryCore.new(2)
	local before = InventoryCore.getFreeSlotCount(inv)

	local fits = InventoryCore.hasSpaceFor(inv, ItemCatalog, "Coin", 500)
	expectTrue(fits, "deberia caber una pila de monedas")
	expectEqual(InventoryCore.getFreeSlotCount(inv), before, "no deberia mutar el inventario")
end)

test("removeItem quita cantidades repartidas entre varios slots y libera los vacios", function()
	local inv = InventoryCore.new(3)
	InventoryCore.addItem(inv, ItemCatalog, "Potion", 10)
	InventoryCore.addItem(inv, ItemCatalog, "Potion", 5)

	local result = InventoryCore.removeItem(inv, "Potion", 12)
	expectTrue(result.ok)
	expectEqual(result.removed, 12)
	expectEqual(InventoryCore.getItemCount(inv, "Potion"), 3)
end)

test("removeItem falla de forma atomica si no hay suficiente cantidad", function()
	local inv = InventoryCore.new(3)
	InventoryCore.addItem(inv, ItemCatalog, "Coin", 5)

	local result = InventoryCore.removeItem(inv, "Coin", 999)
	expectTrue(not result.ok)
	expectEqual(result.errorMessage, "insufficient_quantity")
	-- no debe haberse tocado nada
	expectEqual(InventoryCore.getItemCount(inv, "Coin"), 5)
end)

test("serialize/deserialize hace un roundtrip fiel", function()
	local inv = InventoryCore.new(10)
	InventoryCore.addItem(inv, ItemCatalog, "Sword", 1)
	InventoryCore.addItem(inv, ItemCatalog, "Potion", 7)
	InventoryCore.addItem(inv, ItemCatalog, "Coin", 250)

	local serialized = InventoryCore.serialize(inv)
	local restored, err = InventoryCore.deserialize(serialized)

	expectEqual(err, nil, "deserialize no deberia dar error")
	expectTrue(restored ~= nil, "deberia poder deserializar")

	if restored ~= nil then
		expectEqual(restored.capacity, inv.capacity)
		expectEqual(InventoryCore.getItemCount(restored, "Sword"), 1)
		expectEqual(InventoryCore.getItemCount(restored, "Potion"), 7)
		expectEqual(InventoryCore.getItemCount(restored, "Coin"), 250)
	end
end)

test("deserialize rechaza entradas malformadas", function()
	local restored, err = InventoryCore.deserialize("basura-no-valida")
	expectTrue(restored == nil, "no deberia poder deserializar basura")
	expectTrue(err ~= nil)
end)

test("deserialize rechaza version desconocida", function()
	local restored, err = InventoryCore.deserialize("99|10")
	expectTrue(restored == nil)
	expectEqual(err, "unsupported_version")
end)

test("clone produce una copia independiente", function()
	local inv = InventoryCore.new(2)
	InventoryCore.addItem(inv, ItemCatalog, "Coin", 10)

	local copy = InventoryCore.clone(inv)
	InventoryCore.addItem(copy, ItemCatalog, "Coin", 5)

	expectEqual(InventoryCore.getItemCount(inv, "Coin"), 10, "el original no deberia cambiar")
	expectEqual(InventoryCore.getItemCount(copy, "Coin"), 15)
end)

-- ============================================================================
-- Runner
-- ============================================================================

local passed = 0
for _, case in ipairs(tests) do
	local ok, err = pcall(case.run)
	if ok then
		passed += 1
		print(string.format("[OK]   %s", case.name))
	else
		table.insert(failures, string.format("%s -> %s", case.name, tostring(err)))
		print(string.format("[FAIL] %s -> %s", case.name, tostring(err)))
	end
end

print(string.format("\n%d/%d tests pasados", passed, #tests))

if #failures > 0 then
	error(string.format("%d test(s) fallaron:\n - %s", #failures, table.concat(failures, "\n - ")), 0)
end
