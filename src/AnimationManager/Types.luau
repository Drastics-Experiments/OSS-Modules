export type AnimObj = {
    Animator: Animator,
    LoadedAnimations: {[string]: {[string]: AnimationTrack}},
    PlayingAnimations: {
        CORE: AnimationTrack?,
        ACTION: AnimationTrack?,
        ACTION1: AnimationTrack?,
        ACTION2: AnimationTrack?
    }
}

return nil