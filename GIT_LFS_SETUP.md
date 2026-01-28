# Git LFS Setup Guide

## Overview

This repository is configured to use Git Large File Storage (Git LFS) to handle large binary files. GitHub has a hard limit of 100MB for regular files, and files exceeding this limit will be rejected during push operations. Git LFS allows us to version control large files by storing them outside of the main Git repository.

This configuration tracks all binary file types commonly used in iOS and Android development, even if they are typically smaller than 100MB. This approach:
- **Prevents future issues**: Binary files can grow over time (e.g., adding more assets, longer videos)
- **Simplifies workflow**: No need to remember which specific files need LFS
- **Optimizes repository**: Binary files don't compress well in Git, so LFS improves clone/fetch performance

## What is Git LFS?

Git LFS (Large File Storage) is an extension that replaces large files with text pointers inside Git, while storing the actual file contents on a remote server. This keeps your repository size manageable while still allowing you to version large binary files.

## Tracked File Types

The following file types are automatically tracked by Git LFS in this repository:

### Media Files
- Images: `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.svg`
- Videos: `*.mp4`, `*.mov`, `*.avi`
- Audio: `*.mp3`, `*.wav`, `*.ogg`
- Fonts: `*.ttf`, `*.otf`, `*.woff`, `*.woff2`
- Documents: `*.pdf`

### Archive Files
- `*.zip`, `*.tar`, `*.tar.gz`, `*.tgz`, `*.gz`, `*.bz2`, `*.7z`, `*.rar`

### iOS Specific Files
- `*.ipa` - iOS app packages
- `*.xcarchive` - Xcode archives
- `*.dSYM` - Debug symbols
- `*.framework` - iOS frameworks
- `*.xcframework` - XCFrameworks

### Android Specific Files
- `*.apk` - Android app packages
- `*.aab` - Android App Bundles
- `*.aar` - Android Archive libraries

### Binary Libraries
- `*.a` - Static libraries
- `*.so` - Shared objects (Linux/Android)
- `*.dylib` - Dynamic libraries (macOS/iOS)
- `*.dll` - Dynamic link libraries (Windows)

### Package Files
- `*.dmg` - macOS disk images
- `*.pkg` - macOS installer packages
- `*.deb` - Debian packages
- `*.rpm` - RPM packages

### Database Files
- `*.db`, `*.sqlite`, `*.sqlite3`

## Installation

### Installing Git LFS

If you haven't already installed Git LFS, follow these steps:

#### macOS
```bash
brew install git-lfs
git lfs install
```

#### Ubuntu/Debian
```bash
sudo apt-get install git-lfs
git lfs install
```

#### Windows
Download from https://git-lfs.github.com/ or use:
```bash
winget install GitHub.GitLFS
git lfs install
```

### First Time Setup

When cloning this repository for the first time:

```bash
git clone https://github.com/1733208392/flextrikeIOS.git
cd flextrikeIOS
git lfs install
git lfs pull
```

## Usage

### Adding Large Files

When you add a file that matches one of the tracked patterns, it will automatically be handled by Git LFS:

```bash
# Add your file as usual
git add path/to/large-file.apk
git commit -m "Add Android build"
git push
```

### Checking LFS Status

To see which files are tracked by LFS:

```bash
# List all LFS tracked files in the repository
git lfs ls-files

# Show LFS tracking patterns
git lfs track
```

### Manually Track Additional File Types

If you need to track additional file types:

```bash
# Track a specific file type
git lfs track "*.extension"

# Track files in a specific directory
git lfs track "path/to/directory/**"

# Commit the updated .gitattributes
git add .gitattributes
git commit -m "Track additional file types with LFS"
```

## Troubleshooting

### Files Already Committed Without LFS

If you have large files already committed without LFS:

```bash
# Migrate existing files to LFS
git lfs migrate import --include="*.apk,*.ipa" --everything

# Force push to update remote (WARNING: rewrites history)
# Use --force-with-lease for safety
git push --force-with-lease
```

**⚠️ Important**: This rewrites Git history and requires all collaborators to re-clone the repository or reset their local branches. Coordinate with your team before doing this migration.

### Large File Rejected During Push

If you encounter an error like "file exceeds GitHub's file size limit of 100 MB":

1. Make sure Git LFS is installed and initialized
2. Check if the file type is tracked: `git lfs track`
3. If not tracked, add it: `git lfs track "*.extension"`
4. Commit the .gitattributes change
5. Try pushing again

### Checking File Size Before Commit

To check the size of files before committing:

```bash
find . -type f -size +50M ! -path './.git/*'
```

## Best Practices

1. **Always install Git LFS** before cloning the repository
2. **Commit .gitattributes changes** immediately after tracking new file types
3. **Build artifacts**: While this repo tracks build artifacts (*.ipa, *.apk, etc.) with LFS, only commit them when necessary (e.g., release builds for distribution). Add intermediate/debug builds to .gitignore
4. **Use .gitignore** for files that should never be versioned (temporary builds, dependencies, IDE files)
5. **Run `git lfs pull`** after switching branches if you're missing files

## Resources

- [Git LFS Official Documentation](https://git-lfs.github.com/)
- [GitHub's Git LFS Guide](https://docs.github.com/en/repositories/working-with-files/managing-large-files)
- [Git LFS Tutorial](https://github.com/git-lfs/git-lfs/wiki/Tutorial)

## Support

For issues related to Git LFS in this repository, please:
1. Check this documentation first
2. Verify Git LFS is properly installed
3. Check the `.gitattributes` file for tracked patterns
4. Open an issue if the problem persists
