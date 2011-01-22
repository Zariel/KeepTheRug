local parent, ns = ...
local addon = ns.ktr

local slot_meta = {
	__lt = function(a, b)
		if(a.item and b.item) then
			return a.item < b.item
		elseif(a.item) then
			return true
		else
			return false
		end
	end,
	__eq = function(a, b)
		return a.bag == b.bag and a.slot == b.slot
	end,
}

local new_item = function(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if(link) then
		local t = setmetatable({}, {
			__lt = addon.__lt,
			__tostring = function(self) return tostring(self.link) end
		})

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
		return t
	end
end

function addon:NewSlot(bag, slot)
	local t = setmetatable({}, slot_meta)
	t.item = new_item(bag, slot)
	t.bag = bag
	t.slot = slot

	return t
end

