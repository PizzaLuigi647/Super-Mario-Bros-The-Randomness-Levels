local switch = {}
local active = false

local clock = Sprite{
	frames = 6,
	
	pivot = Sprite.align.CENTER, 
	texpivot = Sprite.align.CENTRE,
	
	texture = Graphics.loadImage "clock.png",
}

local capture = Graphics.CaptureBuffer(800, 600)

local clock_scale = 0
local clock_rotation = 0
local clock_time = 0
local clock_frame = 5
local origX = 0
local origY = 0
local scaleDown = false

local font_scale = 0
local scaled = false
local start = 0
local font_y = 300
local font_timer = 0

local timer = 180
local earthquake_timer = 0

function switch.setMaxTime(val)
	if not active then
		timer = val
	end
end

function switch.isActive()
	return active
end

local switchcolors = require("switchcolors")

function switch.activate(x, y, id)
	if not active then
		if id then
			switchcolors.switch(id, id + 1)
		end
		
		for i = 0, 20 do
			Audio.SeizeStream(i)
			Audio.MusicOpen("hurry_up.ogg")
			Audio.MusicPlay()
		end
		
		clock.x = x
		clock.y = y
		origX = x
		origY = y
		
		active = true
		Misc.pause()
	end
end

local function linear(t, b, c, d)
  return c * t / d + b
end

local textplus = require 'textplus'
local font = textplus.loadFont("font.ini")

function DecimalsToMinutes(dec)
	local ms = tonumber(dec)
	
	if ms < 0 then
		ms = 0
	end
	
	local s = tostring(math.floor(ms % 60))
	
	if #s == 1 then
		s = 0 .. s
	end
	
	return math.floor(ms / 60)..":".. s
end

local shader = Shader()
shader:compileFromFile(nil, Misc.resolveFile("wave.frag"))

local intensity = 0

function switch.onCameraDraw()
	if active then
		capture:captureAt(-96.5)
		
		Graphics.drawBox{
			texture = capture,
			
			x = 0,
			y = 0,
			
			shader = shader,
			uniforms = {
				time = lunatime.tick() / 2,
				intensity = intensity,
			},
			
			priority = -96.0
		}
		
		Graphics.drawBox{
			texture = capture,
			
			x = 0,
			y = 0,
			
			shader = shader,
			uniforms = {
				time = lunatime.tick() / 2,
				intensity = 4,
			},
			color = Color.red .. math.sin(lunatime.tick() / 25) / 4,
			
			priority = -96.0
		}
	
		if not scaleDown then
			clock_rotation = (clock_rotation + 24) % 360
			clock_scale = clock_scale + 0.1
			
			if clock_scale > 2 then
				clock_time = clock_time + 1
				
				clock.x = linear(clock_time, origX, 400 - origX - 64, 48)
				clock.y = linear(clock_time, origY, 128 - origY, 48)
			
				clock_time = math.clamp(clock_time, 0, 48)
				
				clock_scale = 2
				
				if clock_time >= 48 and clock_rotation >= -16 and clock_rotation <= 16  then
					clock_rotation = 0
					clock_scale = 2
					clock_time = 0
					scaleDown = true
				end
			end
		else
			if clock_scale > 1 then
				clock_scale = clock_scale - 0.1
			end
		end
		
		clock.scale = vector(clock_scale, clock_scale)
		clock.rotation = clock_rotation
		
		clock:draw{
			priority = 5,
			frame = math.floor(clock_frame + 1)
		}
		
		-- timer
		
		if start < 6  then
			if not scaled then
				font_scale = font_scale + 0.067
				
				if font_scale > 2 then
					start = start + 1
					
					if start == 6 then
						Misc.unpause()
						font_scale = 2
					else
						font_scale = 2
						scaled = true
					end
				end
			else
				font_scale = font_scale - 0.067
				
				if font_scale < 1 then
					font_scale = 1
					scaled = false
				end
			end
		elseif start >= 6 then
			font_timer = font_timer + 1
			
			font_y = linear(font_timer, 300, 160 - 300, 24)
			
			font_timer = math.clamp(font_timer, 0, 24)
			
			if not Misc.isPaused() then
				timer = timer - 0.015
				clock_frame = (clock_frame + 0.25) % 6
			end
		end
		
		textplus.print{
			text = DecimalsToMinutes(timer),
			
			x = 432,
			y = font_y,
			
			xscale = font_scale,
			yscale = font_scale,
			
			pivot = vector(0.5, 0.5),
			color = (timer < 20 and timer > 10 and Color.yellow) or (timer <= 10 and Color.red) or Color.white,
			font = font,
		}
	end
end

local dead = false

function switch.onTickEnd()
	if active then
		intensity = intensity + 0.1
		
		if intensity > 3 then
			intensity = 3
		end

		earthquake_timer = earthquake_timer + 1
	
		if earthquake_timer > 64 then
			Defines.earthquake = math.random(1,4)
			earthquake_timer = 0
		end
		
		local stop = 0
		
		if not dead then
			for k,p in ipairs(Player.get()) do
				if p.deathTimer <= 0 then
					if timer <= 0 then
						p:kill()
						dead = true
					end
				end
				
				if p.deathTimer > 0 then
					stop = stop + 1
				end
			end
		end
		
		if stop == Player.count() then
			for i = 0, 20 do
				Audio.SeizeStream(i)
				Audio.MusicStop()
			end
		end	
	end
end

function switch.onInitAPI()
	registerEvent(switch, 'onCameraDraw')
	registerEvent(switch, 'onTickEnd')
end

return switch