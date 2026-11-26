# ZERO MERCY — Real phone media and playable games

## Phone media playback
The phone media player scene is `res://scenes/ui/phone_media_player.tscn`.
It plays actual imported Godot `VideoStream` resources and `Texture2D` images. Add licensed/owned assets under `res://media/videos/` and `res://media/photos/`, then pass their exact resource path in a media record's `asset_path` (or open the path in the player).

For broad Godot 4 compatibility, use Ogg Theora video (`.ogv`) and standard imported image formats such as PNG/JPEG. Metadata-only `asset_key` values are intentionally not treated as playable media. The repository does not yet contain a licensed real-world video library.

## Playable tactical FPS foundation
Open `res://scenes/games/tactical_fps_match.tscn` to run the first playable tactical-shooter foundation:
- WASD movement, mouse look and firing
- magazine, reserve ammo and reload
- five moving hostile bots with health
- player health, elimination score and round timer
- procedural cover arena

This is an early single-player prototype, not a finished Counter-Strike/PUBG-scale game, not network multiplayer, and not yet launched from the in-world smartphone. Battle-royale systems, large maps, squads, loot, vehicles, matchmaking, touch controls, animation, audio, and NPC-vs-NPC matches remain future work.

## Important
Only use video, photo, sound and other media assets that ZERO MERCY has permission to distribute. A video player does not grant rights to third-party content.

## Phone integration (November 2026)

The in-world phone UI now exposes **MEDIA** and **GAMES** tabs:
- Press **P** in the main world, then choose MEDIA or GAMES.
- MEDIA opens the dedicated player overlay. Choose a feed item with an installed asset, or enter a project path such as `res://media/videos/sample.ogv`; use **BACK TO PHONE** to return.
- Supported local assets are Godot `VideoStream` resources (for example imported OGV) and `Texture2D` images (PNG/JPEG).
- GAMES launches the standalone Tactical Breach training match. Use **EXIT TO PHONE** to leave; Dara's player camera and movement are restored.
- The current social feed contains metadata unless a real local asset path is supplied. No copyrighted video/photo library is bundled.
- Tactical Breach remains an offline single-player prototype. It is not online PUBG/Counter-Strike, and has no matchmaking or network multiplayer.

These phone launch flows are code-integrated but still require Godot 4 runtime validation on desktop and Android.
