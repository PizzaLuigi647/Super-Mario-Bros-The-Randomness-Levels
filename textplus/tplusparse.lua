local tplusParse = {}
local tplusUtils = require("textplus/tplusutils")
local tplusTags = require("textplus/tplustags")

-- Maps of characters that we are going to skip
local skippedCharacterMap = tplusUtils.strToCodeMap("\r")

local builtinAutoSelfClosingTagMap = {img=true, image=true, emoji=true, less=true, lt=true, greater=true, gt=true, ["break"]=true, br=true}
local customAutoSelfClosingTagMap = {}

------------------------
-- GRAMMAR DEFINITION --
------------------------

local function defineGrammar()
	local L = lpeg.locale()
	local P,V,C,Ct,S,R,Cg,Cc,Ct,Cf,Cmt = 
		lpeg.P, lpeg.V, lpeg.C, lpeg.Ct, lpeg.S, lpeg.R, lpeg.Cg, lpeg.Cc, lpeg.Ct, lpeg.Cf, lpeg.Cmt

	-- Helper function to insert named arguments in a table, but insert unnamed
	-- arguments in numeric order
	local function tableset(tbl, name, val)
		if (name == "") then
			tbl[#tbl+1] = val
		else
			tbl[name] = val
		end
		return tbl
	end

	-- Helper function to check for send ending tags
	local function autoSelfEndingTagFilter(s, p, name)
		if (builtinAutoSelfClosingTagMap[name] or customAutoSelfClosingTagMap[name]) then
			return true, name
		else
			return false, nil
		end
	end
	
	-- Helper function to turn {tagName, args, contents, tagEndName} into a
	-- table of named fields.
	local function tagHelper(tagName, args, contents, tagEndName)
		-- Self-ending tag case
		if (contents == nil) and (tagEndName == nil) then
			return {tag=tagName, args=args}
		end

		if (tagName ~= tagEndName) then
			error("Unterminated <"..tagName.."> tag!")
		end
		return {tag=tagName, args=args, contents=contents}
	end

	-------------------------------
	-- Definitions ahead of time --
	-------------------------------

	local AnyByte = R("\000\255")
	local Space = (S " \t\r\n")^1
	local OptSpace = Space^-1

	-- Literally anything that isn't < or > is valid for plaintext
	local Plaintext = C((AnyByte - S("<>"))^1) +
	                   P("<plaintext>") * C((AnyByte - P("</plaintext>"))^1) * P("</plaintext>")

	-- List of characters safe for putting bare in tag names/args/etc
	local TagSafeChar = AnyByte - S("<>/=\"' \t\r\n")

	-- Let's consider anything except space, <, or > valid for tag names
	local TagName = C(TagSafeChar^1)
	local ArgName = C(TagSafeChar^1)

	-- Let's make some rules for argument values...
	local BareArgValue = C(TagSafeChar^1)
	local QuotedArgValue = (P'"' * C((AnyByte - P'"')^1) * P'"') +
	                       (P"'" * C((AnyByte - P"'")^1) * P"'")
	local ArgValue = QuotedArgValue + BareArgValue

	grammar = P{
		"Message",

		-- Define tag arguments
		-- This is set up so each argument produces a capture group consisting of
		-- two captures. The first capture is the argument name if there is one
		-- or an empty string otherwise. The second capture is the argument value.
		-- These capture groups are then "folded" to set up a 
		UnnamedArg = Cg(C("") * ArgValue),
		NamedArg = Cg(ArgName * "=" * ArgValue),
		Arg = V"NamedArg" + V"UnnamedArg",
		Args = (Cf(Ct("") * (Space * V"Arg")^1, tableset) + Ct("")) * OptSpace,

		-- Define auto-self-ending tags
		AutoSelfEndingTag = (P"<" * Cmt(TagName, autoSelfEndingTagFilter) * V"Args" * P(">")) / tagHelper,
		
		-- Define self-ending tags
		SelfEndingTag = (P"<" * TagName * V"Args" * P("/>")) / tagHelper,

		-- Define tags with contents
		StartTag = P"<" * TagName * V"Args" * P">",
		EndTag = P"<" * "/" * TagName * P">",
		NestingTag = (V"StartTag" * V"Message" * V"EndTag") / tagHelper,

		-- Define tags...
		Tag = V"AutoSelfEndingTag" + V"NestingTag" + V"SelfEndingTag",

		-- Define a message as a sequence of tags and plaintext
		Message = Ct((Plaintext + V"Tag")^0)
	}
	
	return (function (s)
		return lpeg.match(grammar, s)
	end)
end
local parse = defineGrammar()

-----------------------
-- FORMATTING ENGINE --
-----------------------

-- Function to flatten formatting from parse tree
-- Pass in global formatting options via 'fmt'
local resolveFormatting
resolveFormatting = function(parseTree, fmt, out, customTags)
	-- Optional output table
	if out == nil then
		out = {}
	end
	
	-- Optional fmt table
	if fmt == nil then
		fmt = {}
	end
	
	-- Loop over elements
	for _,v in ipairs(parseTree) do
		if type(v) == "string" then
			-- If the element is a string, insert it in the flattened list
			
			-- Convert string the character code sequence
			local seq = tplusUtils.strToCodes(v, skippedCharacterMap)
			
			-- Associate formatting with character code sequence
			seq.fmt = fmt
			
			-- Add the sequence seguement to the list
			out[#out+1] = seq
		else
			local tagHandler = tplusTags[v.tag]
			if (tagHandler == nil) and (customTags ~= nil) then
				tagHandler = customTags[v.tag]
			end
			
			if tagHandler ~= nil then
				-- Call the tag handler
				local childFmt = tagHandler(fmt, out, v.args)
				if v.contents then
					if childFmt == nil then
						error("Contents are not allowed for the '" .. tostring(v.tag) .. "' tag")
					end
					
					-- If there are contents
					resolveFormatting(v.contents, childFmt, out, customTags)
				end
			else
				error("Unknown tag '" .. tostring(v.tag) .. "'")
			end
		end
	end
	
	return out
end

local function parseAndFormat(input, fmt, customTags, customAutoSelfClosingTags)
	if (customAutoSelfClosingTags) then
		for _,v in ipairs(customAutoSelfClosingTags) do
			customAutoSelfClosingTagMap[v] = true
		end
	end

	-- Parse the test string into a parse tree	
	local parseTree = parse(input)
	
	if (customAutoSelfClosingTags) then
		customAutoSelfClosingTagMap = {}
	end
	
	-- Resolve the formatting
	local formattedText = resolveFormatting(parseTree, fmt, nil, customTags)
	
	return formattedText
end
tplusParse.parseAndFormat = parseAndFormat

---------------
-- TEST CODE --
---------------

local tt = 0
tplusParse.runTest = function ()
	local textplusLayout = API.load('textplus/tpluslayout_new')
	local textplusFont = API.load('textplus/tplusfont_new')
	local textplusRender = API.load('textplus/tplusrender')

	-- Define a test string
	local testString = [[Lorem ipsum dolo

r sit amet, consectetur adipiscing elit. Aliquam in odio sed neque ornare commodo. Cras suscipit dapibus nunc at tincidunt. Nam ultrices vel leo id scelerisque. Donec sollicitudin semper velit placerat feugiat. Nulla bibendum mi ut tortor sagittis viverra. Etiam arcu justo, egestas vel risus quis, venenatis facilisis turpis. Curabitur id felis eu tortor tincidunt sagittis. Integer faucibus ex ut dolor semper consequat. Pellentesque interdum ultricies ligula, ac imperdiet nisl. In neque mi, euismod nec erat et, semper maximus nisi. Quisque erat odio, blandit vitae mauris non, tempus facilisis augue. Phasellus bibendum, augue ac lobortis rutrum, ante lacus lacinia lacus, vitae aliquam lorem metus sed tellus. Ut viverra molestie ante, vel facilisis mauris. Sed quis iaculis lacus. Morbi nunc quam, suscipit eu euismod quis, auctor eget purus. Proin condimentum at leo nec condimentum. Praesent dictum, justo id posuere efficitur, metus tellus suscipit elit, non efficitur libero turpis pulvinar dolor. Integer lobortis placerat vehicula. Duis ac odio nulla. Nam quis sem sem. Proin ante turpis, aliquam eget metus sed, placerat faucibus mi. Proin felis felis, interdum ac massa ac, molestie egestas nibh. Praesent aliquet magna nisi, vel bibendum lectus convallis sit amet. Vestibulum neque risus, vestibulum ut fermentum et, molestie ac augue. Nunc dolor arcu, malesuada ac metus et, commodo accumsan tortor. Interdum et malesuada fames ac ante ipsum primis in faucibus. Praesent at sodales lacus, quis euismod elit. Maecenas laoreet ut ex sed rutrum. Aliquam gravida ligula eget efficitur tempus. Curabitur non eros felis. Nulla aliquam lacus eu massa viverra, non tristique sapien cursus. Donec consectetur non nunc et vehicula. Vestibulum nec venenatis ex, in rhoncus diam. Sed vel egestas lectus. Proin quis dui vitae orci volutpat bibendum eu sed sem. Phasellus efficitur lectus ut est egestas tincidunt. Donec lacus eros, dapibus facilisis justo at, porta vehicula tortor. Proin pellentesque augue nulla, quis pretium libero pulvinar nec. Proin dictum luctus odio vitae placerat. Nulla et bibendum magna. Sed sit amet tincidunt turpis. Sed lacinia eros nec ligula molestie suscipit. Cras finibus ac turpis sit amet tincidunt. Nullam mauris nunc, dictum eget orci ut, porta tristique lacus. Duis metus sapien, vehicula malesuada magna eget, molestie sodales arcu. Sed consectetur orci velit, in egestas neque sollicitudin auctor. Nam gravida imperdiet nisl, id pharetra enim fermentum non. Vestibulum leo felis, cursus ut eros a, ultrices malesuada arcu. Maecenas viverra scelerisque posuere. Quisque at euismod purus. Nullam vestibulum ligula et libero lobortis, vel lobortis mauris ornare. Nam ullamcorper augue nec tincidunt posuere. Curabitur a rhoncus lorem. Sed ut augue ac mauris tempus blandit. Sed tristique, odio bibendum bibendum consequat, ante ex cursus enim, eu posuere dui est tristique arcu. Curabitur eleifend dolor faucibus molestie accumsan. Nulla facilisi. Morbi vestibulum quam ex, tempor pulvinar nunc egestas sed. Duis mollis sem odio, eu tempus ipsum ullamcorper fringilla. Nam tristique orci ante, ac tempor lectus venenatis id. Suspendisse in finibus nunc, sed eleifend neque. Integer a vulputate nunc, porttitor imperdiet turpis. Nam vehicula porttitor faucibus. Integer pharetra, nunc lacinia blandit efficitur, magna risus lacinia massa, vitae pulvinar est magna ut orci. In lobortis aliquet massa quis feugiat. Integer nec est nec nulla euismod auctor. Praesent ultricies mauris sit amet massa pharetra, non interdum arcu accumsan. Nam iaculis, nisi sed rutrum convallis, lectus nulla rhoncus sem, quis aliquet augue dui ac massa. Phasellus id gravida ligula. Aliquam imperdiet dolor in nunc malesuada, in posuere urna iaculis. Aliquam fermentum pulvinar luctus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Donec tellus urna, sodales eleifend pellentesque vitae, pulvinar a purus. Mauris eu ante pharetra, consectetur mauris id, volutpat nulla. Proin ipsum nunc, semper dictum lorem in, eleifend suscipit diam. Praesent vitae bibendum purus. Pellentesque eu ligula mauris. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Nam auctor odio quis dui venenatis, euismod gravida enim facilisis. Morbi ultrices massa a risus scelerisque, ac convallis turpis euismod. Vestibulum in lorem nec erat finibus hendrerit ut blandit risus. Curabitur in dui dui. Phasellus dapibus ornare ullamcorper. Nullam est mi, hendrerit id pellentesque ac, sollicitudin ac odio. Donec feugiat tempus quam. Vivamus in maximus turpis, eget tempor tellus. Nullam eu interdum lacus. Nullam consectetur laoreet mattis. Curabitur vulputate volutpat urna non luctus. Praesent iaculis semper erat, a gravida nunc vestibulum eu. Nullam finibus quam ac enim elementum, non ultricies mi malesuada. Nullam libero dolor, elementum nec vulputate non, volutpat et neque. Donec eget enim et nibh tempus cursus id venenatis velit. Phasellus commodo est et quam sodales, et consectetur justo pretium. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam ut sapien congue, dapibus augue quis, accumsan nisl. Vivamus viverra ipsum tincidunt mauris molestie porttitor. Ut dignissim magna nec justo eleifend rutrum. Phasellus sit amet ante mollis, pulvinar dui quis, sollicitudin mi. Sed in feugiat nisi. Morbi ipsum purus, suscipit quis vehicula lobortis, varius eu magna. Proin eget venenatis eros. Nunc dapibus condimentum quam, at congue lorem sollicitudin feugiat. Duis sed ornare tellus, nec viverra velit. Quisque gravida cursus justo sed congue. Nulla lobortis vehicula scelerisque. Quisque vestibulum neque felis, sed eleifend nisi congue eget. Pellentesque a feugiat sapien. Nulla gravida, augue tristique consequat venenatis, ligula arcu pulvinar tortor, sit amet venenatis libero quam nec orci. Donec cursus euismod massa ut aliquet. Etiam accumsan commodo metus quis vehicula. Sed ultrices mauris tempor ligula dapibus, eu pretium mauris iaculis. Phasellus sit amet tortor varius felis eleifend pharetra. Aenean ultricies, diam a pulvinar imperdiet, justo urna ornare nisl, in scelerisque odio lorem eu enim. Etiam volutpat nulla ac ex porttitor, aliquet scelerisque nisl ornare. Vivamus ut purus elementum, accumsan ligula in, cursus nunc. Curabitur tempor erat sed auctor eleifend. Nunc ut leo ullamcorper, venenatis orci sit amet, cursus turpis. Fusce malesuada interdum varius. Donec ac tellus justo. Donec nec velit a nibh ullamcorper consequat a a massa. Proin ut luctus neque. Quisque eleifend urna faucibus aliquam semper. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Nunc tortor libero, euismod nec ante pretium, mollis maximus ligula. Fusce non laoreet elit. Nam commodo dapibus velit. Vivamus lacinia justo odio, eget hendrerit nunc tristique sed. Sed pretium lorem vel tristique convallis. Phasellus eget porttitor quam, sit amet porttitor est. Nunc consequat eros nec magna tincidunt, non consectetur nulla pellentesque. Donec tristique dolor sed lorem placerat imperdiet. In hac habitasse platea dictumst. Sed nec placerat felis. Phasellus eget vehicula ex, nec imperdiet neque. Etiam turpis arcu, iaculis sed tortor et, dignissim aliquam tortor. Morbi venenatis porta ex, nec hendrerit quam mattis ac. Nulla mollis iaculis leo volutpat venenatis. Donec non porttitor justo. Praesent pharetra eros nec mi fringilla, ac tempus orci ornare. Aliquam erat volutpat. Quisque placerat suscipit ante, sed hendrerit arcu ullamcorper nec. Integer laoreet risus vel viverra euismod. Pellentesque luctus erat et erat interdum, vulputate lacinia urna venenatis. Sed quis felis in lacus faucibus luctus. Cras ac elit vel elit suscipit gravida id et enim. Duis semper eu purus eu imperdiet. Curabitur pulvinar hendrerit vulputate. Praesent viverra orci non eros facilisis porta. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. In semper felis ac ultrices facilisis. Nulla augue dui, condimentum ut lacus non, finibus pellentesque nisl. Curabitur id venenatis mi, sit amet rhoncus lacus. Suspendisse lobortis diam iaculis massa viverra hendrerit. Maecenas lorem massa, facilisis ut lacus sit amet, suscipit venenatis turpis. Proin semper feugiat odio id imperdiet. Donec eu nisi eu sem laoreet mattis eget eget nibh. Ut consectetur ipsum nec metus maximus, id cursus ex scelerisque. Duis sit amet turpis et sapien porta pulvinar. Morbi laoreet bibendum sodales. Sed in tortor fringilla dolor laoreet ullamcorper ut quis mi. Pellentesque faucibus purus nibh, non gravida mauris convallis sit amet. Nulla in leo fringilla, cursus tellus dapibus, posuere nisl. Curabitur tincidunt tellus orci, eget gravida ligula luctus semper. Vestibulum id purus quis nulla facilisis euismod a a justo. Mauris quis porta lorem. Morbi tristique in nunc nec mattis. Etiam ut diam quis diam imperdiet tincidunt sit amet ut ipsum. Nulla non dui congue elit accumsan commodo. Praesent id eros eu justo scelerisque congue sed quis neque. Nulla malesuada ipsum metus, eget rhoncus ligula pretium ut. Phasellus tempor, orci ac accumsan finibus, sapien urna faucibus est, non malesuada enim leo nec augue. Sed pharetra at neque quis luctus. Mauris non justo luctus velit vulputate ullamcorper lobortis pulvinar risus. Nulla sagittis enim eu lacus ultrices, at molestie diam rhoncus. Ut posuere sapien ac ante fermentum sollicitudin quis a risus. Fusce condimentum nibh ac pharetra vestibulum. Sed convallis felis pellentesque, sollicitudin leo id, varius augue. Etiam venenatis elit finibus blandit mollis. Nunc eu sollicitudin lorem. Fusce lorem ante, laoreet accumsan velit vitae, gravida ultrices orci. Nunc ut faucibus ligula. Donec viverra facilisis mi, quis euismod turpis sagittis non. Nam vel pulvinar felis, nec mollis turpis. Nam convallis tincidunt ligula, eget viverra ipsum ultricies in. Fusce arcu nulla, aliquam ac fringilla id, laoreet quis eros. Aliquam eget nulla purus. Proin quis massa sagittis, egestas dui in, congue risus. Nulla ut mollis eros, a malesuada dolor. Nunc vel hendrerit tellus, at cursus magna. Maecenas tempor risus ac enim hendrerit sagittis. Ut sit amet facilisis metus. Etiam ultricies mi vel est pellentesque placerat. Maecenas sit amet lorem vitae tellus volutpat pharetra sit amet id diam. Nunc varius pretium libero vel hendrerit. Curabitur posuere leo sed nulla tincidunt imperdiet. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Maecenas quis ex turpis. Praesent semper, turpis non eleifend consectetur, diam elit fringilla odio, malesuada rutrum quam ligula sed tellus. Donec arcu augue, mollis at ex ut, accumsan bibendum risus. Sed dignissim odio at urna posuere, eu pretium massa vehicula. Maecenas tempus egestas augue. Proin a lacus tellus. Etiam vel cursus justo. Fusce vel auctor turpis. Etiam rutrum at sem nec vulputate. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Vivamus vestibulum risus nec est sodales vulputate. Vestibulum sagittis risus quis mattis dapibus. Aenean vestibulum, massa nec maximus ornare, sapien est vestibulum tellus, sit amet vulputate eros nibh eget mauris. Aenean a accumsan elit. In hac habitasse platea dictumst. Integer vel purus velit. Mauris tincidunt, nisi volutpat pulvinar volutpat, neque erat egestas odio, sed lobortis lorem mi eget odio. Pellentesque ac mi id sem efficitur aliquam. Fusce ut iaculis mauris, vitae efficitur diam. Pellentesque at luctus tellus, eget pharetra ex. Pellentesque ultrices tellus mauris, finibus tincidunt augue cursus eu. Vivamus sed ligula vel nunc euismod mattis in sed sem. Donec id luctus elit. Integer pulvinar rhoncus arcu ut sodales. Nullam malesuada nulla nec libero ultricies, in placerat sem faucibus. Praesent risus ex, lacinia sed ultrices id, aliquam non ex. Vivamus sit amet leo id erat lobortis eleifend et ac mauris. In pretium vulputate neque, a tincidunt mi interdum sed. Nunc efficitur ipsum in ante vulputate, a molestie dolor accumsan. Sed mattis, augue quis condimentum feugiat, tortor est gravida dolor, finibus placerat nisi turpis a erat. Fusce vel elit ac orci varius facilisis eu bibendum justo. Praesent facilisis ex porta quam pellentesque, nec pellentesque purus mattis. Duis eget metus efficitur, fringilla turpis eu, vehicula nisl. Quisque vel feugiat tortor, quis sodales lacus. Maecenas dapibus luctus velit, in vehicula sem semper eget. Curabitur lacinia posuere ex id auctor. Mauris et dictum urna, ac vulputate enim. In non libero vitae eros rhoncus pretium sed nec sapien. Suspendisse aliquet finibus tellus non sagittis. Pellentesque maximus mollis nibh, ut porta sapien vestibulum et. Phasellus a ipsum luctus, porttitor justo vitae, aliquet mi. Vivamus a pharetra erat. Mauris convallis neque eget lectus imperdiet, nec varius felis semper. Curabitur volutpat, magna sed vestibulum cursus, eros felis pharetra quam, ac tristique sapien nulla a tellus. Aliquam nulla turpis, tempus at risus at, sagittis vehicula purus. Sed vehicula justo lacus, non consequat tellus suscipit eu. Phasellus vitae risus posuere leo dapibus sagittis. In sed augue nec tellus pellentesque pharetra. Donec faucibus neque ut est feugiat, non laoreet felis venenatis. Phasellus eget commodo nunc. Vivamus vulputate nunc ac justo suscipit, vitae congue leo tristique. Vivamus ultricies commodo interdum. Integer et tellus ut ante tincidunt dignissim ut vel elit. Fusce sodales id nunc vel rhoncus. Cras suscipit metus quam, id dignissim justo interdum non. Sed diam lacus, eleifend ut malesuada sit amet, fringilla vitae sapien. Aenean sed massa sit amet diam varius sollicitudin id in justo. Ut sem purus, tincidunt varius urna eget, convallis viverra lacus. Mauris fringilla est eu vestibulum tempor. Morbi dapibus lorem et consectetur finibus. Donec accumsan id ante in laoreet. Aliquam semper, quam vel sollicitudin posuere, erat sem eleifend turpis, sed molestie lectus ligula in dolor. Donec vulputate velit id ultrices auctor. Donec vel nisl feugiat, tristique libero eget, egestas lectus. Quisque condimentum nunc ipsum, at pellentesque erat lobortis et. Aliquam in metus elit. Praesent eget lacinia turpis, at aliquet lorem. Maecenas ultricies vehicula est ut sagittis. Nulla nunc justo, laoreet imperdiet maximus ut, vehicula vitae nibh. Aliquam vitae libero et lorem maximus sagittis. Nam id lacinia leo. Donec id ligula enim. Maecenas at lorem ac eros tristique pulvinar. Integer fermentum risus in gravida tincidunt. Praesent aliquam commodo fringilla. Etiam tempus vel purus ac interdum. In condimentum quam ac malesuada rhoncus. Quisque in mi vel purus rhoncus volutpat. Nullam sed nisi bibendum eros pharetra lobortis. Mauris quis vulputate augue. In tincidunt erat metus, quis sagittis ipsum pulvinar sed. Duis efficitur consequat sem, nec semper sem convallis in. Cras elementum orci eget diam maximus, dignissim efficitur turpis auctor. Vivamus in pellentesque arcu. Nullam varius urna eget mauris sagittis vestibulum id eu lectus. Etiam molestie at ex a convallis. Mauris luctus magna tellus, non tristique velit mattis sit amet. Curabitur mollis mattis odio, at rhoncus augue sagittis eleifend. Duis id nunc nec turpis auctor eleifend ac sit amet mi. Curabitur ut enim nisl. Nam iaculis nunc ac est pellentesque accumsan. Sed luctus tortor non elit ultrices lacinia. Nulla id sollicitudin justo. Maecenas sem libero, fringilla ut lacus a, semper sagittis ex. Vivamus porta euismod malesuada. Pellentesque luctus sit amet ante eu varius. Duis nec ultricies est, in molestie ligula. Aenean nisi augue, mollis et sapien ultrices, vehicula porttitor est. Nullam arcu ligula, blandit eget ligula quis, feugiat tincidunt mi. Ut nec orci eleifend, eleifend eros eu, pretium neque. Cras porttitor pulvinar tempus. Nullam tempus ipsum at ultricies sodales. Aliquam at dui nunc. Pellentesque ligula ex, tempor nec arcu sed, scelerisque laoreet urna. Fusce cursus elementum justo, ac mollis turpis malesuada id. Nulla maximus ipsum ac lacus accumsan varius. Nam a elit vel purus iaculis pulvinar id quis nisl. Morbi ornare, lectus non placerat suscipit, ante erat malesuada neque, vel sollicitudin urna diam in nulla. Morbi ut nunc maximus, mattis velit vitae, fermentum magna. Vivamus lobortis tellus nec tortor iaculis, nec finibus diam ornare. Sed eget facilisis dolor, non vehicula ligula. Aenean volutpat nulla arcu, ut aliquam urna vestibulum vitae. Vestibulum quis dolor at lectus fermentum aliquet a non sapien. Vivamus porta elit quis nisl efficitur, in molestie ex laoreet. Pellentesque pretium velit eget eros posuere, et mattis ante accumsan. Aenean volutpat lectus dapibus, dictum ligula eget, sodales nunc. Donec at magna sem. Proin iaculis mi sed commodo aliquam. Nam maximus vestibulum urna at aliquet. Aenean in gravida lorem. Vestibulum fermentum bibendum mi, ut pellentesque tellus. Phasellus mollis id lectus quis iaculis. Vestibulum magna risus, congue et gravida in, placerat eu nulla. Fusce consequat non nunc sed pretium. Ut iaculis rhoncus justo, nec luctus risus. Nulla eget consequat nulla. Curabitur viverra mauris libero, sed malesuada ex mattis nec. Quisque feugiat ipsum eros, gravida finibus tortor venenatis at. Mauris et lectus mauris. Mauris nec arcu a enim lacinia imperdiet. Donec et dui at odio ultrices sollicitudin. Nunc nec mauris ligula. Nulla vel quam magna. Pellentesque volutpat scelerisque libero, id bibendum mauris sollicitudin at. Nunc quis arcu ac nisi blandit vestibulum sit amet non lacus. Maecenas varius risus sit amet tristique ultricies. Integer vestibulum sem lorem, a aliquam leo fermentum et. Praesent nec nunc sodales orci tristique tempus. Vestibulum volutpat quam quis libero sagittis, sit amet interdum lacus tincidunt. Donec dui augue, ullamcorper ut mattis euismod, euismod a leo. Aliquam eu lacinia eros, accumsan ullamcorper neque. Fusce fermentum mi eu lorem commodo suscipit. Nulla metus nibh, tristique quis lacinia ut, accumsan eget leo. Quisque velit tellus, tempor at blandit sit amet, egestas quis risus. Maecenas aliquet tincidunt pretium. In sit amet aliquam ante. Etiam feugiat laoreet accumsan. In posuere sollicitudin tortor et tristique. Vestibulum ac hendrerit turpis. In sit amet mollis massa. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Vestibulum porttitor velit sed justo pellentesque eleifend. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Nam porta elit sit amet dolor placerat ullamcorper. Nam vehicula pulvinar dui, ac euismod justo accumsan quis. Curabitur bibendum purus id felis tincidunt, egestas vehicula dolor varius. Mauris iaculis auctor magna, eu egestas augue auctor quis. Duis faucibus ex mattis, ornare erat tempor, egestas ante. Curabitur iaculis vestibulum nisl, a interdum odio porttitor eget. Phasellus nulla turpis, condimentum ut arcu eu, efficitur mollis augue. Duis eget nisl lacus. Integer odio urna, ornare et porta eu, ornare eget ligula. Vestibulum feugiat, nibh ultrices dictum pulvinar, nisi massa imperdiet ipsum, at dignissim nibh purus vel nulla. Aliquam blandit, magna eget porta fermentum, nibh lacus ultricies arcu, luctus rhoncus massa lacus id mi. Mauris felis nulla, posuere non dolor quis, pharetra ornare diam. Nullam tempus dui quis tortor rutrum tincidunt. Vestibulum tempor in lectus vitae pretium. Nulla facilisi. Morbi sed sem viverra, venenatis augue sit amet, feugiat urna. Sed id lacus posuere, ultricies sem eu, blandit massa. Vestibulum semper congue pretium. Nulla vel purus non sapien imperdiet vulputate at at ipsum. Proin nec diam at eros faucibus euismod. Praesent aliquet faucibus posuere. Donec eu lectus et nulla facilisis ullamcorper id eu diam. Donec sit amet lacinia tellus, et egestas sapien. Suspendisse consectetur turpis in mi congue, semper semper ligula pretium. Nulla ultricies arcu ac tristique lacinia. Phasellus ac ex pretium, imperdiet metus sit amet, tempor ipsum. Suspendisse ac placerat tellus. In sit amet neque at elit venenatis lacinia id sed orci. Cras augue quam, rhoncus sed luctus sed, euismod sed nibh. Pellentesque ac ligula eget odio fermentum semper. Proin tempor est rutrum, egestas mauris in, venenatis diam. Nullam ultricies nec quam nec auctor. Nulla nec sapien imperdiet, gravida purus sit amet, ultrices leo. Maecenas in finibus leo. Sed pulvinar lacus eu leo vehicula ultrices. Nam in diam in mi aliquet sagittis. Nulla eget ante et magna placerat convallis. Curabitur quam velit, tempor eu velit eu, pharetra rhoncus odio. Nunc molestie odio nec imperdiet elementum. Donec eget molestie mauris. Vestibulum mauris diam, tristique varius vestibulum vel, pellentesque id sapien. Nulla facilisi. Morbi eget ipsum quis eros vulputate aliquet et vel lorem. Vivamus lacinia quam in lacus lacinia pellentesque. Curabitur pulvinar vel neque id condimentum. Cras mattis ex leo, id semper leo ultricies vitae. Quisque nec diam condimentum, congue urna at, commodo magna. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nam ac metus tortor. Donec nisl elit, placerat eget elementum a, rutrum sed ante. Aliquam vehicula congue fringilla. Nam ut nunc quis risus rhoncus viverra. Nam enim dolor, luctus finibus vehicula non, tristique id dui. Donec vitae molestie lorem, eget aliquet sem. Aenean sodales, ipsum ac tincidunt ultrices, nisl est posuere mauris, sollicitudin gravida magna lacus vel orci. Nam laoreet velit consectetur libero suscipit pharetra. Etiam scelerisque pharetra tortor vitae finibus. Donec molestie felis rhoncus enim consequat, vitae eleifend odio mattis. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Nullam auctor quam ac lectus congue pretium. Suspendisse sollicitudin a mi egestas cursus. Duis sit amet elit metus. Proin magna felis, ornare non neque a, maximus vulputate purus. Integer ornare eros erat, vel tempor enim pharetra in. Sed eu orci sed mi cursus dictum. In mattis pretium est scelerisque elementum. In hac habitasse platea dictumst. Nam efficitur ultricies ex. Cras interdum in ligula ac sagittis. Fusce posuere vel lectus id congue. Phasellus augue libero, dignissim at nisi quis, fringilla efficitur tortor. Curabitur rutrum arcu in quam malesuada faucibus vitae id ex. Sed pellentesque tellus ut risus interdum, sit amet congue nulla blandit. Ut lectus mauris, sollicitudin non metus eu, congue iaculis ante. Integer porttitor suscipit leo, ut congue neque laoreet vel. Quisque vel auctor dui, eget tincidunt elit. Quisque sed fringilla libero. Curabitur mauris metus, aliquet at orci sit amet, iaculis venenatis magna. In in diam sed est commodo porttitor non vel orci. Morbi bibendum, magna id volutpat vehicula, urna dui imperdiet nulla, et auctor turpis risus in ipsum. Sed laoreet ipsum ipsum, id dapibus quam semper et. Phasellus quis porttitor massa. Cras fermentum nulla lorem, eu convallis nisi luctus in. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Vestibulum justo purus, finibus sit amet luctus et, tincidunt ac sem. Donec eget tellus sed mi eleifend commodo ac sed diam. Nam ullamcorper nisi vestibulum magna ullamcorper, sit amet semper sapien dapibus. Mauris ultrices nisl in nibh iaculis accumsan. Fusce elementum lectus vitae ante auctor sodales vel eget sem. Vestibulum eleifend nec magna et consequat. Mauris efficitur diam eget ornare fermentum. Proin pulvinar vestibulum dui, euismod gravida ipsum ultrices a. Cras pharetra consectetur venenatis. Maecenas malesuada risus non laoreet vehicula. Cras vulputate mauris vitae ipsum placerat tempus. Suspendisse nec maximus mauris. Nulla dolor arcu, molestie et ornare eu, maximus ac nibh. Integer nec eleifend nulla. Nulla tristique finibus tortor, vel feugiat augue iaculis ut. Nunc at orci leo. Pellentesque sed pellentesque turpis, id dignissim augue. Etiam eu elit lorem. Fusce pellentesque nisl lacinia malesuada fermentum. Cras pellentesque mattis nunc eu faucibus. Fusce et mauris quis urna pharetra fringilla. Aliquam blandit blandit blandit. Etiam dui quam, laoreet vel commodo quis, sodales eu risus. Fusce a augue ut nisl vehicula rutrum non non odio. Sed condimentum dui arcu, eget rutrum massa vestibulum sit amet. Sed aliquam rhoncus consectetur. Donec ut gravida erat, in tincidunt nibh. Nulla convallis nisi sit amet lacus finibus bibendum. Donec pharetra nisl ligula, non sollicitudin neque dapibus et. Vivamus auctor tempor nisl. Curabitur accumsan nec arcu vitae ullamcorper. Morbi tempor sapien at posuere faucibus.]]
	
	tt = tt + 1
	if tt > 700 then
		tt = 0
	end
	
	-- Parse and Resolve the formatting
	local formattedText = tplusParse.parseAndFormat(testString, {font=textplusFont.font4, xscale=1, yscale=1, align="center"})
	
	local textLayout = textplusLayout.runLayout(formattedText, 800-tt)
	
	textplusRender.renderLayout(5, 5, textLayout, true)
	
	Graphics.drawBox{x=0, y=0, w=800-0, h=600-0, color={0,0,0,0.7}, priority=0}
end



---------------
-- RETURN -----
---------------

return tplusParse;