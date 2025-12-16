# FlexTarget Android

Android port of the FlexTarget iOS shooting drill training application.

## Project Structure

```
FlexTargetAndroid/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/flextarget/android/
│   │   │   │   ├── data/
│   │   │   │   │   ├── local/
│   │   │   │   │   │   ├── entity/        # Room entities
│   │   │   │   │   │   ├── dao/           # Data Access Objects
│   │   │   │   │   │   ├── converter/     # Type converters
│   │   │   │   │   │   └── FlexTargetDatabase.kt
│   │   │   │   │   └── repository/        # Repository layer
│   │   │   │   └── MainActivity.kt
│   │   │   └── AndroidManifest.xml
│   │   ├── test/                          # Unit tests
│   │   └── androidTest/                   # Instrumented tests
│   └── build.gradle.kts
├── build.gradle.kts
└── settings.gradle.kts
```

## Database Migration from iOS CoreData

This project implements a complete migration of the iOS CoreData schema to Android Room:

### Entities

1. **DrillSetupEntity** - Drill configurations
   - Migrated from iOS `DrillSetup`
   - Fields: id, name, desc, demoVideoURL, thumbnailURL, delay, drillDuration, repeats, pause

2. **DrillResultEntity** - Execution results
   - Migrated from iOS `DrillResult`
   - Fields: id, date, drillId, sessionId, totalTime, drillSetupId
   - Foreign key: drillSetupId → DrillSetupEntity (onDelete = SET NULL)

3. **ShotEntity** - Individual shots
   - Migrated from iOS `Shot`
   - Fields: id, data, timestamp, drillResultId
   - Foreign key: drillResultId → DrillResultEntity (onDelete = SET NULL)

4. **DrillTargetsConfigEntity** - Target configurations
   - Migrated from iOS `DrillTargetsConfig`
   - Fields: id, seqNo, targetName, targetType, timeout, countedShots, drillSetupId
   - Foreign key: drillSetupId → DrillSetupEntity (onDelete = SET NULL)

### Relationships

- **DrillSetup ↔ DrillTargetsConfig**: One-to-many (cascade delete)
- **DrillSetup ↔ DrillResult**: One-to-many (cascade delete)
- **DrillResult ↔ Shot**: One-to-many (cascade delete)

### Type Converters

- `UUID` ↔ `String`
- `Date` ↔ `Long` (timestamp)

## Testing

### Unit Tests (test/)
- `DrillSetupRepositoryTest` - Repository layer tests with mocked DAOs
- `DrillResultRepositoryTest` - Repository layer tests with mocked DAOs

### Instrumented Tests (androidTest/)
- `DrillSetupDaoTest` - DAO operations and queries
- `DrillResultDaoTest` - DAO operations with relationships
- `ShotDaoTest` - Shot entity operations
- `DrillTargetsConfigDaoTest` - Target configuration operations

## Running Tests

```bash
# Unit tests
./gradlew test

# Instrumented tests (requires Android device/emulator)
./gradlew connectedAndroidTest
```

## Build

```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease
```

## Dependencies

- **Room**: 2.6.1 - Database persistence
- **Kotlin Coroutines**: 1.7.3 - Async operations
- **Jetpack Compose** - Modern UI toolkit
- **JUnit**: 4.13.2 - Unit testing
- **Truth**: 1.1.5 - Fluent assertions
- **Mockito**: 5.7.0 - Mocking framework

## Migration Notes

This implementation provides:
- ✅ Complete CoreData schema migration to Room
- ✅ All entity relationships preserved
- ✅ Proper cascade deletion rules
- ✅ Type converters for UUID and Date
- ✅ Comprehensive DAO interfaces
- ✅ Repository pattern for clean architecture
- ✅ Unit tests with mocking
- ✅ Instrumented tests with in-memory database
- ✅ Flow-based reactive queries

## Next Steps

Remaining migration tasks:
1. BLE (Bluetooth Low Energy) manager implementation
2. Jetpack Compose UI screens
3. OpenCV integration for image processing
4. Localization resources (7 languages)
5. Asset migration (images, audio, HTML tutorials)
