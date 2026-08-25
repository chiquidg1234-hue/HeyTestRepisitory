--!strict
--[[
	ItemCatalog.luau

	Catalogo de definiciones de item. Es un modulo de datos PURO (sin
	dependencias de Roblox ni de otros modulos), para poder usarse tanto
	dentro de Roblox (servidor y cliente) como en los tests fuera de Roblox.

	La forma de cada entrada coincide con InventoryCore.ItemDefinition.
]]

export type ItemId = string

export type ItemDefinition = {
	id: ItemId,
	displayName: string,
	maxStack: number,
}

export type ItemDefinitions = { [ItemId]: ItemDefinition }

local ItemCatalog: ItemDefinitions = {
	Sword = { id = "Sword", displayName = "Espada de hierro", maxStack = 1 },
	Shield = { id = "Shield", displayName = "Escudo de madera", maxStack = 1 },
	Potion = { id = "Potion", displayName = "Pocion de vida", maxStack = 10 },
	Coin = { id = "Coin", displayName = "Moneda de oro", maxStack = 999 },
}

return ItemCatalog
