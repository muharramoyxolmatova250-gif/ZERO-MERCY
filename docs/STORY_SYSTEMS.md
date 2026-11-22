# Story systems

The repository includes three small, data-driven foundations:
- `scripts/story/mission_manager.gd`: sequential objective tracking via gameplay events.
- `scripts/story/dialogue_manager.gd`: branching dialogue loaded from JSON.
- `scripts/save/save_manager.gd`: versioned local JSON save/load.

## Integration

Add the mission and dialogue scripts as Autoload singletons in Project Settings if they should be globally accessible. Add SaveManager as an Autoload named `SaveManager`.

Example mission usage:
```gdscript
MissionManager.start_mission("prologue_signal")
MissionManager.report_event("enter_old_market")
```

Example dialogue usage:
```gdscript
DialogueManager.start_dialogue("intro", "res://data/story/dialogue_intro.json")
DialogueManager.choose(0)
```

Example save usage:
```gdscript
SaveManager.save_game({"chapter": "prologue", "credits": 250})
var loaded_state := SaveManager.load_game()
```

These are gameplay foundations, not a complete mission UI, cinematic system, branching quest database, cloud save, or tested final story implementation. Wire signals to UI and game-world interactions in later integration work.
