local vector = require("lib.hump.vector")
local util = require("lib.self.util")

local circle = require("util.circle")

---

local circle_colliding = circle.colliding
local circle_aabb = circle.aabb
local table_invert = util.table.invert
local table_has = util.table.has

---

local function ent_colliding(entity, other)
	return circle_colliding(entity.Position,entity.Radius, other.Position,other.Radius)
end

local function ent_aabb(entity)
	return circle_aabb(entity.Radius, entity.Position.x, entity.Position.y)
end

---

local function collision_eligible(ent1, ent2)
	if ent1 == ent2 then return false end

	if ent1.CollisionExcludeEntities then
		if table_invert(ent1.CollisionExcludeEntities)[ent2] then
			return false
		end
	end

	if ent2.CollisionExcludeEntities then
		if table_invert(ent2.CollisionExcludeEntities)[ent1] then
			return false
		end
	end

	---

	if ent1.CollisionExcludeComponents then
		if table_has(ent2, ent1.CollisionExcludeComponents) then
			return false
		end
	end

	if ent2.CollisionExcludeComponents then
		if table_has(ent1, ent2.CollisionExcludeComponents) then
			return false
		end
	end

	return true
end

local function physics_resolve_collision(world, ent1, ent2, mtv)
	if ent1.Mass == 0 then
		world:move_entity(ent1, ent1.Position + mtv)
	elseif ent2.Mass == 0 then
		world:move_entity(ent2, ent2.Position + mtv)
	else
		local masses = (ent1.Mass + ent2.Mass)
		world:move_entity(ent1, ent1.Position + (ent2.Mass/masses)*mtv)
		world:move_entity(ent2, ent2.Position - (ent1.Mass/masses)*mtv)
	end

	if ent2.Velocity then
		-- Dynamic vs. Dynamic
		local ent1_normal_velocity = ent1.Velocity:projectOn(mtv)
		local ent1_tangent_velocity = ent1.Velocity - ent1_normal_velocity

		local ent2_normal_velocity = ent2.Velocity:projectOn(mtv)
		local ent2_tangent_velocity = ent2.Velocity - ent2_normal_velocity

		local ent1_mass = ent1.Mass
		local ent2_mass = ent2.Mass

		-- We only care about normal velocity - the tangent velocities remain the same.
		-- Velocity equations: https://en.wikipedia.org/wiki/Elastic_collision
		local ent1_final_normal_velocity =
			(ent1_normal_velocity * (ent1_mass - ent2_mass) + 2 * ent2_mass * ent2_normal_velocity)
			/ (ent1_mass + ent2_mass)
		local ent2_final_normal_velocity =
			(ent2_normal_velocity * (ent2_mass - ent1_mass) + 2 * ent1_mass * ent1_normal_velocity)
			/ (ent2_mass + ent1_mass)

		ent1.Velocity = ent1_tangent_velocity + ent1_final_normal_velocity
		ent2.Velocity = ent2_tangent_velocity + ent2_final_normal_velocity
	else
		-- Dynamic vs. Static
		local normal_velocity = entity.Velocity:projectOn(mtv)
		local tangent_velocity = entity.Velocity - normal_velocity
		entity.Velocity = -normal_velocity + tangent_velocity
	end
end

--

local weak_mt = {__mode = "k"}
local col_pairs = setmetatable({},
	{
		__index = function(self, key)
			local t = setmetatable({}, weak_mt)
			rawset(self, key, t)
			return t
		end,

		__mode = "k"
	}
)

local function add_pair(ent1, ent2)
	col_pairs[ent1][ent2] = true
	col_pairs[ent2][ent1] = true
end

local function remove_pair(ent1, ent2)
	col_pairs[ent1][ent2] = nil
	col_pairs[ent2][ent1] = nil
end

local function check_pair(ent1, ent2)
	return col_pairs[ent1] and col_pairs[ent1][ent2] --and col_pairs[ent2] and col_pairs[ent2][ent1]
end

