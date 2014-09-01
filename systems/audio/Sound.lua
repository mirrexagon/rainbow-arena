local timer = require("lib.hump.timer")
local util = require("lib.self.util")

---

local clamp = util.math.clamp

---

local collision_sound = "audio/collision.wav"
local volume_threshold_speed = 1600
local collision_max_volume = 0.5

---

local can_spawn_col_sound = true
local sound_spawn_delay = 0.05

---

return {
	systems = {
		{
			name = "UpdateSoundSource",
			requires = {"Position", "Sound"},
			update = function(source, world, dt)
				local ss = source.Sound
				assert(ss.source, "Sound component missing source field!")

				ss.source:setPosition(source.Position.x/SOUND_POSITION_SCALE, source.Position.y/SOUND_POSITION_SCALE, 0)

				local pitch = world.speed
				if ss.pitch then
					pitch = pitch * ss.pitch
				end
				ss.source:setPitch(pitch)

				if ss.volume then
					ss.source:setVolume(ss.volume)
				end

				if not ss.playing then
					ss.source:play()
					ss.playing = true
				end

				if ss.source:isStopped() and ss.playing then
					source.Sound = nil
				end
			end
		}
	},

	events = {
		{ -- Sound for arena wall collisions.
			event = "ArenaCollision",
			func = function(world, entity, pos, side)
				local source = love.audio.newSource(collision_sound)

				world:spawnEntity{
					Position = pos,
					Lifetime = 0.3,
					Sound = {
						source = source,
						volume = clamp(0, entity.Velocity:len() / volume_threshold_speed, collision_max_volume)
					}
				}
			end
		},
		{ -- Sound for entity collision.
			event = "PhysicsCollision",
			func = function(world, ent1, ent2, mtv)
				if can_spawn_col_sound then
					local source = love.audio.newSource(collision_sound)
					local pos = ent2.Position + mtv

					world:spawnEntity{
						Position = pos,
						Lifetime = 0.3,
						Sound = {
							source = source,
							volume = clamp(0, (ent1.Velocity + ent2.Velocity):len() / volume_threshold_speed, collision_max_volume)						}
					}

					can_spawn_col_sound = false
					timer.add(sound_spawn_delay, function()
						can_spawn_col_sound = true
					end)
				end
			end
		}
	}
}
