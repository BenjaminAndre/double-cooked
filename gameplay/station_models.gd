class_name StationModels
extends RefCounted
## The animations of the artist's station models, which stand in their scene
## (art/scenes, see GridRoom.art): the FRIGO's door, the bin's lid, the fryer's baskets.

## Animations, in frames at 30 per second (docs/art/Readme_SettingsV3.txt).
const FPS := 30.0
const DOOR_OPEN := Vector2(1, 10)
const DOOR_CLOSE := Vector2(11, 24)
## Meta key on each basket: its "eject food" move (eject_frames), frames 0 to 30 of the
## fryer's animation. That animation tips both baskets at once: each plays its own part.
const EJECT := &"eject"
const EJECT_FRAMES := Vector2i(0, 30)


## A basket's tracks over EJECT_FRAMES, one [offset, rotation] per frame, both in the basket's
## own space and from its first frame (a basket rests unrotated).
static func eject_frames(animation: Animation, basket: String) -> Array:
    var position_track := -1
    var rotation_track := -1
    for track in animation.get_track_count():
        if not String(animation.track_get_path(track)).ends_with(basket):
            continue
        match animation.track_get_type(track):
            Animation.TYPE_POSITION_3D:
                position_track = track
            Animation.TYPE_ROTATION_3D:
                rotation_track = track
    if position_track < 0 or rotation_track < 0:
        return []
    var start := animation.position_track_interpolate(position_track, EJECT_FRAMES.x / FPS)
    var frames := []
    for frame in range(EJECT_FRAMES.x, EJECT_FRAMES.y + 1):
        frames.append([animation.position_track_interpolate(position_track, frame / FPS) - start,
                animation.rotation_track_interpolate(rotation_track, frame / FPS)])
    return frames


## Plays part of a model's only animation, in frames, and stays on its last frame.
static func play(models: Node, frames: Vector2) -> void:
    var player := models.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if not player or player.get_animation_list().is_empty():
        return
    var animation := player.get_animation_list()[0]
    player.play_section(animation, frames.x / FPS, frames.y / FPS)
