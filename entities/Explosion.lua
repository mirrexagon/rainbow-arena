--- Require ---
local Class = require("lib.hump.class")
local vector = require("lib.hump.vector")

local util = require("lib.util")

local circle = require("util.circle")
--- ==== ---


--- Class definition ---
local ent_Explosion = {}
--- ==== ---


--- Local functions ---
--- ==== ---


--- Class functions ---
function ent_Explosion:init(arg)
	assert(util.table.check(arg, {
		"position",
		"radius",
		"duration"
	}, "Explosion init"))

	self.Color = arg.color or {255, 97, 0}

	self.Position = arg.position:clone()
	self.Lifetime = arg.duration

	self.Blast = {
		radius = arg.radius,
		duration = arg.duration,
		func = function(e, impact, dir_vec)
			-- Pulse entity.
			if e.pulse then e:pulse(impact) end

			-- Apply explosion force.
			if e.Mass and e.Velocity and not e.IgnoreExplosion then
				e.Velocity = e.Velocity + impact * ((arg.force or 10^6) / e.Mass) * dir_vec
			end

			-- Apply health damage.
			if e.Health and arg.damage then
				e.Health.current = e.Health.current - math.ceil(impact * arg.damage)
			end
		end
	}
end
--- ==== ---


return Class(ent_Explosion)