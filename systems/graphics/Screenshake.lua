local vector = require("lib.hump.vector")
local util = require("lib.self.util")

local clamp = util.math.clamp

return {
	systems = {
		{
			name = "UpdateScreenshakeSource",
			requires = {"Position", "Screenshake"},
			update = function(source, world, dt)
				local ss = source.Screenshake
				assert( ss.intensity and ss.radius, "Screenshake component missing field(s)!")

				-- Initialise starting time if this is a timed source.
				if not ss.timer and ss.duration then
					source.Screenshake.timer = ss.duration
				end

				-- Step screenshake timer.
				if ss.timer then
					ss.timer = ss.timer - dt
					if ss.timer <= 0 then
						source.Screenshake = nil
						return
					end
				end

				local intensity = ss.intensity
				if ss.timer and ss.duration then -- Adjust timed source intensity.
					intensity = intensity * (ss.timer / ss.duration)
				end

				local camera_pos = vector.new(world.camera.x, world.camera.y)
				local dist_to_source = (source.Position - camera_pos):len()

				local final_intensity = clamp(0, intensity * ( 1 - (dist_to_source/ss.radius)), math.huge)

				world.screenshake = world.screenshake + final_intensity
			end
		}
	},

	events = {
		{ -- Screenshake for arena wall collisions.
			event = "ArenaCollision",
			func = function(world, entity, pos, side)
				local duration = 0.1
				local intensity = 1

				world:spawnEntity{
					Position = pos:clone(),
					Lifetime = duration,
					Screenshake = {
						intensity = intensity,
						radius = 100,
						duration = duration
					}
				}
			end
		},
		{ -- Screenshake for entity collision.
			event = "PhysicsCollision",
			func = function(world, ent1, ent2, mtv)
				local duration = 0.1
				local intensity = 1

				world:spawnEntity{
					Position = ent2.Position + mtv,
					Lifetime = duration,
					Screenshake = {
						intensity = intensity,
						radius = 100,
						duration = duration
					}
				}
			end
		}
	}
}
