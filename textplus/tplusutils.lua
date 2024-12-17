local utils = {}
local string_byte = string.byte
local string_len = string.len
local bit_lshift = bit.lshift
local bit_band = bit.band
local bit_bor = bit.bor

-- Function to turn a UTF-8 string into a table of character codes.
-- Invalid bytes are skipped.
function utils.strToCodes(input, skippedCodeMap)
	local out = {}
	
	local len = string_len(input)
	local inCursor = 1
	while true do
		local code = string_byte(input, inCursor)
		inCursor = inCursor + 1
		
		if (code == nil) then
			-- End of string
			break
		elseif (code < 128) then
			-- Single byte
			out[#out+1] = code
		elseif (code < 192) or (code >= 248) then
			-- Invalid
		else
			-- Two or more bytes
			
			local extraLen = 0
			if code < 224 then
				-- 2 byte character
				code = bit_band(code, 0x1f)
				extraLen = 1
			elseif code < 240 then
				-- 3 byte character
				code = bit_band(code, 0x0f)
				extraLen = 2
			else
				-- 4 byte character
				code = bit_band(code, 0x07)
				extraLen = 3
			end
			
			for i=1,extraLen do
				local b2 = string_byte(input, inCursor)
				inCursor = inCursor + 1
				
				-- If invalid, break
				if (b2 == nil) or (b2 < 128) or (b2 >= 192) then
					code = nil
					break
				end
				
				-- Shift and add new bits
				code = bit_bor(bit_lshift(code, 6), bit_band(b2, 0x3f))
			end
			
			-- If we still are valid, store the character code
			if (code ~= nil) and ((skippedCodeMap == nil) or not skippedCodeMap[code]) then
				out[#out+1] = code
			end
		end
	end
	
	return out
end

function utils.strToCodeMap(input)
	local characters = utils.strToCodes(input)
	local codeMap = {}
	for _,code in ipairs(characters) do
		codeMap[code] = true
	end
	return codeMap
end

return utils