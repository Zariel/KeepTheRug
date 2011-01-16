--[[
	Implament a sort, just like MrPlow.

	Sort a table of bags.
	Mantain 2 tables, current position, target positions.
]]

local addon = CreateFrame("Frame")
addon.runningTime = 0

-- Some table funcs
local newT, delT, copyT, reverseT
do
	delT = function(t)
		for k, v in pairs(t) do
			if(type(v) == "table") then
				delT(v)
			end

			t[k] = nil
		end

		return
	end

	copyT = function(s, d)
		delT(d)

		local meta = getmetatable(s)
		setmetatable(d, meta)

		for k, v in pairs(s) do
			if(type(v) == "table") then
				local t = {}
				copyT(v, t)
				d[k] = t
			else
				d[k] = v
			end
		end

		return d
	end

	printT = function(t)
		for k, v in pairs(t) do
			print(k, v)
			if(type(v) == "table") then
				printT(v)
			end
		end
	end

	reverseT = function(t)
		local len = #t
		for i = 1, len / 2 do
			addon:Swap(t, i, len - i + 1)
		end
	end
end

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

local stackSort = function(a, b)
	if(a.count == b.count) then
		return false
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

local itemMeta = {
	__lt = function(a, b)
		if(a.link and b.link) then
			return raritySort(a, b)
		elseif(a.link) then
			return true
		else
			return false
		end
	end,
	__eq = function(a, b)
		return a.name == b.name and a.count == b.count
	end,
	__tostring = function(self) return tostring(self.link) end,
}

-- TODO: Add item info caching
local newItem = function(bag, slot)
	local t = setmetatable({}, itemMeta)
	local link = GetContainerItemLink(bag, slot)

	t.bag = bag
	t.slot = slot
	t.empty = not link

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

function addon:Print(...)
	return print("|cffKtR: ")
end

function addon:Swap(bags, from, to)
	local tmp = copyT(bags[from], {})
	copyT(bags[to], bags[from])
	copyT(tmp, bags[to])
end

function addon:ItemInBag(item, bag)
	return bit.band(item.family, bagFamily[bag])
end

function addon:GetBags(bank)
	local bags = {}

	local i = 1
	local min = (bank and NUM_BAG_SLOTS + 1) or 0
	local max = (bank and NUM_BAG_SLOTS + NUM_BANKBAGSLOTS + 1) or NUM_BAG_SLOTS

	if(bank) then
		for slot = 1, GetContainerNumSlots(-1) do
			local item = newItem(-1, slot)
			item.id = i
			bags[i] = item

			i = i + 1
		end
	end

	for bag = min, max do
		for slot = 1, GetContainerNumSlots(bag) do
			local item = newItem(bag, slot)
			item.id = i
			bags[i] = item

			i = i + 1
		end
	end

	bags.bank = bank

	return bags
end

function addon:FirstEmpty(bags)
	for i = 1, #bags do
		if(bags[i].empty) then
			return i
		end
	end
end

function addon:DefragMap(bags)
	if(not self:FirstEmpty(bags)) then
		return bags
	end

	local dest = copyT(bags, {})

	local slot
	local i = #bags

	while(i > 1) do
		for j = i, 1, -1 do
			slot = dest[j]
			i = j
			if(not slot.empty) then
				break
			end
		end

		local empty = self:FirstEmpty(dest)
		if(empty and i > empty) then
			self:Swap(dest, i, empty)
		else
			break
		end

		i = i - 1
	end

	return dest
end

function addon:StackMap(bags)
	local dest = copyT(bags, {})

	local i = #dest
	local slot
	while(i > 0) do
		for j = i, 1, -1 do
			slot = dest[j]
			i = j
			if(not (slot.empty or slot.count < slot.maxCount)) then
				break
			end
		end

		-- Find another stack to dump onto.
		local n
		for j = 1, i do
			if(slot.name == dest[j].name and dest[j].count < dest[j].maxCount) then
				n = j
				break
			end
		end

		if(n) then
			local ammount = dest[j].maxCount - dest[j].count
			self:Swap(dest, i, n)
			dest[i].ammount = ammount
		end
	end
end

function addon:QSort(t, min, max)
	local pivot
	local left, right = min, max

	if(max > min) then
		pivot = math.floor((min + max) / 2)
		while(left <= pivot and right >= pivot) do
			while(t[left] < t[pivot] and left <= pivot) do
				left = left + 1
			end

			while(t[right] > t[pivot] and right >= pivot) do
				right = right - 1
			end

			self:Swap(t, left, right)

			left = left + 1
			right = right - 1

			if(left - 1 == pivot) then
				right = right + 1
				pivot = right
			elseif(right + 1 == pivot) then
				left = left - 1
				pivot = left
			end
		end

		self:QSort(t, min, pivot - 1)
		self:QSort(t, pivot + 1, max)
	end
