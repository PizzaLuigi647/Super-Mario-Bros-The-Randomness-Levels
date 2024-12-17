local npc = {}

local npcManager = require 'npcManager'
local switch = require 'switch'

local id = NPC_ID

npcManager.setNpcSettings{
	id = id,
	
	width = 48,
	gfxwidth = 48,
	height = 84,
	gfxheight = 84,
	
	jumphurt = false,
	nohurt = true,
	
	noiceball = true,
	noyoshi = true,
	
	nogravity = true,
	noblockcollision = true,
	speed = 0,
	
	score = 0,
	time = 180,
	
	blockId = 761,
}

switch.setMaxTime(NPC.config[id].time)

local npcutils = require 'npcs/npcutils'

function npc.onCameraDrawNPC(v)
	if v.despawnTimer <= 0 then return end
	
	if v.ai1 == 2 then
		local frame = math.floor(v.ai3) + 2
		
		if frame > 2 then
			frame = frame + 1
		end
		
		npcutils.drawNPC(v, {
			frame = 3,
		})
		
		npcutils.drawNPC(v, {
			frame = frame,
			yOffset = v.ai2,
		})
	end
end

function npc.onTickEndNPC(v)
	if v.ai1 == 2 then
		if v.despawnTimer > 0 then
			v.despawnTimer = 180
		end
	
		v.animationFrame = -1
		
		if v.ai2 > 0 then
			v.ai2 = v.ai2 - 0.25
		end
		
		v.ai3 = (v.ai3 + 0.1) % 3
	elseif v.ai1 == 1 then
		v.animationFrame = 1
		
		v.ai2 = v.ai2 + 1
		if v.ai2 > 16 then
			v.ai2 = 12
			v.ai1 = 2
		end
	else
		v.animationFrame = 0
	end
end

function npc.onNPCKill(e, v, r)
	if v.id ~= id then return end
	
	if r == 1 or r == HARM_TYPE_SPINJUMP then
		e.cancelled = true
		v.friendly = true
		v.ai1 = 1
		v.speedX = 0
		v.speedY = 0
		
		local vx = v.x - camera.x
		local vy = v.y - camera.y
		
		switch.activate(vx + v.width / 2, vy + v.height / 2, NPC.config[v.id].blockId)
	else
		e.cancelled = true
	end
end

function npc.onInitAPI()
	npcManager.registerEvent(id, npc, 'onCameraDrawNPC')
	npcManager.registerEvent(id, npc, 'onTickEndNPC')
	npcManager.registerHarmTypes(id, {HARM_TYPE_JUMP}, {});	
	registerEvent(npc, 'onNPCKill')
end

return npc