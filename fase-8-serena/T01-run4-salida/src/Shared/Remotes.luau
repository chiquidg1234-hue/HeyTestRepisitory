--!strict

--[[
	Remotes

	Nombres compartidos entre servidor y cliente para el Folder de remotos y
	sus RemoteFunction/RemoteEvent, para no duplicar strings sueltos.
]]

export type RemoteFunctionName = "GetInventorySnapshot" | "UseItem"
export type RemoteEventName = "InventoryChanged"

export type RemotesConfig = {
	FOLDER_NAME: string,
	FUNCTIONS: {
		GET_INVENTORY_SNAPSHOT: RemoteFunctionName,
		USE_ITEM: RemoteFunctionName,
	},
	EVENTS: {
		INVENTORY_CHANGED: RemoteEventName,
	},
}

local Remotes: RemotesConfig = {
	FOLDER_NAME = "InventoryRemotes",
	FUNCTIONS = {
		GET_INVENTORY_SNAPSHOT = "GetInventorySnapshot",
		USE_ITEM = "UseItem",
	},
	EVENTS = {
		INVENTORY_CHANGED = "InventoryChanged",
	},
}

return Remotes
