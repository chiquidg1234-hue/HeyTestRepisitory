--!strict
--[[ Comprobación mínima EN EL MOTOR, para Open Cloud (FASE 7).
     Se ejecuta dentro de un place real, no en Lune. No toca gameplay:
     solo confirma que el place arranca y que los servicios esperados existen. ]]

local servicios = { "ReplicatedStorage", "ServerScriptService", "Players", "DataStoreService" }

for _, nombre in servicios do
	local ok = pcall(function()
		return game:GetService(nombre)
	end)
	assert(ok, "no se pudo obtener el servicio " .. nombre)
	print("servicio OK: " .. nombre)
end

return { ok = true, servicios = #servicios }
