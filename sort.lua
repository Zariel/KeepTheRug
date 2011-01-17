local parent, ns = ...

local addon = ns.ktr

local nullMeta = {
	__index = function()
		return 0
	end
}

local bagFamily = setmetatable({}, {
	__index = function(self, key)
		rawset(self, key, GetItemFamily(-key + 1))
		return rawget(self, key)
	end
})

-- Sorting
local itemTypeWeight = setmetatable({
	["Miscellaneous"] = 0,
	["Consumable"] = 2,
	["Container"] = 3,
	["Reagent"] = 4,
	["Recipe"] = 5,
	["Gem"] = 6,
	["Quest"] = 7,
	["Trade Goods"] = 8,
	["Armor"] =  9,
	["Weapon"] = 10,
}, nullMeta)

local itemSubWeight = setmetatable({
	["Armor"] = {
		["Miscellaneous"] = 0,
		["Sigils"] = 1,
		["Totems"] = 2,
		["Idols"] = 3,
		["Librams"] = 4,
		["Shields"] = 5,
		["Cloth"] = 6,
		["Leather"] = 7,
		["Mail"] = 8,
		["Plate"] = 9,
	},
	["Weapon"] = {
		["Miscellaneous"] = 0,
		["Fishing Poles"] = 1,
		["Daggers"] = 2,
		["One-Handed Axes"] = 3,
		["One-Handed Maces"] = 4,
		["One-Handed Swords"] = 5,
		["Fist Weapons"] = 5.5,
		["Guns"] = 6,
		["Crossbows"] = 7,
		["Bows"] = 8,
		["Thrown"] = 9,
		["Wands"] = 10,
		["Staves"] = 11,
		["Polearms"] = 12,
		["Two-Handed Axes"] = 13,
		["Two-Handed Maces"] = 14,
		["Two-Handed Swords"] = 15,
	},
	["Trade Goods"] = {
		["Armor Enchantment"] = 1,
		["Cloth"] = 14,
		["Devices"] = 2,
		["Elemental"] = 13,
		["Enchanting"] = 11,
		["Explosives"] = 3,
		["Herb"] = 12,
		["Jewelcrafting"] = 10,
		["Leather"] = 9,
		["Materials"] = 8,
		["Meat"] = 4,
		["Metal & Stone"] = 5,
		["Other"] = 0,
		["Parts"] = 6,
		["Trade Goods"] = 0,
		["Weapon Enchantment"] = 7,
	},
	["Consumable"] = {
		["Food & Drink"] = 3,
		["Potion"] = 4,
		["Elixir"] = 5,
		["Flask"] = 6,
		["Bandage"] = 7,
		["Item Enhancement"] = 2,
		["Scroll"] = 1,
		["Other"] = 0,
		["Consumable"] = 0.5,
	}
}, { __index = function()
	return setmetatable({}, nullMeta)
end
})

for k,v in pairs(itemTypeWeight) do
	if(not itemSubWeight[k]) then
		itemSubWeight[k] = setmetatable({}, nullMeta)
	end
end

for k, v in pairs(itemSubWeight) do
	setmetatable(itemSubWeight[k], nullMeta)
end

local linkSort = function(a, b)
	if(a.link == b.link) then
		return false
	else
		return a.link > b.link
	end
end

local stackSort = function(a, b)
	if(a.count == b.count) then
		return linkSort(a, b)
	else
		return a.count > b.count
	end
end

local nameSort = function(a, b)
	if(a.name == b.name) then
		return stackSort(a, b)
	else
		return a.name > b.name
	end
end

local iconSort = function(a, b)
	if(a.icon == b.icon) then
		return nameSort(a, b)
	else
		return a.icon > b.icon
	end
end

local iLevelSort = function(a, b)
	if(a.iLevel == b.iLevel) then
		return iconSort(a, b)
	else
		return a.iLevel > b.iLevel
	end
end

local itemSubTypeSort = function(a, b)
	if(a.subType == b.subType) then
		return iLevelSort(a, b)
	else
		return itemSubWeight[a.itemType][a.subType] > itemSubWeight[b.itemType][b.subType]
	end
end

local itemTypeSort = function(a, b)
	if(a.itemType == b.itemType) then
		return itemSubTypeSort(a, b)
	else
		return itemTypeWeight[a.itemType] > itemTypeWeight[b.itemType]
	end
end

local raritySort = function(a, b)
	if(a.rarity == b.rarity) then
		return itemTypeSort(a, b)
	else
		return a.rarity > b.rarity
	end
end

addon.__lt = function(a, b)
	if(a.link and b.link) then
		return raritySort(a, b)
	elseif(a.link) then
		return true
	else
		return false
	end
end