end

-- TODO: Optimize this
function addon:SortMap(bags, reverse, junkEnd)
	local dest = copyT(bags, {})

	local slot, prev

	if(#dest > 1) then
		self:QSort(dest, 1, #dest)

		-- Dirty hack :E
		if(reverse) then
			reverseT(dest)
		end

		if(junkEnd) then
			for i = #dest, 1 do
				if(dest[i].rarity ~= 1) then
					local last = self:LastEmpty(dest)
					if(last) then
						self:Swap(dest, i, last)
					else
						break
					end
				else
					break
				end
			end
		end
	end

	return dest
end

-- For a given map of what the bag should look like, createa a path that will move the items so that it
-- matches the given map.

function addon:ParseMap(dest)
	local current = self:GetBags(dest.bank)

	local slot
	local path = {}

	for i = 1, #dest do
		slot = dest[i]
		-- Are we in the correct place ?
		--if(i ~= slot.id) then
		if(slot.link ~= current[i].link) then
			-- Find where slot is in the current layout
			-- slot.id == j the first time when an item isnt moved
			-- but when an item is moved the self:Swap() only operates on current.
			local n
			-- TODO: Optimize this
			for j = #current,1,-1 do
				-- Need to check here that the links are the same
				if(current[j].link == slot.link) then
					n = j
					break
				end
			end

			--print(i, slot, n, dest[n], current[i], current[n], slot == dest[n])
			if(n and i ~= n and (slot ~= dest[n])) then
				-- From To
				path[#path + 1] = { slot, current[n] }
				self:Swap(current, i, n)
			end
		end
	end

	return path
end

local timer = 0
function addon:OnUpdate(elapsed)
	timer = timer + elapsed

	-- Move check throttle
	if(timer > 0) then
		if(self.driving and coroutine.status(self.driving) == "suspended") then
			self.runningTime = self.runningTime + timer
			local err, ret = coroutine.resume(self.driving, self, self.driverArgs)
			if(ret) then
				self.driving = nil
				self.driverArg = nil
			end
		end

		timer = 0
	end

end

addon:Hide()
addon:SetScript("OnUpdate", addon.OnUpdate)

function addon:MoveItems(fromBag, fromSlot, toBag, toSlot)
	local _, locked1, locked2
	while(true) do
		_, _, locked1 = GetContainerItemInfo(fromBag, fromSlot)
		_, _, locked2 = GetContainerItemInfo(toBag, toSlot)

		if(locked1 or locked2) then
			coroutine.yield(false)
		else
			break
		end
	end

	PickupContainerItem(fromBag, fromSlot)

	if(CursorHasItem()) then
		PickupContainerItem(toBag, toSlot)
	end

	return true
end

-- Time for some CRAZY couroutines!
function addon:Driver(path)
	self.runningTime = 0
	print("Starting ..")

	local from, to
	local err, ret

	local moving

	for i = 1, #path do
		from = path[i][1]
		to = path[i][2]

		moving = coroutine.create(self.MoveItems)
		local count = 0

		--print(i, from.bag, from.slot, to.bag, to.slot)
		while(true) do
			err, ret = coroutine.resume(moving, self, from.bag, from.slot, to.bag, to.slot)
			count = count + 1

			if(not ret) then
				if(count > 50) then
					print(string.format("Error moving (%d, %d) -> (%d, %d)", from.bag, from.slot, to.bag, to.slot))
					return true
				else
					coroutine.yield(false)
				end
			else
				break
			end
		end

		coroutine.yield(false)
	end

	print("Finished in: " .. self.runningTime .. "s")

	return true
end

function addon:Run(bags)
	if(self.driving and coroutine.status(self.driving) ~= "dead") then
		return
	end

	self.driving = coroutine.create(addon.Driver)
	self.driverArgs = bags

	self:Show()
end

local _G = getfenv(0)

function _G.SlashCmdList.WALRUS(msg)
	local bank = string.match(msg, "(%S)") and true
	--local defrag = addon:DefragMap(addon:GetBags(bank))
	local sort = addon:SortMap(addon:GetBags(bank))
	local path = addon:ParseMap(sort)

	print(#path)

	addon:Show()
	addon:Run(path)
end

_G.SLASH_WALRUS1 = "/walrus"
