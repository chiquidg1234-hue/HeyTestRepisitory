--!strict

--[[
	ItemCatalog
	===========
	Catálogo estático y autoritativo de items. Es la única fuente de
	verdad sobre qué itemIds existen y cuánto se puede apilar cada uno.
	Tanto el servidor (para validar) como el cliente (para mostrar
	nombres) lo requieren; solo el servidor lo usa para decidir.
]]

local InventoryCore = require(script.Parent:WaitForChild("InventoryCore"))

type ItemCatalog = InventoryCore.ItemCatalog

local ItemCatalog: ItemCatalog = {
	sword = { id = "sword", displayName = "Espada", maxStack = 1 },
	potion = { id = "potion", displayName = "Poción", maxStack = 20 },
	coin = { id = "coin", displayName = "Moneda", maxStack = 999 },
}

return ItemCatalog
