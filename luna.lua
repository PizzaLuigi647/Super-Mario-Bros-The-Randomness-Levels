local CAMERA_WIDTH = 1066
local CAMERA_HEIGHT = 600

function onStart()
    camera.width = CAMERA_WIDTH
    camera.height = CAMERA_HEIGHT
    Graphics.setMainFramebufferSize(CAMERA_WIDTH, CAMERA_HEIGHT)
end

function onCameraUpdate()
    camera.width, camera.height = Graphics.getMainFramebufferSize()
end

-- TOTALLY NOT STOLEN Widescreen code, TRRRUUUUSSSSTTTT MEEEEE,,, :eyes: 

local nobrokensmbxkicker = require("nobrokensmbxkicker")

local inventory = require("simpleInventory")

local health = require("customHealth")

require('minHUD')

local pauseMenu = require("pauseMenu")

local aw = require("anotherwalljump")
aw.registerAllPlayersDefault()

local charnames = require("charnames")

dive = require("dive")

local warpTransition = require("warpTransition")

local ppp = require('playerphysicspatch')

_G.extrasounds = require("extrasounds")

twirl = require("twirl")

local fakeblocks = require("blocks/ai/fakeblocks")

local littleDialogue = require("littleDialogue")
littleDialogue.registerStyle("smb1",{ })

-- Window name/icon
if not GameData.windowIconSet then
    Misc.setWindowIcon(Graphics.loadImageResolved("launcher/icon.png"))
    GameData.windowIconSet = true
end

Misc.setWindowTitle("SMB: The Randomness Levels!")


GameData.debugMuteMusic = GameData.debugMuteMusic or false
GameData.debugSwapControls = GameData.debugSwapControls or false