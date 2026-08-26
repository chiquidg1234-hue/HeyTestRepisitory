--!strict
local Contador = require("../src/Contador")

local casos: { { nombre: string, run: () -> () } } = {}
local function test(nombre: string, run: () -> ())
	table.insert(casos, { nombre = nombre, run = run })
end
local function assertEq(a: any, b: any, msg: string?)
	if a ~= b then
		error(
			string.format(
				"%s: se esperaba %s, se obtuvo %s",
				msg or "assert",
				tostring(b),
				tostring(a)
			),
			0
		)
	end
end

test("empieza en cero", function()
	assertEq(Contador.nuevo(10).valor, 0)
end)
test("incrementa dentro del máximo", function()
	local e = Contador.nuevo(10)
	local ok = Contador.incrementar(e, 4)
	assertEq(ok, true)
	assertEq(e.valor, 4)
end)
test("rechaza superar el máximo", function()
	local e = Contador.nuevo(5)
	local ok, err = Contador.incrementar(e, 99)
	assertEq(ok, false)
	assertEq(err, "excede_maximo")
end)
test("rechaza cantidad no positiva", function()
	local ok, err = Contador.incrementar(Contador.nuevo(5), 0)
	assertEq(ok, false)
	assertEq(err, "cantidad_no_positiva")
end)

return casos
