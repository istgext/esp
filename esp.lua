--Settings--
local ESP = {
    Enabled = false,
    Boxes = true,
    BoxShift = CFrame.new(0,-1.5,0),
	BoxSize = Vector3.new(4,6,0),
    Color = Color3.fromRGB(255, 0, 0),
    FaceCamera = false,
    Names = true,
    TeamColor = true,
    Thickness = 2,
    AttachShift = 1,
    TeamMates = true,
    Players = true,
    
    Objects = setmetatable({}, {__mode=kv}),
    Overrides = {}
}

--Declarations--
local cam = workspace.CurrentCamera
local plrs = gameGetService(Players)
local plr = plrs.LocalPlayer
local mouse = plrGetMouse()

local V3new = Vector3.new
local WorldToViewportPoint = cam.WorldToViewportPoint

--Functions--
local function Draw(obj, props)
	local new = Drawing.new(obj)
	
	props = props or {}
	for i,v in pairs(props) do
		new[i] = v
	end
	return new
end

function ESPGetTeam(p)
	local ov = self.Overrides.GetTeam
	if ov then
		return ov(p)
	end
	
	return p and p.Team
end

function ESPIsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
	if ov then
		return ov(p)
    end
    
    return selfGetTeam(p) == selfGetTeam(plr)
end

function ESPGetColor(obj)
	local ov = self.Overrides.GetColor
	if ov then
		return ov(obj)
    end
    local p = selfGetPlrFromChar(obj)
	return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESPGetPlrFromChar(char)
	local ov = self.Overrides.GetPlrFromChar
	if ov then
		return ov(char)
	end
	
	return plrsGetPlayerFromCharacter(char)
end

function ESPToggle(bool)
    self.Enabled = bool
    if not bool then
        for i,v in pairs(self.Objects) do
            if v.Type == Box then --fov circle etc
                if v.Temporary then
                    vRemove()
                else
                    for i,v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
    end
end

function ESPGetBox(obj)
    return self.Objects[obj]
end

function ESPAddObjectListener(parent, options)
    local function NewListener(c)
        if type(options.Type) == string and cIsA(options.Type) or options.Type == nil then
            if type(options.Name) == string and c.Name == options.Name or options.Name == nil then
                if not options.Validator or options.Validator(c) then
                    local box = ESPAdd(c, {
                        PrimaryPart = type(options.PrimaryPart) == string and cWaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == function and options.PrimaryPart(c),
                        Color = type(options.Color) == function and options.Color(c) or options.Color,
                        ColorDynamic = options.ColorDynamic,
                        Name = type(options.CustomName) == function and options.CustomName(c) or options.CustomName,
                        IsEnabled = options.IsEnabled,
                        RenderInNil = options.RenderInNil
                    })
                    --TODO add a better way of passing options
                    if options.OnAdded then
                        coroutine.wrap(options.OnAdded)(box)
                    end
                end
            end
        end
    end

    if options.Recursive then
        parent.DescendantAddedConnect(NewListener)
        for i,v in pairs(parentGetDescendants()) do
            coroutine.wrap(NewListener)(v)
        end
    else
        parent.ChildAddedConnect(NewListener)
        for i,v in pairs(parentGetChildren()) do
            coroutine.wrap(NewListener)(v)
        end
    end
end

local boxBase = {}
boxBase.__index = boxBase

function boxBaseRemove()
    ESP.Objects[self.Object] = nil
    for i,v in pairs(self.Components) do
        v.Visible = false
        vRemove()
        self.Components[i] = nil
    end
end

