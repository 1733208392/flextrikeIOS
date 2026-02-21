# Multi-Target Sequence Feature for Network Drills

## Overview

The Godot drills_network now supports configurable target sequences. A single BLE ready command can specify an array of target types, and the Godot app will automatically cycle through each target after 2 shots, then end the drill.

## BLE Command Format

### Single Target (Backward Compatible)
```json
{
  "action": "netlink_forward",
  "dest": "5F0430",
  "content": {
    "command": "ready",
    "delay": 0.0,
    "targetType": "ipsc",
    "timeout": 1200,
    "countedShots": 5,
    "repeat": 1,
    "isFirst": true,
    "isLast": true,
    "mode": "ipsc"
  }
}
```

### Multiple Targets (New Feature)
```json
{
  "action": "netlink_forward",
  "dest": "5F0430",
  "content": {
    "command": "ready",
    "delay": 0.0,
    "targetType": ["ipsc", "hostage", "paddle"],
    "timeout": 1200,
    "countedShots": 5,
    "repeat": 1,
    "isFirst": true,
    "isLast": true,
    "mode": "ipsc"
  }
}
```

## Implementation Details

### State Variables
- `target_sequence: Array` - Array of target types to cycle through
- `current_target_index: int` - Index of the current target (0-based)
- `shots_on_current_target: int` - Counts shots on the current target

### Parsing Logic
In `_on_ble_ready_command()`:
- If `targetType` is a string, it's converted to a single-element array
- If `targetType` is an array, it's used as-is
- Each target in the sequence is validated against the game mode
- The first target is loaded and spawned (unless in CQB mode)

### Transition Mechanism
When a target receives 2 shots:
1. `_on_target_hit()` or `_on_cqb_target_hit()` increments `shots_on_current_target`
2. When `shots_on_current_target >= 2`:
   - If NOT the last target in sequence: Call `_transition_to_next_target()`
   - If IS the last target: Apply legacy "endingTarget" logic

### `_transition_to_next_target()` Function
- Increments `current_target_index`
- Resets `shots_on_current_target` to 0
- Validates the next target type
- Removes the old target instance
- Spawns the new target
- Each shot sends one performance record with the current `target_type` included

### Automatic Drill Ending
When the last target in the sequence receives 2 shots:
1. `_transition_to_next_target()` detects `current_target_index >= target_sequence.size()`
2. Automatically calls `_on_ble_end_command({})` to end the drill
3. Sends acknowledgement `{"ack": "end", "drill_duration": <seconds>}` to mobile app

### Early Termination
If the mobile app sends an explicit "end" command before all targets are completed:
1. `_on_ble_end_command()` is invoked
2. Calls `complete_drill()` to stop the timer and show completion overlay
3. Sends end acknowledgement to mobile app
4. Prevents any further target transitions

## Shot Data Recording

Each shot fires one record per shot, regardless of multi-target configuration:
```json
{
  "cmd": "shot",
  "tt": "ipsc",  // current target type at time of shot
  "td": 0.42,    // sensor time in seconds
  "hp": {"x": "100.5", "y": "200.3"},  // hit position
  "ha": "8",     // hit area/zone
  "rep": 1,      // repeat number
  "std": "0.00"  // shot timer delay
}
```

The mobile app can segment shots by `tt` (target type) for per-target analytics.

## Example Flow: 3-Target Drill

**BLE Ready Command:**
```json
{
  "command": "ready",
  "targetType": ["ipsc", "hostage", "paddle"],
  "mode": "ipsc"
}
```

**Sequence:**

| Step | Event | Action |
|------|-------|--------|
| 1 | Ready received | Parse targetType array, spawn "ipsc" target |
| 2 | Shot 1 on ipsc | Log shot, shots_on_current_target=1 |
| 3 | Shot 2 on ipsc | Log shot, shots_on_current_target=2 → **TRANSITION** |
| 4 | Transition | Remove ipsc, load hostage, spawn hostage target |
| 5 | Shot 3 on hostage | Log shot, shots_on_current_target=1 |
| 6 | Shot 4 on hostage | Log shot, shots_on_current_target=2 → **TRANSITION** |
| 7 | Transition | Remove hostage, load paddle, spawn paddle target |
| 8 | Shot 5 on paddle | Log shot, shots_on_current_target=1 |
| 9 | Shot 6 on paddle | Log shot, shots_on_current_target=2 → **END DRILL** |

**Total Performance Records:** 6 shot records + 1 end acknowledgement

## Backward Compatibility

- Single targetType strings continue to work (e.g., `"targetType": "ipsc"`)
- Handled as a single-element array internally
- Legacy drills with no targetType specified use mode defaults
- Existing single-target drill flows unchanged

## Valid Target Types by Mode

### IPSC Mode
ipsc, special_1, special_2, hostage, rotation, paddle, popper, final

### IDPA Mode
idpa, idpa_black_1, idpa_black_2, idpa_ns, hostage, paddle, popper, final

### CQB Mode
cqb_front, cqb_move, cqb_swing, cqb_hostage, disguised_enemy

## Error Handling

- Invalid targets in sequence are skipped (recursively tries next target)
- Invalid mode defaults to "ipsc"
- Empty sequence defaults to first valid target for the mode
- Malformed targetType falls back to defaults
- Early end command gracefully stops the sequence

## Testing Checklist

- [ ] Send multi-target ready with 3 targets; verify each displays after 2 shots
- [ ] Verify each shot record includes correct target type in "tt" field
- [ ] Send early "end" command; verify drill stops without completing sequence
- [ ] Test backward compatibility: send single-string targetType
- [ ] Verify performance tracker sends correct number of shot records
- [ ] Test CQB mode multi-target
- [ ] Test IDPA mode multi-target
- [ ] Verify UI updates correctly when targets transition
- [ ] Check that transition delay allows bullet effects to complete
