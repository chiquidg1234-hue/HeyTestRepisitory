--!strict

--[[
	ItemDatabase

	Catálogo de items del juego. Es un módulo puro (no toca servicios de
	Roblox); solo depende de los tipos de InventoryCore.
]]

local InventoryCore = require(script.Parent.InventoryCore)

export type ItemDefinition = InventoryCore.ItemDefinition
export type ItemDatabase = InventoryCore.ItemDatabase

local ItemDatabase: ItemDatabase = {
	Wood = { id = "Wood", displayName = "Madera", maxStack = 99 },
	GoldCoin = { id = "GoldCoin", displayName = "Moneda de oro", maxStack = 999 },
	HealthPotion = { id = "HealthPotion", displayName = "Poción de vida", maxStack = 20 },
	Sword = { id = "Sword", displayName = "Espada de hierro", maxStack = 1 },
}

return ItemDatabase
