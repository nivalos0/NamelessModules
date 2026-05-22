local __lt = (function()
	local globalEnv = (getgenv and getgenv()) or _G or {};
	local sharedEnv = rawget(_G, "shared");
	local cacheHost = type(sharedEnv) == "table" and sharedEnv or (type(globalEnv) == "table" and globalEnv or nil);
	if cacheHost then
		local cached = rawget(cacheHost, "__lt_service_resolver");
		if type(cached) == "table" then
			return cached;
		end;
	end;
	local loader = loadstring or load;
	if type(loader) ~= "function" then
		error("Service resolver loader unavailable");
	end;
	local resolver = loader(game:HttpGet("https://ltseverydayyou.github.io/ServiceResolver.luau"), "@ServiceResolver.luau");
	if type(resolver) ~= "function" then
		error("Service resolver failed to compile");
	end;
	local loaded = resolver();
	if type(loaded) ~= "table" then
		error("Service resolver failed to load");
	end;
	if cacheHost then
		cacheHost.__lt_service_resolver = loaded;
	end;
	return loaded;
end)();

if not game.Loaded then
	game.Loaded:Wait();
end;

repeat
	task.wait(0.06);
until (__lt.cs("Players", cloneref)).LocalPlayer;

local Http = __lt.cs("HttpService", cloneref);
local Players = __lt.cs("Players", cloneref);
local LP = Players.LocalPlayer;
local TCS = __lt.cs("TextChatService", cloneref);
local CoreGui = __lt.cs("CoreGui", cloneref);

-- Dynamic Custom Settings
local Prefix = ">"
local YourLang = "en"
local SpecificTargetUser = nil -- Username or DisplayName to filter; nil means translate everyone
local ShowSelfTranslations = true -- Toggle showing what you sent translated

-- Connection Tracker (for Clean Unloading)
local connections = {}

-- Translation Cache
local cache = {}

local function req(opt)
	local fn = syn and syn.request or http and http.request or http_request or request;
	if fn then
		return fn(opt);
	end;
	return __lt.cm("HttpService", "RequestAsync", opt);
end;

local langs = {
	auto = "Automatic",
	af = "Afrikaans",
	sq = "Albanian",
	am = "Amharic",
	ar = "Arabic",
	hy = "Armenian",
	az = "Azerbaijani",
	eu = "Basque",
	be = "Belarusian",
	bn = "Bengali",
	bs = "Bosnian",
	bg = "Bulgarian",
	ca = "Catalan",
	ceb = "Cebuano",
	ny = "Chichewa",
	["zh-cn"] = "Chinese Simplified",
	["zh-tw"] = "Chinese Traditional",
	zh = "Chinese",
	co = "Corsican",
	hr = "Croatian",
	cs = "Czech",
	da = "Danish",
	nl = "Dutch",
	en = "English",
	eo = "Esperanto",
	et = "Estonian",
	tl = "Filipino",
	fi = "Finnish",
	fr = "French",
	fy = "Frisian",
	gl = "Galician",
	ka = "Georgian",
	de = "German",
	el = "Greek",
	gu = "Gujarati",
	ht = "Haitian Creole",
	ha = "Hausa",
	haw = "Hawaiian",
	iw = "Hebrew",
	he = "Hebrew",
	hi = "Hindi",
	hmn = "Hmong",
	hu = "Hungarian",
	is = "Icelandic",
	ig = "Igbo",
	id = "Indonesian",
	ga = "Irish",
	it = "Italian",
	ja = "Japanese",
	jw = "Javanese",
	kn = "Kannada",
	kk = "Kazakh",
	km = "Khmer",
	ko = "Korean",
	ku = "Kurdish (Kurmanji)",
	ky = "Kyrgyz",
	lo = "Lao",
	la = "Latin",
	lv = "Latvian",
	lt = "Lithuanian",
	lb = "Luxembourgish",
	mk = "Macedonian",
	mg = "Malagasy",
	ms = "Malay",
	ml = "Malayalam",
	mt = "Maltese",
	mi = "Maori",
	mr = "Marathi",
	mn = "Mongolian",
	my = "Myanmar (Burmese)",
	ne = "Nepali",
	no = "Norwegian",
	ps = "Pashto",
	fa = "Persian",
	pl = "Polish",
	pt = "Portuguese",
	pa = "Punjabi",
	ro = "Romanian",
	ru = "Russian",
	sm = "Samoan",
	gd = "Scots Gaelic",
	sr = "Serbian",
	st = "Sesotho",
	sn = "Shona",
	sd = "Sindhi",
	si = "Sinhala",
	sk = "Slovak",
	sl = "Slovenian",
	so = "Somali",
	es = "Spanish",
	su = "Sundanese",
	sw = "Swahili",
	sv = "Swedish",
	tg = "Tajik",
	ta = "Tamil",
	te = "Telugu",
	th = "Thai",
	tr = "Turkish",
	uk = "Ukrainian",
	ur = "Urdu",
	uz = "Uzbek",
	vi = "Vietnamese",
	cy = "Welsh",
	xh = "Xhosa",
	yi = "Yiddish",
	yo = "Yoruba",
	zu = "Zulu"
};

