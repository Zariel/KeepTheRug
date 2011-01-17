local parent, ns = ...
local addon = ns.addon

local slot_meta = {
	__lt = addon.__lt,
	__eq = function(a, b)
		if(a.item and b.item) then
			return a.item.link == b.item.link
		end

		return false
	end,
	__tostring = function(self) return tostring(self.item and self.item.link) end,
}

local new_item = function(bag, slot)
	local link = GetContainerItemLink(bag, slot)

	if(link) then
		local icon, count = GetContainerItemInfo(bag, slot)
		local name, _, rarity, iLevel, minLevel, itemType, subType, maxCount = GetItemInfo(link)

		t.link = link
		t.name = name
		t.iLevel = iLevel
		t.minLevel = minLevel
		t.itemType = itemType
		t.subType = subType
		t.maxCount = maxCount
		t.count = count
		t.rarity = rarity
		t.full = count == maxCount
		t.family = GetItemFamily(link)
		t.icon = icon
	end

	return t
end

local new_slot = function(bag, slot)
	local t = setmetatable({}, slot_meta)
	t.item = new_item(bag, slot)
	t.bag = bag
	t.slot = slot

	return t
end