local function get_pairs(ent)
	return col_pairs[ent]
end

---

return {
	systems = {
		{
			name = "CalculateAcceleration",
			requires = {"InputAcceleration"},
			priority = 2,
			update = function(entity)
				entity.Acceleration = (entity.InputAcceleration or vector.zero)
			end
		},

		-- https://stackoverflow.com/questions/667034/simple-physics-based-movement
		-- v_max = acc/drag, time_to_v_max = 5/drag
		{
			name = "Motion",
			requires = {"Position", "Velocity"},
			priority = 1,
			update = function(entity, world, dt)
				world:move_entity(entity, entity.Position + entity.Velocity*dt)

				entity.Velocity = entity.Velocity + ((entity.Acceleration or vector.zero) - (entity.Drag or 0) * entity.Velocity)*dt
			end
		},

		{
			name = "Collision",
			requires = {"Position", "Velocity", "Radius"},
			update = function(entity, world, dt)
				-- TODO: Optimise by not checking already tested ones?
				-- Last time this made the second check skip some entities all the time or something.

				for other in pairs(get_pairs(entity)) do
					if not ent_colliding(entity, other) then
						remove_pair(entity, other)
						world:emit_event("_EntityCollisionStop", entity, other)
					end
				end

				for other in pairs(world.hash:get_objects_in_range(ent_aabb(entity))) do
					if other ~= entity then
						---
						local col, mtv = ent_colliding(entity, other)
						if col then
							if not check_pair(entity, other) then
								add_pair(entity, other)
								world:emit_event("_EntityCollision", entity, other, mtv)
							end

							world:emit_event("_EntityColliding", entity, other, mtv)
						end
						---
					end
				end
			end,
		}
	},

	events = {
		--[[
		{ -- Call the collision functions of entities if they have them.
			event = "EntityColliding",
			func = function(world, ent1, ent2, mtv)
				if ent1.OnEntityColliding then
					ent1:OnEntityColliding(world, ent2, mtv)
				end

				---

				if ent2.OnEntityColliding then
					ent2:OnEntityColliding(world, ent1, -mtv)
				end
			end
		},
		{
			event = "EntityCollision",
			func = function(world, ent1, ent2, mtv)
				if ent1.OnEntityCollision then
					ent1:OnEntityCollision(world, ent2, mtv)
				end

				---

				if ent2.OnEntityCollision then
					ent2:OnEntityCollision(world, ent1, -mtv)
				end
			end
		},
		--]]

		-- Metaevent relays.
		{
			event = "_EntityCollision",
			func = function(world, ent1, ent2, mtv)
				if collision_eligible(ent1, ent2) then
					world:emit_event("EntityCollision", ent1, ent2, mtv)
				end
			end
		},
		{
			event = "_EntityColliding",
			func = function(world, ent1, ent2, mtv)
				if collision_eligible(ent1, ent2) then
					world:emit_event("EntityColliding", ent1, ent2, mtv)
				end
			end
		},
		{
			event = "_EntityCollisionStop",
			func = function(world, ent1, ent2)
				if collision_eligible(ent1, ent2) then
					world:emit_event("EntityCollisionStop", ent1, ent2)
				end
			end
		},

		{ -- Resolve collisions with physics!
			event = "EntityColliding",
			func = function(world, ent1, ent2, mtv)
				local REQ = {
					"CollisionPhysics",
					"Mass"
				}

				if table_has(ent1, REQ) and table_has(ent2, REQ) then
					world:emit_event("PhysicsCollision", ent1, ent2, mtv)
					physics_resolve_collision(world, ent1, ent2, mtv)
				end
			end
		}

		--[[
		{ -- DestroyOnEntityCollision
			event = "EntityColliding",
			func = function(world, ent1, ent2, mtv)
				if ent1.DestroyOnEntityCollision then
					world:destroy_entity(ent1)
				end

				if ent2.DestroyOnEntityCollision then
					world:destroy_entity(ent2)
				end
			end
		}
		--]]
	}
}