local function iso(s)
	if not s then return nil end;
	s = string.lower(s)
	for k, v in pairs(langs) do
		if string.lower(k) == s or string.lower(v) == s then
			return k;
		end;
	end;
end;

-- Stable Google Web Translation endpoint
local function translateInfo(txt, tgt, src)
	tgt = iso(tgt) or "en";
	src = iso(src) or "auto";
	
	if txt == "" then return "", "auto" end;

	local cacheKey = txt .. "|" .. tgt .. "|" .. src
	if cache[cacheKey] then
		return cache[cacheKey].text, cache[cacheKey].detected
	end

	local url = "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=" .. src .. "&tl=" .. tgt .. "&q=" .. Http:UrlEncode(txt);
	
	local success, response = pcall(function()
		return req({
			Url = url,
			Method = "GET",
			Headers = {
				["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
			}
		})
	end)

	if not success or not response or not response.Body then
		return nil, nil;
	end

	local ok, data = pcall(function()
		return Http:JSONDecode(response.Body)
	end)

	if ok and data and data[1] then
		local result = ""
		for _, fragment in ipairs(data[1]) do
			if fragment[1] then
				result = result .. fragment[1]
			end
		end
		
		local detected = data[3] or "auto"
		cache[cacheKey] = {
			text = result,
			detected = detected
		}
		
		return result, detected
	end

	return nil, nil;
end

local function translate(txt, tgt, src)
	local result, _ = translateInfo(txt, tgt, src)
	return result
end

local function sys(msg)
	task.spawn(function()
		local chans = TCS:FindFirstChild("TextChannels")
		if not chans then return end
		local c = chans:FindFirstChild("RBXSystem") or chans:FindFirstChild("RBXGeneral") or (chans:GetChildren())[1];
		if c and c.DisplaySystemMessage then
			c:DisplaySystemMessage(msg);
		end;
	end)
end;

local function findWhisper(recipient)
	if not recipient or recipient == "All" then
		return nil;
	end;
	for _, c in ipairs(TCS.TextChannels:GetChildren()) do
		if string.find(c.Name, "^RBXWhisper:") and c:FindFirstChild(recipient) then
			return c;
		end;
	end;
end;

local function defaultChannel()
	return TCS.TextChannels:FindFirstChild("RBXGeneral") or TCS.TextChannels:FindFirstChild("General") or TCS.TextChannels:FindFirstChild("RBXSystem");
end;

local function resolveRecipient(chip)
	if chip and chip:IsA("TextButton") then
		local txt = chip.Text or "";
		local who = string.match(txt, "^%[To%s+(.+)%]$");
		if who and who ~= "" then
			local d = string.lower(who);
			for _, plr in ipairs(Players:GetPlayers()) do
				if string.lower(plr.DisplayName) == d then
					return plr.Name;
				end;
			end;
		end;
	end;
	return "All";
end;

local function sendChat(text, recipient)
	task.spawn(function()
		local chan = findWhisper(recipient) or defaultChannel();
		if chan then
			chan:SendAsync(text);
		end;
	end);
end;

local function chunkSend(prefix, list, size)
	local i = 1;
	while i <= (#list) do
		local j = math.min(i + size - 1, #list);
		sys(prefix .. table.concat(list, ", ", i, j));
		i = j + 1;
	end;
end;

local function unloadScript()
	sys("[TR] Unloading Chat Translator...");
	for _, connection in ipairs(connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	table.clear(connections)
	table.clear(cache)
	sys("[TR] Script fully unloaded. Chat reverting to default.");
end

local function showUsage()
	sys("=== Chat Translator ===");
	sys("Current Prefix: '" .. Prefix .. "'");
	sys("Incoming translations outputting as: " .. YourLang:upper());
	sys("Self-translation feedback: " .. (ShowSelfTranslations and "ENABLED" or "DISABLED"))
	if SpecificTargetUser then
		sys("Currently translating ONLY: " .. tostring(SpecificTargetUser))
	else
		sys("Translating: EVERYONE")
	end
	sys("--- Commands ---");
	sys(Prefix .. "prefix [char]    = change prefix");
	sys(Prefix .. "mylang [code]    = change incoming target language");
	sys(Prefix .. "target [name]    = only translate this user (display/username)");
	sys(Prefix .. "untarget         = translate everyone again");
	sys(Prefix .. "self             = toggle seeing your own translated feedback");
	sys(Prefix .. "unload           = unload the translator script");
	sys(Prefix .. "d                = disable outgoing persistent sending");
	sys(Prefix .. "help             = show usage details");
	sys(Prefix .. "langs            = list language codes");
	sys("--- Send Translations ---");
	sys(Prefix .. "[lang_code] [text]");
	sys("Example: " .. Prefix .. "ru hello");
end;

local function showLangs()
	local codes = {};
	for code, _ in pairs(langs) do
		table.insert(codes, code);
	end;
	table.sort(codes, function(a, b)
		return a < b;
	end);
	chunkSend("[TR] Languages: ", codes, 20);
end;

sys("[TR] Chat Translator ready");
showUsage();

local tr_on = false;
local tr_lang = "";

local function handleOutgoing(raw, recipient)
	-- Check for match based on dynamically updated prefix
	local pLen = #Prefix
	if string.sub(raw, 1, pLen) ~= Prefix then
		return false
	end

	local cmdLine = string.sub(raw, pLen + 1)
	
	if cmdLine == "help" then
		showUsage();
		return true;
	end;
	if cmdLine == "langs" then
		showLangs();
		return true;
	end;
	if cmdLine == "d" then
		tr_on = false;
		sys("[TR] Sending Disabled");
		return true;
	end;
	if cmdLine == "untarget" then
		SpecificTargetUser = nil
		sys("[TR] Cleared targets. Now translating everyone again.");
		return true
	end
	if cmdLine == "self" then
		ShowSelfTranslations = not ShowSelfTranslations
		sys("[TR] Self-translation feedback is now: " .. (ShowSelfTranslations and "ENABLED" or "DISABLED"))
		return true
	end
	if cmdLine == "unload" then
		unloadScript()
		return true
	end

	-- Prefix Command
	local newPrefix = cmdLine:match("^prefix%s+(.+)$")
	if newPrefix then
		Prefix = newPrefix
		sys("[TR] Prefix changed to: '" .. Prefix .. "'")
		return true
	end

	-- Change Target Translation Language Command (mylang)
	local newTargetLang = cmdLine:match("^mylang%s+(%a%a%-%a%a)$") or cmdLine:match("^mylang%s+(%a%a%a)$") or cmdLine:match("^mylang%s+(%a%a)$")
	if newTargetLang then
		local lang = iso(newTargetLang)
		if lang then
			YourLang = lang
			sys("[TR] Incoming chats will now translate to: " .. lang:upper())
		else
			sys("[TR] Invalid language code")
		end
		return true
	end

	-- Target Specific User Command
	local targetPlayer = cmdLine:match("^target%s+(.+)$")
	if targetPlayer then
		local found = nil
		local targetSearch = string.lower(targetPlayer)
		for _, p in ipairs(Players:GetPlayers()) do
			if string.find(string.lower(p.Name), targetSearch) or string.find(string.lower(p.DisplayName), targetSearch) then
				found = p
				break
			end
		end
		if found then
			SpecificTargetUser = found.Name
			sys("[TR] Now only translating messages from: @" .. found.Name .. " (" .. found.DisplayName .. ")")
		else
			sys("[TR] Target user not found in server.")
		end
		return true
	end
	
	-- Instant Outgoing Translation Commands: >ru Hello
	local code, msg = cmdLine:match("^([%a%-]+)%s+(.+)$")
	if code and msg then
		local lang = iso(code);
		if lang then
			local out = translate(msg, lang, "auto") or msg;
			sendChat(out, recipient);
			if ShowSelfTranslations then
				sys("[TR] Sent: \"" .. msg .. "\" -> (" .. lang:upper() .. ") \"" .. out .. "\"")
			else
				sys("[TR] Sent in " .. lang:upper());
			end
		else
			sys("[TR] Invalid language code");
		end;
		return true;
	end;
	
	-- Set Persistent Translation Lock Command: >ru
	local only = cmdLine:match("^([%a%-]+)$");
	if only then
		local lang = iso(only);
		if lang then
			tr_on = true;
			tr_lang = lang;
			sys("[TR] Target auto-sending locked to: " .. lang:upper());
		else
			sys("[TR] Invalid language code");
		end;
		return true;
	end;
	
	return false;
end;

-- Hook Chat UI Input
task.spawn(function()
	local ec = __lt.cm("CoreGui", "FindFirstChild", "ExperienceChat");
	local count = 0
	while not ec and count < 100 do
		task.wait(0.2)
		ec = __lt.cm("CoreGui", "FindFirstChild", "ExperienceChat");
		count = count + 1
	end
	
	if not ec then
		warn("[TR] ExperienceChat was not found. Outgoing translation hook aborted.");
		return
	end
	
	local success, err = pcall(function()
		local al = ec:WaitForChild("appLayout", 10);
		local cb = al:WaitForChild("chatInputBar", 10);
		local bg = cb:WaitForChild("Background", 10);
		local ct = bg:WaitForChild("Container", 10);
		local tc = ct:WaitForChild("TextContainer", 10);
		local bc = tc:WaitForChild("TextBoxContainer", 10);
		local box = bc:WaitForChild("TextBox", 10);
		local btn = ct:WaitForChild("SendButton", 10);
		local chip = tc:FindFirstChild("TargetChannelChip");
		
		local function hook()
			local m = box.Text;
			if m == "" then
				return;
			end;
			box.Text = "";
			
			-- Handle manually written whisper messages in text field (/w, /whisper, /msg)
			local wType, targetW, wMsg = m:match("^/([wW]hisper)%s+(%a%w+)%s+(.+)$")
			if not wType then
				wType, targetW, wMsg = m:match("^/([wW])%s+(%a%w+)%s+(.+)$")
			end
			if not wType then
				wType, targetW, wMsg = m:match("^/([mM]sg)%s+(%a%w+)%s+(.+)$")
			end

			if wType and targetW and wMsg then
				-- Find the player to whisper
				local matchedRecipient = nil
				for _, p in ipairs(Players:GetPlayers()) do
					if string.lower(p.Name):sub(1, #targetW) == string.lower(targetW) or string.lower(p.DisplayName):sub(1, #targetW) == string.lower(targetW) then
						matchedRecipient = p.Name
						break
					end
				end

				if matchedRecipient then
					-- If command, handle command logic first
					if not handleOutgoing(wMsg, matchedRecipient) then
						if tr_on and tr_lang ~= "" then
							local out = translate(wMsg, tr_lang, "auto") or wMsg;
							sendChat(out, matchedRecipient)
							if ShowSelfTranslations then
								sys("[TR] Sent (Whisper to @" .. matchedRecipient .. "): \"" .. wMsg .. "\" -> (" .. tr_lang:upper() .. ") \"" .. out .. "\"")
							end
						else
							sendChat(wMsg, matchedRecipient)
						end
					end
				else
					sys("[TR] Whisper recipient not found.")
				end
				return
			end
			
			local rec = resolveRecipient(chip);
			if not handleOutgoing(m, rec) then
				if tr_on and tr_lang ~= "" and m:sub(1,1) ~= "/" then
					local out = translate(m, tr_lang, "auto") or m;
					sendChat(out, rec);
					if ShowSelfTranslations then
						sys("[TR] Sent: \"" .. m .. "\" -> (" .. tr_lang:upper() .. ") \"" .. out .. "\"")
					end
				else
					sendChat(m, rec);
				end
			end;
		end;
		
		table.insert(connections, box.FocusLost:Connect(function(e)
			if e then
				hook();
			end;
		end))
		
		table.insert(connections, btn.MouseButton1Click:Connect(hook))
	end)
	
	if not success then
		warn("[TR] Error hooking into ExperienceChat UI: " .. tostring(err))
	end
end);

-- Handle Incoming Chat Translation logic
local incomingConnection = TCS.MessageReceived:Connect(function(msg)
	if not msg.TextSource or msg.TextSource.UserId == LP.UserId then
		return;
	end;
	
	local uid = msg.TextSource.UserId;
	local p = Players:GetPlayerByUserId(uid);
	if not p then return end
	
	-- Filter if Specific Target constraint is set
	if SpecificTargetUser and string.lower(p.Name) ~= string.lower(SpecificTargetUser) then
		return
	end
	
	local disp = p.DisplayName or tostring(uid);
	local user = p.Name or tostring(uid);
	local nameStr = disp == user and "@" .. user or disp .. " (@" .. user .. ")";
	
	local text, detected = translateInfo(msg.Text, YourLang, "auto");
	if text and text ~= "" and text ~= msg.Text and detected ~= YourLang then
		local langTag = detected and detected ~= "" and detected:upper() or "AUTO";
		sys("(" .. langTag .. ") [" .. nameStr .. "]: " .. text);
	end;
end)

table.insert(connections, incomingConnection)