function boxBaseUpdate()
    if not self.PrimaryPart then
        --warn(not supposed to print, self.Object)
        return selfRemove()
    end

    local color
    if ESP.Highlighted == self.Object then
       color = ESP.HighlightColor
    else
        color = self.Color or self.ColorDynamic and selfColorDynamic() or ESPGetColor(self.Object) or ESP.Color
    end

    local allow = true
    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
        allow = false
    end
    if self.Player and not ESP.TeamMates and ESPIsTeamMate(self.Player) then
        allow = false
    end
    if self.Player and not ESP.Players then
        allow = false
    end
    if self.IsEnabled and (type(self.IsEnabled) == string and not ESP[self.IsEnabled] or type(self.IsEnabled) == function and not selfIsEnabled()) then
        allow = false
    end
    if not workspaceIsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
        allow = false
    end

    if not allow then
        for i,v in pairs(self.Components) do
            v.Visible = false
        end
        return
    end

    if ESP.Highlighted == self.Object then
        color = ESP.HighlightColor
    end

    --calculations--
    local cf = self.PrimaryPart.CFrame
    if ESP.FaceCamera then
        cf = CFrame.new(cf.p, cam.CFrame.p)
    end
    local size = self.Size
    local locs = {
        TopLeft = cf  ESP.BoxShift  CFrame.new(size.X2,size.Y2,0),
        TopRight = cf  ESP.BoxShift  CFrame.new(-size.X2,size.Y2,0),
        BottomLeft = cf  ESP.BoxShift  CFrame.new(size.X2,-size.Y2,0),
        BottomRight = cf  ESP.BoxShift  CFrame.new(-size.X2,-size.Y2,0),
        TagPos = cf  ESP.BoxShift  CFrame.new(0,size.Y2,0),
        Torso = cf  ESP.BoxShift
    }

    if ESP.Boxes then
        local TopLeft, Vis1 = WorldToViewportPoint(cam, locs.TopLeft.p)
        local TopRight, Vis2 = WorldToViewportPoint(cam, locs.TopRight.p)
        local BottomLeft, Vis3 = WorldToViewportPoint(cam, locs.BottomLeft.p)
        local BottomRight, Vis4 = WorldToViewportPoint(cam, locs.BottomRight.p)

        if self.Components.Quad then
            if Vis1 or Vis2 or Vis3 or Vis4 then
                self.Components.Quad.Visible = true
                self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
                self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
                self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
                self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
                self.Components.Quad.Color = color
            else
                self.Components.Quad.Visible = false
            end
        end
    else
        self.Components.Quad.Visible = false
    end

    if ESP.Names then
        local TagPos, Vis5 = WorldToViewportPoint(cam, locs.TagPos.p)
        
        if Vis5 then
            self.Components.Name.Visible = true
            self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y)
            self.Components.Name.Text = self.Name
            self.Components.Name.Color = color
            
            self.Components.Distance.Visible = true
            self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y + 14)
            self.Components.Distance.Text = math.floor((cam.CFrame.p - cf.p).magnitude) ..m away
            self.Components.Distance.Color = color
        else
            self.Components.Name.Visible = false
            self.Components.Distance.Visible = false
        end
    else
        self.Components.Name.Visible = false
        self.Components.Distance.Visible = false
    end
    
    if ESP.Tracers then
        local TorsoPos, Vis6 = WorldToViewportPoint(cam, locs.Torso.p)

        if Vis6 then
            self.Components.Tracer.Visible = true
            self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
            self.Components.Tracer.To = Vector2.new(cam.ViewportSize.X2,cam.ViewportSize.YESP.AttachShift)
            self.Components.Tracer.Color = color
        else
            self.Components.Tracer.Visible = false
        end
    else
        self.Components.Tracer.Visible = false
    end
end

function ESPAdd(obj, options)
    if not obj.Parent and not options.RenderInNil then
        return warn(obj, has no parent)
    end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = Box,
        Color = options.Color --[[or selfGetColor(obj)]],
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or plrsGetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName == Model and (obj.PrimaryPart or objFindFirstChild(HumanoidRootPart) or objFindFirstChildWhichIsA(BasePart)) or objIsA(BasePart) and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)

    if selfGetBox(obj) then
        selfGetBox(obj)Remove()
    end

    box.Components[Quad] = Draw(Quad, {
        Thickness = self.Thickness,
        Color = color,
        Transparency = 1,
        Filled = false,
        Visible = self.Enabled and self.Boxes
    })
    box.Components[Name] = Draw(Text, {
		Text = box.Name,
		Color = box.Color,
		Center = true,
		Outline = true,
        Size = 19,
        Visible = self.Enabled and self.Names
	})
	box.Components[Distance] = Draw(Text, {
		Color = box.Color,
		Center = true,
		Outline = true,
        Size = 19,
        Visible = self.Enabled and self.Names
	})
	
	box.Components[Tracer] = Draw(Line, {
		Thickness = ESP.Thickness,
		Color = box.Color,
        Transparency = 1,
        Visible = self.Enabled and self.Tracers
    })
    self.Objects[obj] = box
    
    obj.AncestryChangedConnect(function(_, parent)
        if parent == nil and ESP.AutoRemove ~= false then
            boxRemove()
        end
    end)
    objGetPropertyChangedSignal(Parent)Connect(function()
        if obj.Parent == nil and ESP.AutoRemove ~= false then
            boxRemove()
        end
    end)

    local hum = objFindFirstChildOfClass(Humanoid)
	if hum then
        hum.DiedConnect(function()
            if ESP.AutoRemove ~= false then
                boxRemove()
            end
		end)
    end

    return box
end

local function CharAdded(char)
    local p = plrsGetPlayerFromCharacter(char)
    if not charFindFirstChild(HumanoidRootPart) then
        local ev
        ev = char.ChildAddedConnect(function(c)
            if c.Name == HumanoidRootPart then
                evDisconnect()
                ESPAdd(char, {
                    Name = p.Name,
                    Player = p,
                    PrimaryPart = c
                })
            end
        end)
    else
        ESPAdd(char, {
            Name = p.Name,
            Player = p,
            PrimaryPart = char.HumanoidRootPart
        })
    end
end
local function PlayerAdded(p)
    p.CharacterAddedConnect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end
plrs.PlayerAddedConnect(PlayerAdded)
for i,v in pairs(plrsGetPlayers()) do
    if v ~= plr then
        PlayerAdded(v)
    end
end

gameGetService(RunService).RenderSteppedConnect(function()
    cam = workspace.CurrentCamera
    for i,v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
        if v.Update then
            local s,e = pcall(v.Update, v)
            if not s then warn([EU], e, v.ObjectGetFullName()) end
        end
    end
end)

return ESP