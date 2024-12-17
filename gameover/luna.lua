local player2 = Player(2)
local blackscreen = false

Graphics.activateHud(false)
local activateinventory = false

function onStart()
	mem(0x00B2C5AC,FIELD_FLOAT, 3)
	SFX.play("gameover/gameover-sound.ogg")
end

function onTick()
	for i = 1,91 do
		Audio.sounds[i].muted = true
	end
end

function onInputUpdate()
	player.leftKeyPressing = false
	player.rightKeyPressing = false
	player.upKeyPressing = false
	player.downKeyPressing = false
	player.altJumpKeyPressing = false
	player.runKeyPressing = false
	player.altRunKeyPressing = false
	player.dropItemKeyPressing = false
	player.pauseKeyPressing = false
	player.jumpKeyPressing = false
end

function onEvent(eventName)
	if eventName == "Game Over Timing Execution 2" then
		SFX.play("gameover/gameover-announcer.ogg")
	end
	if eventName == "Game Over Timing Execution 3" then
		Level.exit()
	end
end

function onDraw()
	if blackscreen then
		Graphics.drawScreen{color = Color.black, priority = 10}
	end
end