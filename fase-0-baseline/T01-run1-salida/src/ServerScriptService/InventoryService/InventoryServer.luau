--!strict
--[[
	InventoryServer.luau

	Logica de servidor: usa el nucleo puro InventoryCore para las reglas de
	inventario y ProfileStore (DataStoreService + bloqueo de sesion) para
	persistirlo. Mantiene un cache en memoria por jugador mientras esta
	conectado.

	IMPORTANTE (autoridad del servidor): ninguna funcion publica de este
	modulo acepta cantidades ni identidades de item "en bruto" para mutar el
	inventario de un jugador sin validar contra ItemCatalog. RequestUseItem,
	que es la unica entrada pensada para ser invocada a partir de un
	remote, fija la cantidad consumida en el propio servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryCore = require(Shared:WaitForChild("InventoryCore"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))

local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))

type InventoryState = InventoryCore.InventoryState
type ItemDefinitions = InventoryCore.ItemDefinitions

export type LoadOutcome = {
	ok: boolean,
	errorMessage: string?,
}

export type ActionOutcome = {
	ok: boolean,
	errorMessage: string?,
}

local DEFAULT_CAPACITY = 20
local DATASTORE_NAME = "PlayerInventory_v1"

-- Items que el jugador puede "usar" desde el cliente. La cantidad
-- consumida SIEMPRE la decide el servidor (ver RequestUseItem); el
-- cliente solo puede indicar la identidad del item.
local USABLE_ITEMS: { [string]: boolean } = {
	Potion = true,
}

local InventoryServer = {}
InventoryServer.__index = InventoryServer

export type InventoryServerInstance = typeof(setmetatable(
	{} :: {
		_profileStore: ProfileStore.ProfileStoreInstance,
		_itemDefs: ItemDefinitions,
		_cache: { [number]: InventoryState },
	},
	InventoryServer
))

function InventoryServer.new(): InventoryServerInstance
	local self = setmetatable({}, InventoryServer) :: InventoryServerInstance
	self._profileStore = ProfileStore.new(DATASTORE_NAME)
	self._itemDefs = ItemCatalog
	self._cache = {}
	return self
end

local function keyForUser(userId: number): string
	return "Player_" .. tostring(userId)
end

-- Carga (o crea) el inventario de un jugador bajo candado de sesion y lo
-- deja en cache.
function InventoryServer:LoadForUser(userId: number): LoadOutcome
	local defaultInventory = InventoryCore.new(DEFAULT_CAPACITY)
	local defaultPayload = InventoryCore.serialize(defaultInventory)

	local result = self._profileStore:Load(keyForUser(userId), defaultPayload)
	if not result.ok or result.payload == nil then
		return { ok = false, errorMessage = result.errorMessage }
	end

	local state, err = InventoryCore.deserialize(result.payload)
	if state == nil then
		return { ok = false, errorMessage = err }
	end

	self._cache[userId] = state
	return { ok = true, errorMessage = nil }
end

-- Copia inmutable del estado actual en cache (segura de exponer).
function InventoryServer:GetSnapshot(userId: number): InventoryState?
	local state = self._cache[userId]
	if state == nil then
		return nil
	end
	return InventoryCore.clone(state)
end

function InventoryServer:GetSerializedSnapshot(userId: number): string?
	local state = self._cache[userId]
	if state == nil then
		return nil
	end
	return InventoryCore.serialize(state)
end

-- Guarda el estado actual en cache hacia el DataStore, renovando el
-- candado de sesion.
function InventoryServer:SaveForUser(userId: number): ActionOutcome
	local state = self._cache[userId]
	if state == nil then
		return { ok = false, errorMessage = "no_cached_state" }
	end

	local payload = InventoryCore.serialize(state)
	local result = self._profileStore:Save(keyForUser(userId), payload)
	return { ok = result.ok, errorMessage = result.errorMessage }
end

-- Guarda y libera el candado. Llamar al desconectar al jugador y en
-- BindToClose.
function InventoryServer:ReleaseForUser(userId: number)
	self:SaveForUser(userId)
	self._profileStore:ReleaseLock(keyForUser(userId))
	self._cache[userId] = nil
end

-- Concede un item a un jugador. La cantidad la decide siempre codigo de
-- SERVIDOR (recompensas, tienda ya validada, quests, etc.). Esta funcion
-- NO debe conectarse directamente a un remote sin validacion adicional.
function InventoryServer:GrantItem(userId: number, itemId: string, quantity: number): ActionOutcome
	local state = self._cache[userId]
	if state == nil then
		return { ok = false, errorMessage = "no_cached_state" }
	end

	local result = InventoryCore.addItem(state, self._itemDefs, itemId, quantity)
	return { ok = result.ok, errorMessage = result.errorMessage }
end

-- Maneja una peticion de "usar item" iniciada por el cliente. El cliente
-- SOLO aporta la identidad del item (itemId): el servidor decide de forma
-- independiente si ese item existe, si es realmente usable, si el
-- jugador lo posee, y cuanta cantidad se consume (siempre 1, fijado aqui,
-- jamas por el cliente).
function InventoryServer:RequestUseItem(userId: number, itemId: string): ActionOutcome
	if typeof(itemId) ~= "string" then
		return { ok = false, errorMessage = "invalid_item_id" }
	end

	if not USABLE_ITEMS[itemId] then
		return { ok = false, errorMessage = "item_not_usable" }
	end

	local state = self._cache[userId]
	if state == nil then
		return { ok = false, errorMessage = "no_cached_state" }
	end

	local CONSUME_QUANTITY = 1 -- fijado por el servidor, no por el cliente
	local result = InventoryCore.removeItem(state, itemId, CONSUME_QUANTITY)
	if not result.ok then
		return { ok = false, errorMessage = result.errorMessage }
	end

	return { ok = true, errorMessage = nil }
end

return InventoryServer
