local addNewActor = dofile(ResolveRelativePath("new_Actor/NewActor.lua", 1));
local deleteActor = dofile(ResolveRelativePath("new_Actor/DeleteActor.lua", 1));

local pi = math.pi;
local exp = math.exp;
local log = math.log;
local abs = math.abs;
local max = math.max;
local min = math.min;
local cos = math.cos;
local sin = math.sin;
local clockS = GetTimeSinceStart;

local VERBOSE_MODE_ENABLED = false;
local EXPONENTIAL_SMOOTHING_UNIT = 1-exp(-1);
local DEFAULT_TIME_CONSTANT = 0.096;
local DEFAULT_APPROACH_RATE = 1/(DEFAULT_TIME_CONSTANT);
local DEFAULT_SNAP_THRESHOLD = 1/64;
local LANE_DESTRUCTION_DELAY = -log(1/256) * DEFAULT_TIME_CONSTANT;
local MOUSE_BUTTOMS = {"left mouse button", "middle mouse button", "right mouse button", 
                       "left ctrl", "left shift", "left alt"};


local topScreen;
local mainActorFrame;
local verboseText;

local lastUpdateTime = 0;
local updateTime = clockS();
local deltaTime = 1/60;


local baseBottomY = 100;
local baseTopY = 150;
local baseZ = 120;
local baseFOV = 90;
local baseZoomY = 1.36;


--[[    for reference only    --
local function minmax(curV, minV, maxV)
	return min(max(curV, minV), maxV);
end
]]

local function expSmoothApproach(current, goal, factor, snapThreshold, unitTimeAmount, useSmoothFactor)
	if type(current) ~= "number" or type(goal) ~= "number" then
		return current, false;
	end

	local factor = factor or ((useSmoothFactor == true)
	                          and (1 - 0.00003^deltaTime)
	                          or DEFAULT_TIME_CONSTANT);
	local unitTimeAmount = unitTimeAmount or EXPONENTIAL_SMOOTHING_UNIT;
	local snapThreshold = snapThreshold or DEFAULT_SNAP_THRESHOLD;
	local smoothingFactor =	(useSmoothFactor == true)
	                        and factor
	                        or (1 - exp(log(1-unitTimeAmount) * deltaTime / factor));

	local delta = smoothingFactor * (goal - current);
	local isChanged = abs(delta) > snapThreshold;
	return isChanged and (current + delta) or goal, isChanged;
end
local function multiExpSmoothApproach(Table)
	local ret = {};
	local isChanged = false;
	for i, args in ipairs(Table) do
		local isItemChanged = false;
		ret[i], isItemChanged = expSmoothApproach(unpack(args));
		if isItemChanged then isChanged = true; end
	end
	return ret, isChanged;
end


