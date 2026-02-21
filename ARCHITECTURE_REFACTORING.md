# Android Drill Targets Architecture Refactoring

## Status: In Progress

### Completed (Phase 1)

#### 1. Value Objects
**Files Created:**
- `TargetType.kt` - Enforces non-empty, no JSON arrays
- `DeviceId.kt` - Enforces non-empty device IDs

**Benefits:**
- Type-safe handling of domain concepts
- Validation at construction (fail fast)
- Prevents mixing different string types accidentally
- Self-documenting code

**Usage:**
```kotlin
val type = TargetType("ipsc")  // Valid
val type = TargetType("[\"ipsc\",\"hostage\"]")  // Throws - JSON array not allowed
```

#### 2. Sealed Class for Explicit Types
**File Created:**
- `DrillTargetState.kt` - Sealed class with SingleTarget and ExpandedMultiTarget

**Benefits:**
- Compiler enforces correct handling of each case
- No more implicit contracts
- Self-documenting distinction between single/multi-target

```kotlin
when (target) {
    is DrillTargetState.SingleTarget -> { /* match by device */ }
    is DrillTargetState.ExpandedMultiTarget -> { /* match by type */ }
}
```

#### 3. Centralized Transformation Logic
**File Created:**
- `TargetExtensions.kt` - All target conversions in ONE place

**Benefits:**
- No scattered transformation logic
- Easy to find and maintain
- Single source of truth for conversions
- Can't accidentally use wrong conversion

**Extension Functions:**
- `List<DrillTargetsConfigEntity>.toExpandedDataObjects()`
- `List<DrillTargetsConfigData>.toDisplayTargets()`
- `List<DrillTargetsConfigEntity>.toDisplayTargets()`
- `List<DrillTargetState>.groupByDevice()`
- Helper functions for validation

#### 4. Comprehensive Domain Tests
**File Created:**
- `ShotMatchingTests.kt` - Tests and extracted matching function

**Benefits:**
- Domain rules are explicit and testable
- Single source of truth for matching logic
- Prevents regressions
- Documents expected behavior

**Key Test Cases:**
- ✅ Multi-target: same device, different types → should NOT match
- ✅ Multi-target: only type matching, no device fallback
- ✅ Single-target: device name matching
- ✅ Edge cases: null devices, whitespace, case sensitivity

---

### Next Steps (Phase 2)

#### 5. Repository Wrapper
Create explicit repository interface:
```kotlin
interface DrillTargetRepository {
    suspend fun getTargetsExpandedForDisplay(drillId: UUID): List<DrillTargetState>
    suspend fun getTargetsRaw(drillId: UUID): List<DrillTargetsConfigEntity>
}
```

#### 6. Refactor DrillResultView
Replace old matching logic with new sealed class handling:
```kotlin
private fun shotMatchesTarget(shot: ShotData, target: DrillTargetState): Boolean {
    return when (target) {
        is DrillTargetState.ExpandedMultiTarget -> 
            shot.content.actualTargetType.lowercase() == target.targetType.value.lowercase()
        is DrillTargetState.SingleTarget -> 
            shot.device?.trim()?.lowercase() == target.targetName.lowercase()
    }
}
```

#### 7. Update Calling Code
- TimerSessionView → use `.toExpandedDataObjects()`
- DrillFormView → use extension functions
- HistoryTabViewModel → use extension functions
- All scoring utilities → accept DrillTargetsConfigData

---

### Architecture Improvements Summary

**Before:**
- Implicit contracts about data shape
- Scattered transformation logic
- Type confusion (string used for everything)
- Hard to track data flow
- Vulnerable to similar bugs

**After:**
- Explicit types (sealed classes)
- Centralized transformations
- Type-safe domains (TargetType, DeviceId)
- Self-documenting code
- Testable domain logic
- Single source of truth for each concept

---

### Files Created
1. `TargetType.kt` - Value object
2. `DeviceId.kt` - Value object  
3. `DrillTargetState.kt` - Sealed class with type distinction
4. `TargetExtensions.kt` - All transformation extension functions
5. `ShotMatchingTests.kt` - Domain tests + extracted matching function

### Files to Refactor (Next)
1. `DrillResultView.kt` - Use DrillTargetState and new matching logic
2. `TimerSessionView.kt` - Use target extension functions
3. `DrillFormView.kt` - Use target extension functions  
4. `DrillExecutionManager.kt` - Accept DrillTargetsConfigData (or DrillTargetState)
5. `HistoryTabViewModel.kt` - Use extension functions

---

## Key Architectural Insight

The root cause of the "all shots on all targets" bug was **implicit contracts without type enforcement**:

**❌ Old way:**
```kotlin
// Implicit: "these targets are from same device" → "single target"
// Reality: After expansion, each target still has same device name!
val targets: List<DrillTargetsConfigData> = ...
val shots: List<ShotData> = ...
// Bug: All shots match all targets via device name fallback
```

**✅ New way:**
```kotlin
// Explicit: Type tells you exactly what this is
val target: DrillTargetState.ExpandedMultiTarget = ...
when (target) {
    is DrillTargetState.ExpandedMultiTarget -> onlyMatchByType()  // Compiler enforces
    is DrillTargetState.SingleTarget -> onlyMatchByDevice()      // Compiler enforces
}
```

The compiler won't let you forget which matching strategy to use!
