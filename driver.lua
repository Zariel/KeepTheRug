local parent, ns = ...
local addon = ns.addon

-- For a given map of what the bag should look like, createa a path that will move the items so that it
-- matches the given map.

function addon:ParseMap(dest)
	local current = self:GetBags(dest.bank)

	local path = {}
	local dirty = {}

	local slot

	for i = 1, #dest do
		slot = dest[i]
		-- Are we in the correct place ?
		if(slot.link and slot ~= current[i]) then
			-- Find where slot is in the current layout
			-- slot.id == j the first time when an item isnt moved
			-- but when an item is moved the self:Swap() only operates on current.
			local n
			-- TODO: Optimize this
			for j = 1, #current do
				-- Need to check here that the links are the same
				if(current[j].link == slot.link) then
					n = j
					break
				end
			end

			print(string.format("%d->%d -- %s (%d:%d) -> (%d:%d), %s", i, n, slot.link, slot.bag, slot.slot, current[n].bag, current[n].slot, current[n].link))
			if(n and i ~= n) then
				path[#path + 1] = { current[n], slot }

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
				if(count > 60) then
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

	print("Finished in: " .. math.floor((self.runningTime * 100) / 100) .. "s")

	return true
end