local function setHorizontalLaneForPn(actorFrame, pn, isConstant)
	local actor;

	local name = "HorizontalLaneP"..(pn+1)..(isConstant and "_Const" or "");
	local baseBottomY = baseBottomY;
	local baseTopY = baseTopY;
	local reverseFactor = 1;

	local baseX, baseY = 0, 0;
	local ox, oy, oz = 0, 0, 0;
	local x, y, z = 0, 0, 0;
	local nx, ny, nz = 0, 0, 0;
	local pitch, npitch = 0, 0;
	local bottomX, bottomY = 0, 0;
	local nbottomX, nbottomY = 0, 0;
	local topX, topY = 0, -baseTopY;
	local ntopX, ntopY = 0, 0;
	local fov, nfov = -1 - baseFOV, 0;
	local zoomY, nzoomY = 1-baseZoomY, 0;
	local oNoteColumnH = {};
	local oTilt, oSkew, oMini = 0, 0, 0;

	local pl;
	local nf;
	local nfc;
	local modS;

	local mousePressed = {false, false, false, false, false, false};
	local mouseReset = {false, false, false, false, false, false};
	local enabled = true;
	local isChanged=false;


	local function transX(x, y) return x * cos(pitch) + y * -sin(pitch); end
	local function transY(x, y) return x * sin(pitch) + y *  cos(pitch); end


	local function isMousePressed(index)
		local iw = (index-1)%3+1;
		return mousePressed[iw] or mousePressed[iw+3];
	end
	local function isMouseReset(index)
		local iw = (index-1)%3+1;
		return mouseReset[iw] or mouseReset[iw+3];
	end

	local function handleMouseButton(event)
		if enabled then
			for i, v in ipairs(MOUSE_BUTTOMS) do
				if event.DeviceInput.button == "DeviceButton_"..v and event.type ~= "InputEventType_Repeat" then
					mousePressed = {false, false, false, false, false, false};
					mouseReset[i] = event.type == "InputEventType_FirstPress";
					mousePressed[i] = mouseReset[i];
				end
			end

			if isMouseReset(1) and isMouseReset(3) then
				mousePressed = {false, false, false, false, false, false};

				nx, ny, nz = ox, oy, oz;
				npitch = 0;
				nbottomX, nbottomY = 0, 0;
				ntopX, ntopY = 0, 0;
				nfov = 0;
				nzoomY = 0;
				if not isConstant and isMouseReset(2) then
					deleteActor(actor);
				end
			else
				for i, v in ipairs{"up", "down"} do
					if event.DeviceInput.button == "DeviceButton_mousewheel "..v and event.type == "InputEventType_FirstPress" then
						if isMouseReset(1) and isMouseReset(2) then
							nfov = min(max(nfov + (i == 1 and 1 or -1), -1-baseFOV), 180-baseFOV);
						elseif isMousePressed(2) then
							nzoomY = nzoomY + (i == 1 and 1 or -1) * 0.04;
						elseif not isMousePressed(3) then
							nz = nz - (i == 1 and 1 or -1) * 10;
						end
					end
				end
			end
		end
		return false;
	end
	local function handleMousePosition()
		if not (isMouseReset(1) and isMouseReset(3)) then
			if isMouseReset(1) and isMouseReset(2) then
				nbottomX = INPUTFILTER:GetMouseX() - _screen.cx;
				nbottomY = INPUTFILTER:GetMouseY() - _screen.cy;
			elseif isMousePressed(1) then
				nx = INPUTFILTER:GetMouseX() - _screen.cx;
				ny = INPUTFILTER:GetMouseY() - _screen.cy;
			elseif isMousePressed(2) then
				npitch = reverseFactor * 2*pi * (-INPUTFILTER:GetMouseX()/_screen.w + (1 - INPUTFILTER:GetMouseY()/_screen.h));
			elseif isMousePressed(3) then
				ntopX = INPUTFILTER:GetMouseX() - _screen.cx;
				ntopY = INPUTFILTER:GetMouseY() - _screen.cy;
			end
		end
	end

	local function handleVariableUpdate()
		local result = {};
		result, isChanged = multiExpSmoothApproach{
		    {x, nx}, {y, ny}, {z, nz},
		    {pitch, npitch, 0.8 * DEFAULT_TIME_CONSTANT, pi/180 * DEFAULT_SNAP_THRESHOLD},
		    {bottomX, nbottomX}, {bottomY, nbottomY},
		    {topX, ntopX}, {topY, ntopY},
		    {fov, nfov, nil, 0.1 * DEFAULT_SNAP_THRESHOLD},
		    {zoomY, nzoomY, nil, 0.01 * DEFAULT_SNAP_THRESHOLD}
		};

		x, y, z,
		pitch,
		bottomX, bottomY,
		topX, topY,
		fov,
		zoomY =
		    unpack(result);
	end


	local function OnCommand(self)
		pl = topScreen:GetChild("PlayerP"..pn+1);
		nf = pl:GetChild("NoteField");
		nfc = nf:get_column_actors();
		modS = GAMESTATE:GetPlayerState(pn):GetPlayerOptions("ModsLevel_Song");

		reverseFactor = 1 - 2 * modS:Reverse();
		baseBottomY = reverseFactor * baseBottomY;
		baseTopY = reverseFactor * (baseTopY + baseY);

		baseX, baseY = pl:GetX(), pl:GetY();
		ox, oy, oz = nf:GetX(), nf:GetY(), nf:GetZ();
		x, y, z = ox, oy, oz - baseZ;

		oTilt = modS:Tilt(-3, DEFAULT_APPROACH_RATE);
		oSkew = modS:Skew(0, DEFAULT_APPROACH_RATE);
		oMini = modS:Mini(2/3 * (1 + modS:Mini()), DEFAULT_APPROACH_RATE);
		topX = oSkew*(_screen.cx - baseX);

		for i, Actor in ipairs(nfc) do
			oNoteColumnH[i] = Actor:GetHeight();
		end

		topScreen:AddInputCallback(handleMouseButton);
		self:playcommand("Update");
	end

	local function UpdateCommand(self)
		handleMousePosition();
		handleVariableUpdate();

		nf:xy(x + transX(bottomX, y + baseBottomY + bottomY - baseTopY - topY),
		      baseTopY + topY + transY(bottomX, y + baseBottomY + bottomY - baseTopY - topY))
		    :rotationy(reverseFactor * 180/pi * pitch)
		    :z(z + baseZ)
		    :SetFOV(baseFOV + fov)
		    :vanishpoint(baseX + topX,
		                 baseY + baseTopY + topY);
		for i, Actor in ipairs(nfc) do
			Actor:zoomtoheight((baseZoomY + zoomY)*oNoteColumnH[i]);
		end
		
		if not enabled and not isChanged then
			self:queuecommand("Term");
		end
	end

	local function OffCommand(self)
		enabled = false;

		ny, nz = oy - baseBottomY - bottomY, oz - baseZ;
		nfov = -1 - baseFOV;
		nzoomY = 1 - baseZoomY;
		ntopX, ntopY = oSkew*(_screen.cx - baseX), -baseTopY;
		modS:Tilt(oTilt, DEFAULT_APPROACH_RATE, true)
		    :Skew(oSkew, DEFAULT_APPROACH_RATE, true)
		    :Mini(oMini, DEFAULT_APPROACH_RATE);
	end

	local function TermCommand(self)
		mainActorFrame:playcommand("Reset", {pn});
	end


	actor = addNewActor(actorFrame, Def.Actor{
	    Name=name,
	    OnCommand=OnCommand,
	    UpdateCommand=UpdateCommand,
	    OffCommand=OffCommand,
	    TermCommand=TermCommand,
	});
	return actor;
