local parent, ns = ...
local addon = ns.ktr

-- For a given map of what the bag should look like, create a path that will move the items so that it
-- matches the given map.

function addon:ParseMap(dest)
	local current = self:GetBags(dest.bank)

	local path = {}

	for i, slot in ipairs(dest) do
		local target = current[i]
		if(slot ~= target) then
			path[#path + 1] = { slot.bag, slot.slot, target.bag, target.slot }

			local id
			print(target.item)
			for j, s in pairs(dest) do
				if(s.item == target.item) then
					id = j
					break
				end
			end

			print(id)
			local bag, slot = slot.bag, slot.slot
			dest[id].bag = bag
			dest[id].slot = slot
			dest[id].id = id
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

	local err, ret

	local moving

	for i = 1, #path do
		moving = coroutine.create(self.MoveItems)
		local count = 0

		--print(i, from.bag, from.slot, to.bag, to.slot)
		while(true) do
			err, ret = coroutine.resume(moving, self, unpack(path[i]))
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

