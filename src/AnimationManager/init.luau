--!strict

local CollectionService = game:GetService("CollectionService")

local DefaultData = require(script.DefaultData)
local Types = require(script.Types)

local AnimationManager = {}
AnimationManager._Storage = {}
AnimationManager._TagCache = {}

-- // Constructor

function AnimationManager.new(AnimatorID: string, Animator: Animator)
    AnimationManager._Storage[AnimatorID] = DefaultData(Animator)
    return AnimationManager._Storage[AnimatorID]
end

function AnimationManager.get(AnimatorID)
    return AnimationManager._Storage[AnimatorID]
end

-- // 

function AnimationManager.LoadTag(AnimObj: Types.AnimObj, Tag: string)
    local TaggedInstances = AnimationManager._TagCache[Tag] or CollectionService:GetTagged(Tag)
    AnimationManager._TagCache[Tag] = TaggedInstances
    AnimObj.LoadedAnimations[Tag] = {}
    local LoadedTag = AnimObj.LoadedAnimations[Tag]

    for _, Animation: Animation in TaggedInstances do
        LoadedTag[Animation.Name] = 
    end


end

function AnimationManager.UnloadTag(AnimObj: Types.AnimObj, Tag: string)
end

function AnimationManager.PlayAnim(AnimObj: Types.AnimObj, Tag: string, AnimName: string)
end

function AnimationManager.GetPlayingAnims(AnimObj: Types.AnimObj)
end

function AnimationManager.StopAllAnims(AnimObj: Types.AnimObj)
end

return AnimationManager