end


local pnEnumToNumT = Enum.Reverse(PlayerNumber);
local function pnEnumTToNum(pnEnumT)
	for i, v in pairs(pnEnumT) do
		pnEnumT[i] = pnEnumToNumT[v];
	end
	return pnEnumT;
end


local textY, ntextY = 0, 0;

local function isMouseReset(index)
	return mouseReset[index] > 0;
end

local mainMousePressed = {false, false, false, false, false, false};
local function isMainMousePressed(index)
	local iw = (index-1)%3+1;
	return mainMousePressed[iw] or mainMousePressed[iw+3];
end
local function mainMouseButton(event)
	for i, v in ipairs(MOUSE_BUTTOMS) do
		if event.DeviceInput.button == "DeviceButton_"..v and event.type ~= "InputEventType_Repeat" then
			mainMousePressed[i] = event.type == "InputEventType_FirstPress";
		end
	end
	
	if isMainMousePressed(1) and isMainMousePressed(3) then
		mainActorFrame:playcommand("SetLane", pnEnumTToNum(GAMESTATE:GetEnabledPlayers()));
	end
	for i, v in ipairs{"up", "down"} do
		if event.DeviceInput.button == "DeviceButton_mousewheel "..v and event.type == "InputEventType_FirstPress" and isMainMousePressed(3) then
			ntextY = ntextY + (v == "up" and 1 or -1) * 20;
		end
	end
	return false;
end


local verboseTextDef = Def.BitmapText{
	Font="Common Normal",
	InitCommand=function(self)
		self:x(2*_safe.w):CenterY():halign(0):zoom(0.7):visible(VERBOSE_MODE_ENABLED);
		ntextY = _screen.cy;
	end
};


local isLaneSet = {};
local isLaneConstant = {};
local laneToDestroy = {};

local t = Def.ActorFrame{
	Name="mainActorFrame",
	OnCommand=function(self)
		topScreen = SCREENMAN:GetTopScreen();
		mainActorFrame = self;
		verboseText = addNewActor(self, verboseTextDef);

		local pnToSet = {};
		for i, pn in pairs(GAMESTATE:GetEnabledPlayers()) do
			local pconf = playerConfig:get_data(pn_to_profile_slot(pn));
			if pconf and pconf.Perspective == 6 then
				local pnNum = pnEnumToNumT[pn];
				pnToSet[#pnToSet+1] = pnNum;
				isLaneConstant[pnNum+1] = true;
			end
		end

		self:playcommand("SetLane", pnToSet);

		topScreen:AddInputCallback(mainMouseButton);

		local pl = topScreen:GetChild("PlayerP1");
		local nf = pl:GetChild("NoteField");

		self:SetUpdateFunction(function(Self)
			lastUpdateTime = updateTime;
			updateTime = clockS();
			deltaTime = updateTime - lastUpdateTime;
			
			textY = expSmoothApproach(textY, ntextY);
			verboseText:y(textY);

			Self:RunCommandsOnChildren(function(child)
			--	verboseText:settext("pl: ("..pl:GetX()..", "..pl:GetY()..", "..pl:GetZ()..")\n"..
			--						"nf: ("..nf:GetX()..", "..nf:GetY()..", "..nf:GetZ()..")"	);
				child:playcommand("Update");
			end)
		end);
	end,
	SetLaneCommand=function(self, params)
		for i, pn in pairs(params) do
			if not isLaneSet[pn+1] then
				local newChild = setHorizontalLaneForPn(self, pn, isLaneConstant[pn+1]);
				
				if newChild ~= nil then
					isLaneSet[pn+1] = true;
				end
			end
		end
		self:queuecommand("RefreshInfo");
	end,
	ResetCommand=function(self, params)
		local pn = params[1]

		mainIsMousePressed = {false, false, false};
		isLaneSet[pn+1] = false;

		self:queuecommand("RefreshInfo");
	end,
	RefreshInfoCommand=function(self)
		if VERBOSE_MODE_ENABLED then
			verboseText:settext(self:GetName()..": "..imp.print_actor_r(self).."\n"
			    .."isLaneSet: "..imp.print_r(isLaneSet));
		end
	end
};

return t;
