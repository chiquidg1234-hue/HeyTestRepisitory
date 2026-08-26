--!strict
--[[
	ItemDatabase
	============

	Catálogo de items del juego. Es la única fuente de verdad sobre qué
	items existen, cuánto apilan y qué pasa al "usarlos". No importa
	ningún servicio de Roblox: es pura, igual que InventoryCore.

	El servidor usa esta tabla para validar TODO lo que llega del cliente:
	el cliente nunca puede inventar un itemId ni decidir cuánto se
	consume al usar un item, eso siempre sale de aquí.
]]

local InventoryCore = require(script.Parent.InventoryCore)

export type ItemDefinition = {
	id: InventoryCore.ItemId,
	maxStack: number,
	displayName: string,
	usable: boolean,
	-- Cantidad que se consume al usar el item (solo si usable == true).
	consumeOnUse: number?,
}

local ItemDatabase = {}

ItemDatabase.Definitions = ({
	Sword = {
		id = "Sword",
		maxStack = 1,
		displayName = "Espada",
		usable = false,
		consumeOnUse = nil,
	},
	HealthPotion = {
		id = "HealthPotion",
		maxStack = 20,
		displayName = "Poción de vida",
		usable = true,
		consumeOnUse = 1,
	},
	GoldCoin = {
		id = "GoldCoin",
		maxStack = 999,
		displayName = "Moneda de oro",
		usable = false,
		consumeOnUse = nil,
	},
} :: { [InventoryCore.ItemId]: ItemDefinition })

--[[
	Devuelve la definición de un item, o `nil` si el id no existe en el
	catálogo. Punto único de validación de identidad de item.
]]
function ItemDatabase.get(itemId: InventoryCore.ItemId): ItemDefinition?
	return ItemDatabase.Definitions[itemId]
end

--[[
	Proyecta el catálogo completo al tipo mínimo que espera InventoryCore
	(solo `id` y `maxStack`), para usarlo como tabla de validación en
	`InventoryCore.deserialize`. Se necesita porque `ItemDefinition` aquí
	tiene más campos que `InventoryCore.ItemDefinition` y el chequeo de
	tipos de las tablas-diccionario no acepta campos extra por variancia.
]]
function ItemDatabase.toCoreDefinitions(): InventoryCore.ItemDefinitions
	local coreDefinitions: InventoryCore.ItemDefinitions = {}
	for itemId, itemDef in ItemDatabase.Definitions do
		coreDefinitions[itemId] = { id = itemDef.id, maxStack = itemDef.maxStack }
	end
	return coreDefinitions
end

return ItemDatabase
