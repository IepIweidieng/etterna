local returnFunction, level = ...;
if not returnFunction then
	return Def.BGAnimation{
		Name = "New BGAnimation",
	};
end


local baseAttrs, baseDoPreProcess =
	loadfile(ResolveRelativePath("ActorFrame.lua", 1))(true, level+1);

local addNewActor = dofile(ResolveRelativePath("new_Actor/NewActor.lua", 1));
local function doPreProcess(actor, actorDef, level)
	baseDoPreProcess(actor, actorDef, level+1);
end

local attrs = {
	AniDir = nil,
	LengthSeconds = function(actor, fLengthSeconds)
		local pActor = addNewActor(actor, Def.Actor{
			Name = "BGAnimation dummy",
		});
		pActor:visible(false)
		      :addcommand("On", function(self)
				self:sleep(fLengthSeconds);
		      end);
	end
} .. baseAttrs;

return attrs, doPreProcess;
