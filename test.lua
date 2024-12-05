local stepInterval = 0.35

local function calcDistance(old, new)
    return (old.Position - new.Position).Magnitude
end

local function getParentPos(bone)
    if bone:IsA("Bone") then
        return bone.WorldPosition
    else
        return bone.Position
    end
end

local function onBone(bone, params)
    local oldcf = bone:GetAttribute("oldCF")
    local distance = calcDistance(oldcf, bone.WorldCFrame)

    local neededSteps = math.ceil(distance / stepInterval)

    for i = 1, neededSteps do
        local currentcf = oldcf:Lerp(bone.WorldCFrame, i / neededSteps)
        local parentPos = getParentPos(bone)
        local offset = CFrame.new(currentcf.Position, parentPos) * CFrame.new(0, 0, -(parentPos - currentcf.Position).Magnitude / 2)

        local ray = workspace:GetPartBoundsInBox(offset, (parentPos - currentcf.Position).Magnitude, params)
        if #ray > 0 then
            for _, v in ray do
                local model = v:FindFirstAncestorOfClass("Model")
                if not model then continue end

                local humanoid = model:FindFirstChild("Humanoid")
                if not humanoid then continue end

                table.insert(params.FilterDescendantInstances, model)
                -- fire touched event
            end
        end
    end
end

local function runHitboxSim(bones, filter)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantInstances = filter or {}

    for i,v in bones do
        onBone(v, params)
    end
end