local npcManager = require("npcManager")
local health = require("customHealth")

local lifeUp = {}
local npcID = NPC_ID

local lifeUpSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	width = 32,
	height = 32,
	gfxoffsetx = 0,
	gfxoffsety = 0,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 0,
	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.

	nohurt = true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,
	notcointransformable = true,

	jumphurt = true, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false

	grabside=false,
	grabtop=false,
	isinteractable = true,
	powerup = true,
	score = 6,

	soundEffect = Misc.resolveSoundFile("SFX/smg_life_mushroom"), -- The SFX that will play when the player collects the power-up.
	soundEffectAlt = Misc.resolveSoundFile("SFX/smrpg_item"), -- The SFX that will play when the player collects the power-up while health is full.

	soundEffectVolume = 0.45, -- Volume of "soundEffect"
	soundEffectVolumeAlt = 0.4, -- Volume of "soundEffectAlt"
}

npcManager.setNpcSettings(lifeUpSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
		HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

function lifeUp.onInitAPI()
	registerEvent(lifeUp, "onPostNPCCollect")
end

function lifeUp.onPostNPCCollect(v, p)
    if v.id ~= npcID then return end

	local config = NPC.config[v.id]

	Misc.givePoints(config.score, v, true)

	if health.dareActive then return end

	if health.curHealth <= health.settings.mainHealth then
		SFX.play(config.soundEffect, config.soundEffectVolume)
		health.setMax()
	else
		SFX.play(config.soundEffectAlt, config.soundEffectVolumeAlt)
		health.set(health.settings.maxHealth)
	end
end

return lifeUp