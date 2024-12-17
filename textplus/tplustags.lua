local tags = {}

-- Utility function to perform shallow copy
local function shallowCopy(tbl)
	local newtbl = {}
	for k, v in pairs(tbl) do
		newtbl[k] = v
	end
	return newtbl
end

-- Alternate utility function to layer one table on another using metatables
-- NOTE: Not currently used, but need to benchmark. May be faster than
--       shallowCopy but may leave more for work for garbage collection.
local function shallowCopyMetatable(tbl)
	return setmetatable({}, {__index=tbl})
end

-- Tag factory for simple tags
local function simpleTag(fmtName)
	return function (fmt, out, args)
		if not fmt[fmtName] then
			fmt = shallowCopy(fmt)
			fmt[fmtName] = true
		end
		return fmt
	end
end
local function oneArgTag(fmtName, default)
    return function (fmt, out, args)
		local arg = args[1]
		if (arg == nil) then
			arg = default
		end
        if not fmt[fmtName] ~= args[1] then
            fmt = shallowCopy(fmt)
            fmt[fmtName] = args[1]
        end
        return fmt
    end
end
local function multiArgTag(fmtName)
    return function (fmt, out, args)
		fmt = shallowCopy(fmt)
		fmt[fmtName] = args
        return fmt
    end
end

-- Define tags
do

	-- Simple tags
	local simpleTags = {
	}
	for _,v in ipairs(simpleTags) do
		tags[v] = simpleTag(v)
	end

	-- One-argument tags (optional default arg in brackets)
	local oneArgTags = {
		"align", "tremble", "wave"
	}
	for _,v in ipairs(oneArgTags) do
		local default = nil
		if rawtype(v) == "table" then
			v, default = v[1], v[2]
		end
		tags[v] = oneArgTag(v,default)
	end

	-- Multi-argument tags
	local multiArgTags = {
		
	}
	for _,v in ipairs(multiArgTags) do
		tags[v] = multiArgTag(v)
	end
	
	function tags.greater(fmt, out, args)
		out[#out+1] = {string.byte(">"), fmt=fmt}
		return fmt
	end

	function tags.less(fmt, out, args)
		out[#out+1] = {string.byte("<"), fmt=fmt}
		return fmt
	end
	
	tags["break"] = function(fmt, out, args)
		out[#out+1] = {string.byte("\n"), fmt=fmt}
		return fmt
	end
	
	-- Glitch tag
	function tags.glitch(fmt, out, args)
		local chance = args.chance or args[1] or 1.0
		local delay = args.delay or args[2] or 1
		local useemoji = (args.useemoji or args[3] or "true") == "true"
		
		fmt = shallowCopy(fmt)
        fmt.glitch = {chance = chance, delay = delay, useemoji = useemoji}
		
        return fmt
    end	

	-- Color tag with parsing
	function tags.color(fmt, out, args)
		local c
		if args[1] == "rainbow" then
			c = args[1]
		else
			c = Color.parse(args[1])
		end
        if not fmt.color ~= c then
            fmt = shallowCopy(fmt)
            fmt.color = c
        end
        return fmt
    end	
	
	-- Size tag
	function tags.size(fmt, out, args)
		local scale = args.scale or args[1]
		if scale ~= nil then
			fmt = shallowCopy(fmt)
			fmt.xscale = fmt.xscale*scale
			fmt.yscale = fmt.yscale*scale
		end
		
        return fmt
    end	
	
	-- Image tag
	function tags.image(fmt, out, args)
		local src = args.src or args[1]
		src = Misc.resolveGraphicsFile(src)
		if src ~= nil then
			local img = Graphics.loadImage(src)
			if img ~= nil then
				local seg = {img=img, argWidth=args.width, argHeight=args.height, maxWidth=args.maxWidth or args.maxwidth, maxHeight=args.maxHeight or args.maxheight, smooth=(args.smooth == 'true'), fmt=fmt}
				
				-- TODO: Consider supporting image subsets?
				
				out[#out+1] = seg
			end
		end
		
        return fmt
    end	
	
	-- Emoji tag (like image tag, but scaled to font height)
	function tags.emoji(fmt, out, args)
		local src = args.src or args[1]
		src = Misc.resolveGraphicsFile(src)
		if src ~= nil then
			local img = Graphics.loadImage(src)
			if img ~= nil then
				local w, h = img.width, img.height
				
				-- Scale to font ascent
				local targetH = fmt.font.ascent * fmt.yscale
				w = w * (targetH / h)
				h = targetH
				
				local seg = {img=img, argWidth=w, argHeight=h, fmt=fmt}
				
				out[#out+1] = seg
			end
		end
		
        return fmt
    end	
	
	-- BULK-FORMATTING TAGS
	-- Style tag (applies a style to the text until the end of the page, overrides page style)
	local styleProperties = {color="colour",xscale=1,yscale=1}
	tags.style = function (fmt, out, args)
		local formatTbl = {}

		-- Get standard arguments (check for alias and randomization if applicable)
		for  k,v in pairs (styleProperties)  do
			formatTbl[k] = args[k]
			if  args[k] == nil  and  type(v) == "string"  then
				formatTbl[k] = args[v]
			end
		end

		-- Output the formatting table
		out[#out+1] = {style=formatTbl}
	end

	-- Aliases
	do
		tags.gt      = tags.greater
		tags.lt      = tags.less
		tags.br      = tags['break'] -- ('break' is a reserved keyword in Lua)
		tags.img     = tags.image
		tags.colour  = tags.color
		tags.garbage = tags.glitch
	end
end

return tags