--[[
	Implament a sort, just like MrPlow.

	Sort a table of bags.
	Mantain 2 tables, current position, target positions.
]]

local parent, ns = ...

local addon = ns.ktr
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


-- TODO: Add item info caching

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
			local item = self:NewSlot(-1, slot)
			item.id = i
			bags[i] = item

			i = i + 1
		end
	end

	for bag = min, max do
		for slot = 1, GetContainerNumSlots(bag) do
			local item = self:NewSlot(bag, slot)
			bags[i] = item

			i = i + 1
		end
	end

	bags.bank = bank

	return bags
end

function addon:FirstEmpty(bags)
	for i = 1, #bags do
		if(not bags[i].item) then
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

function addon:LastEmpty(dest)
	for i = #dest, 1, -1 do
		if(not dest[i].link) then
			return i
		end
	end
end

-- TODO: Optimize this
function addon:SortMap(bags, reverse, junkEnd)
	local dest = copyT(bags, {})

	local slot, prev

	if(#dest > 1) then
		self:QSort(dest, 1, #dest)

		if(junkEnd) then
			for i = #dest, 1, -1 do
				if(dest[i].rarity == 0) then
					local last = self:LastEmpty(dest)
					if(last) then
						self:Swap(dest, i, last)
					else
						break
					end
				end
			end
		end

		-- Dirty hack :E
		if(reverse) then
			reverseT(dest)
		end
	end

	return dest
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
