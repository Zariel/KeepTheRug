--[[
	Implament a sort, just like MrPlow.

	Sort a table of bags.
	Mantain 2 tables, current position, target positions.
]]

-- Some table funcs
local newT, delT, copyT
do
	local cache = {}
	newT = function(...)
		local t = next(cache) or {}

		for i = 1, select("#", ...) do
			t[#t + 1] = select(i, ...)
		end

		cache[t] = nil

		return t
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

local itemMeta = {
	__lt = function(a, b)
		return a.rarity < b.rarity
	end,
	__le = function(a, b)
		return a.rarity <= b.rarity
	end
}

-- TODO: Add item info caching
local newItem = function(bag, slot)
	local t = setmetatable(newT(), itemMeta)
	local _, count, _, rarity = GetContainerItemInfo(bag, slot)
	local link = GetContainerItemLink(bag, slot)

	t.bag = bag
	t.slot = slot
	t.link = link
	t.empty = not link

	if(link) then
		local name, _, _, iLevel, minLevel, itemType, subType, maxCount = GetItemInfo(link)
		t.name = name
		t.iLevel = iLevel
		t.minLevel = minLevel
		t.itemType = itemType
		t.subType = subType
		t.maxCount = maxCount
		t.count = count
		t.rarity = rarity
		t.full = count == maxCount
	end

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
	local revBags = newT()

	local i = 1
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local item = newItem(bag, slot)
			item.currentPos = i
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
			i = j
			if(not slot.empty) then
				break
			end
		end

		local empty = firstEmpty(dest)
		if(empty and i > empty) then
			swap(dest, i, empty)
			-- Update the new slot position so we can find it again
			dest[empty].currentPos = i
		else
			break
		end

		i = i - 1
	end

	return dest
end

local stackMap = function(bags)
	local dest = copyT(bags, newT())
end

local qsort
qsort = function(t, min, max)
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

			swap(t, left, right)

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

		qsort(t, min, pivot - 1)
		qsort(t, pivot + 1, max)
	end
end

local sortMap = function(bags)
	local dest = newT()

	local slot, prev

	for i = 1, #bags do
		if(not bags[i].empty) then
			dest[#dest + 1] = bags[i]
		end
	end

	qsort(dest, 1, #dest)

	for i = 1, #bags do
		if(bags[i].empty) then
			table.insert(dest, i, bags[i])
		end
	end

	return dest
end

-- For a given map of what the bag should look like, createa a path that will move the items so that it
-- matches the given map.

local parseMap = function(dest)
	local current, rev = getBags()

	--[[
	for i = 1, #dest do
		if(dest[i].dirty) then
			print(i, dest[i].link, dest[i].bag, dest[i].slot)
		end
	end
	]]

	local i = #dest
	local slot

	local path = newT()

	while(i > 0) do
		if(not (slot and slot.dirty)) then
			for j = i, 1, -1 do
				slot = dest[j]
				i = j

				if(slot.dirty and not slot.empty) then
					break
				end
			end
		end

		-- Logic is broken or might not be
		-- print(i, slot.currentPos)
		local source = current[i]
		if(i ~= slot.currentPos) then
			-- From To
			path[#path + 1] = { slot, source }
		end

		i = i - 1
		slot = dest[i]
	end

	return path
end

local driving, driverArg

local timer = 0
local OnUpdate = function(self, elapsed)
	timer = timer + elapsed

	-- Move check throttle
	if(timer > 1) then
		if(driving and coroutine.status(driving) == "suspended") then
			coroutine.resume(driving, driverArgs)
		end
		timer = 0
	end

end

local f = CreateFrame("frame")
f:Hide()
f:SetScript("OnUpdate", OnUpdate)

local moveItems = function(fromBag, fromSlot, toBag, toSlot)
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
local driver = function(path)
	local from, to
	local err, ret

	local moving

	for i = 1, #path do
		from = path[i][1]
		to = path[i][2]

		moving = coroutine.create(moveItems)
		err, ret = coroutine.resume(moving, from.bag, from.slot, to.bag, to.slot)
		print(i, err, ret, from.bag, from.slot, to.bag, to.slot)
		if(not ret) then
			-- moving failed, locked
			--[[
			f:Show()
			coroutine.yield(false)
			f:Hide()
			]]

			-- debug this
			if(not (moving or coroutine.status(moving) == "suspended")) then
				return true
			end

			while(true) do
				err, ret = coroutine.resume(moving, from.bag, from.slot, to.bag, to.slot)

				if(not ret) then
					f:Show()
					coroutine.yield(false)
				else
					break
				end
			end

			f:Hide()
		end
	end

	return true
end

local run = function(bags)
	if(driving and coroutine.status(driving) ~= "dead") then
		return
	end

	driving = coroutine.create(driver)
	driverArgs = bags

	coroutine.resume(driving, driverArgs)

end

_G.walrus = function()
	--local map = parseMap(defragMap(getBags()))
	--local map = parseMap(defragMap(sortMap(getBags())))
	local defrag = defragMap(getBags())
	for i = 1, #defrag do
		print(defrag[i]
	run(map)
end

