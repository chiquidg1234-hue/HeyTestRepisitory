--!strict
--[[ Runner mínimo sobre Lune. ~40 líneas, sin dependencias muertas.
     Descubre tests/*.spec.luau, los ejecuta y sale con código != 0 si algo falla. ]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local pasados, fallos = 0, {}

for _, entrada in fs.readDir("tests") do
	if string.match(entrada, "%.spec%.luau$") then
		local modulo = string.gsub(entrada, "%.luau$", "")
		local ok, casos = pcall(require, "./" .. modulo)
		if not ok then
			table.insert(
				fallos,
				string.format("%s -> no se pudo cargar: %s", entrada, tostring(casos))
			)
		else
			for _, caso in casos do
				local exito, err = pcall(caso.run)
				if exito then
					pasados += 1
					print(string.format("  [OK]   %s :: %s", entrada, caso.nombre))
				else
					table.insert(
						fallos,
						string.format("%s :: %s -> %s", entrada, caso.nombre, tostring(err))
					)
					print(string.format("  [FAIL] %s :: %s", entrada, caso.nombre))
				end
			end
		end
	end
end

print(string.format("\n%d pasados, %d fallos", pasados, #fallos))
if #fallos > 0 then
	for _, f in fallos do
		print("  ! " .. f)
	end
	process.exit(1)
end
process.exit(0)
