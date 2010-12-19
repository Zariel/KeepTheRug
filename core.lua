--[[
	Implament a sort, just like MrPlow.

	Sort a table of bags.
	Mantain 2 tables, current position, target positions.
]]

-- Some table funcs
local newT, delT, copyT
do
	local cache = {}
	newT = function()
		local t = next(cache)
		if(t) then
			cache[t] = nil
			return t
		else
			return {}
		end
	end

	delT = function(t, nocache)
		for k, v in pairs(t) do
			if(type(v) == "table") then
				delT(v)
			end

			t[k] = nil
		end

		if(not nocache) then
			cache[t] = true
		end

		return
	end

	copyT = function(s, d)
		delT(d, true)

		for k, v in pairs(s) do
			if(type(v) == "table") then
				local t = newT()
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
end

local newItem = function(bag, slot)
	local t = newT()
	local _, count, _, rarity = GetContainerItemInfo(bag, slot)
	local link = GetContainerItemLink(bag, slot)

	t.bag = bag
	t.slot = slot
	t.count = count
	t.link = link
	t.rarity = rarity
	t.empty = not link

	return t
end

local swap = function(bags, from, to)
	local tmp = copyT(bags[from], newT())
	copyT(bags[to], bags[from])
	copyT(tmp, bags[to])

	bags[from].dirty = true
	bags[to].dirty = true
end

local getBags = function()
	local bags = newT()

	local i = 1
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local item = newItem(bag, slot)
			bags[i] = item

			i = i + 1
		end
	end

	return bags
end

local firstEmpty = function(bags)
	for i = 1, #bags do
		if(bags[i].empty) then
			return i
		end
	end
end

local defragMap = function(bags)
	if(not firstEmpty(bags)) then
		return bags
	end

	local dest = copyT(bags, newT())

	local slot
	local i = #bags

	while(i > 1) do
		for j = i, 1, -1 do
			slot = dest[j]
			if(not slot.empty) then
				break
			end
			i = j
		end

		local empty = firstEmpty(dest)
		if(empty and i > empty) then
			swap(dest, i, empty)
		else
			break
		end

		i = i - 1
	end

	return dest
end

_G.walrus = function()
	--[[
	local bags = getBags()

	for k, v in pairs(bags[1]) do
		print(bags[1][k], bags[2][k])
	end

	swap(bags, 1, 2)

	for k, v in pairs(bags[1]) do
		print(bags[1][k], bags[2][k])
	end
	]]

	return defragMap(getBags())
end

