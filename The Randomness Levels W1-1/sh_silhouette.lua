local c = {}

local shader = Shader()
shader:compileFromFile(nil, "sh_silhouette.frag")

c.speed = 1
c.lowpriority = -95
c.priority = 0
c.color = Color.black

local cb = Graphics.CaptureBuffer(800, 600)
local bg = Graphics.CaptureBuffer(800, 600)
function c.onInitAPI()
    registerEvent(c, "onCameraDraw")
end

function c.onCameraDraw()
    bg:captureAt(c.lowpriority)
    cb:captureAt(c.priority)

    local bounds = Section(player.section).boundary

    Graphics.drawScreen{
        texture = cb,
        priority = c.priority,
        shader = shader,
        uniforms = {
            iTexture = texture,
            iBackdrop = bg,
            iColor = c.color
        }
    }
end

return c