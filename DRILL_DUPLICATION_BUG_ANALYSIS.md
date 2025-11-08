# Drill Duplication Bug Analysis

## Bug Description
`DrillFormView` creates **duplicate drill entries** in Core Data when saving, particularly when editing existing drills.

## Root Cause

### The Problem Flow

**For ADD mode:**
```
saveDrill() 
  → createNewDrillSetup()           [Creates new DrillSetup + DrillTargetsConfig objects in viewContext]
  → viewContext.save()               [Saves ALL inserted objects]
```

**For EDIT mode:**
```
saveDrill()
  → targets = targetConfigs          [Sync state variable with edited values]
  → updateExistingDrillSetup()       [Updates existing DrillSetup AND creates NEW DrillTargetsConfig objects]
  → viewContext.save()               [Saves both the UPDATED object AND the NEW targets]
```

### Why Duplicates Occur in EDIT Mode

In `updateExistingDrillSetup()` at line 605:

```swift
// Clear and update targets
if let existingTargets = drillSetup.targets {
    drillSetup.removeFromTargets(existingTargets)
}

for targetData in targetConfigs {
    let target = DrillTargetsConfig(context: viewContext)  // ← NEW OBJECT CREATED!
    target.id = targetData.id
    target.seqNo = Int32(targetData.seqNo)
    // ... properties ...
    drillSetup.addToTargets(target)  // ← Added to the existing drill
}
```

**Issue:** Every time you edit a drill, brand new `DrillTargetsConfig` objects are created instead of updating the existing ones.

**Result:** After first edit → 2 targets | After second edit → 3 targets | After third edit → 4 targets, etc.

### Secondary Duplication Path in DrillRepository

In `DrillRepository.saveDrillSetup()` at line 42-76:

```swift
func saveDrillSetup(_ setup: DrillSetupData) throws {
    // ... fetch logic ...
    if let existing = existingSetups.first {
        // Update existing...
        if let existingTargets = coreDataSetup.targets {
            coreDataSetup.removeFromTargets(existingTargets)  // Remove old
        }
        
        for targetConfig in setup.targets {
            let config = DrillTargetsConfig(context: context)  // ← NEW objects again
            // ...
            coreDataSetup.addToTargets(config)  // ← Add new ones
        }
    }
}
```

**Issue:** Same problem—always creating new target objects instead of reusing/updating existing ones.

## Why This Happens

The code treats target configs as **disposable** rather than **persistent** entities. When editing:

1. **Current approach:** Delete all old targets → Create new targets → Save
2. **Problem:** Multiple saves can retain old targets due to:
   - Multiple calls to `updateExistingDrillSetup()` before save
   - Cascading deletes not properly handled by Core Data
   - Race conditions if saves happen simultaneously

## Files Affected

1. **`DrillFormView.swift` (line 605)** — Creates new targets on every edit
2. **`DrillRepository.swift` (line 68-70)** — Creates new targets instead of updating
3. **`DrillListView.swift` (line 200-210)** — `copyDrill()` creates new targets (correct pattern)

## Solution Options

### Option 1: Update Existing Targets (Recommended)
```swift
// In updateExistingDrillSetup()
private func updateExistingDrillSetup(_ drillSetup: DrillSetup) {
    // ... update drill properties ...
    
    // Get existing targets as a dict by ID
    let existingTargets = (drillSetup.targets as? Set<DrillTargetsConfig>) ?? []
    let targetMap = Dictionary(uniqueKeysWithValues: existingTargets.map { ($0.id, $0) })
    
    // Update existing targets or create new ones
    for targetData in targetConfigs {
        let target: DrillTargetsConfig
        
        if let existing = targetMap[targetData.id] {
            // Update existing target
            target = existing
        } else {
            // Create new target only if needed
            target = DrillTargetsConfig(context: viewContext)
        }
        
        target.seqNo = Int32(targetData.seqNo)
        target.targetName = targetData.targetName
        target.targetType = targetData.targetType
        target.timeout = targetData.timeout
        target.countedShots = Int32(targetData.countedShots)
        target.drillSetup = drillSetup
    }
    
    // Remove targets that are no longer needed
    let targetIdsToKeep = Set(targetConfigs.map { $0.id })
    let targetsToRemove = existingTargets.filter { !targetIdsToKeep.contains($0.id ?? UUID()) }
    for target in targetsToRemove {
        drillSetup.removeFromTargets(target)
        viewContext.delete(target)
    }
}
```

### Option 2: Clear and Recreate (Current, but with safety)
This is what the code does now—just ensure it happens only once per save cycle and targets are properly validated before delete.

## Testing Steps to Verify Bug

1. Create a new drill with 2 targets
2. Verify it shows 2 targets in Core Data
3. Edit the drill and change one target name
4. Check Core Data: Should still show 2 targets (but will show 4)
5. Edit again: Shows 6 targets
6. Pattern: Each edit adds N more duplicate targets

## Files to Modify

- `/Users/kai/Documents/flextrikeIOS/flextarget/View/Drills/DrillFormView.swift` → `updateExistingDrillSetup()` method
- `/Users/kai/Documents/flextrikeIOS/flextarget/Model/DrillRepository.swift` → `saveDrillSetup()` method

## Recommendation

Implement **Option 1** to preserve existing targets and only update their properties. This avoids cascading deletes and keeps the relationship stable.
