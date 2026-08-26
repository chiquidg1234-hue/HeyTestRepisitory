--!strict

--[[
	ItemDatabase.luau

	Catálogo de items del juego: es la única fuente de verdad sobre qué
	items existen y cuánto se apilan (`maxStack`). Ni el cliente ni ningún
	remoto deciden esto: solo el servidor la lee para validar peticiones y
	para reconstruir inventarios guardados.
]]

local Inventory = require(script.Parent.Inventory)

type ItemDefinitions = Inventory.ItemDefinitions

local ItemDatabase: ItemDefinitions = {
	Wood = { id = "Wood", maxStack = 100 },
	Stone = { id = "Stone", maxStack = 100 },
	IronSword = { id = "IronSword", maxStack = 1 },
	HealthPotion = { id = "HealthPotion", maxStack = 20 },
}

return ItemDatabase
