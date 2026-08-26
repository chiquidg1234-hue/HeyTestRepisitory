--!strict
--[[ Módulo correcto: lógica pura, sin servicios de Roblox. ]]

local Contador = {}

export type Estado = { valor: number, maximo: number }

function Contador.nuevo(maximo: number): Estado
	return { valor = 0, maximo = maximo }
end

function Contador.incrementar(estado: Estado, cantidad: number): (boolean, string?)
	if cantidad <= 0 then
		return false, "cantidad_no_positiva"
	end
	if estado.valor + cantidad > estado.maximo then
		return false, "excede_maximo"
	end
	estado.valor += cantidad
	return true, nil
end

return Contador
