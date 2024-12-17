local block = {}
local blockManager = require("blockManager")

local id = BLOCK_ID

blockManager.setBlockSettings{
	id = id,
	passthrough = true,
}

return block