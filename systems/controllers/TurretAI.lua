local vector = require("lib.hump.vector")
local util = require("lib.self.util")

local circle = require("util.circle")

---

local circle_aabb = circle.aabb

local math_atan2 = math.atan2

---

return {
	systems = {
		{
			name = "DumbTurretController",
			requires = {"Position", "TargetSearchRadius", "DumbTurretAI"},
			update = function(entity, world, dt)
				-- Find closest target.
				local target
				local mindist = math.huge
				for other in pairs(world.hash:get_objects_in_range(
					circle_aabb(entity.TargetSearchRadius, entity.Position.x, entity.Position.y)))
				do
					if other ~= entity and other.Team ~= entity.Team then
						local dist = (other.Position - entity.Position):len()
						if dist < mindist then
							target = other
							mindist = dist
						end
					end
				end

				if target then
					-- Point at target.
					local tx, ty = target.Position.x, target.Position.y
					local ex, ey = entity.Position.x, entity.Position.y
					entity.RotationTarget = math_atan2(ty - ey, tx - ex)

					entity.Firing = true
				else
					entity.Firing = false
				end
			end
		},
	},

	events = {

	}
}
