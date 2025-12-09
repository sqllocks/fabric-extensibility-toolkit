# Internal Scripts Directory

This directory contains internal scripts and tools used by the Microsoft team for managing the Fabric Extensibility Toolkit project. These scripts are **excluded from public releases** and are only used in the staging/internal repository.

## Scripts

### SyncToPublic.ps1

Automates syncing changes from the staging repository to the public repository by creating a Pull Request.

#### Purpose
- Validates version numbers and release notes
- Creates versioned release branch (dev/release/{VERSION}) in public repository
- Syncs changes from staging to public release branch
- Creates Pull Requests for review
- Does NOT create tags or update README (done separately in public repo)

#### Usage

```powershell
# Basic sync with version check
.\SyncToPublic.ps1 -Version "2025.11.1"

# Dry run to see what would be done
.\SyncToPublic.ps1 -Version "2025.11.1" -DryRun

# Sync with custom repository
.\SyncToPublic.ps1 -Version "2025.11.1" -PublicRepoUrl "https://github.com/microsoft/fabric-extensibility-toolkit.git"

# Force sync without confirmations
.\SyncToPublic.ps1 -Version "2025.11.1" -Force
```

#### Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `-Version` | Version number (YYYY.MM or YYYY.MM.P format) | - | ✅ |
| `-PublicRepoUrl` | URL of public repository | `https://github.com/microsoft/fabric-extensibility-toolkit.git` | ❌ |
| `-PublicRepoOwner` | GitHub repository owner | `microsoft` | ❌ |
| `-PublicRepoName` | GitHub repository name | `fabric-extensibility-toolkit` | ❌ |
| `-SourceBranch` | Branch in staging repository to sync from | `main` | ❌ |
| `-TargetBranch` | Target branch for PR in public repo (where release branch merges to) | `main` | ❌ |
| `-Force` | Skip confirmation prompts | `false` | ❌ |
| `-DryRun` | Show what would be done without making changes | `false` | ❌ |

#### Prerequisites

1. **Git Repository**: Must be run from within the staging repository
2. **Release Notes**: File must exist at `docs/ReleaseNotes/{YYYY}/v{VERSION}.md` (e.g., `docs/ReleaseNotes/2025/v2025.11.md`)
3. **GitHub CLI** (optional): For automatic PR creation
4. **Git Access**: Push permissions to public repository

#### Process Flow

1. **Validation**
   - Checks version format (YYYY.MM or YYYY.MM.P)
   - Verifies release notes exist
   - Validates git repository status
   - Confirms GitHub CLI authentication

2. **Preparation**
   - Creates temporary working directory
   - Clones public repository
   - Creates or checks out dev/release/{VERSION} branch in public repository

3. **Synchronization**
   - Copies files from staging repository (SourceBranch)
   - Applies exclusion patterns (see below)
   - Commits changes to release branch

4. **Publication**
   - Pushes dev/release/{VERSION} branch to public repository
   - Creates Pull Request from dev/release/{VERSION} to target branch

5. **Cleanup**
   - Removes temporary directories
   - Reports completion status

> **Note**: The script creates a versioned release branch (dev/release/{VERSION}) in the public repository, allowing for review and testing before merging to the target branch.

#### Exclusion Patterns

The following files and directories are **excluded** from public releases:

```
scripts/_internal/*     # Internal scripts (this directory)
Workload/node_modules/* # Node.js dependencies
.git/*                  # Git internal files
.vs/*                   # Visual Studio files
.vscode/*               # VS Code settings
*.tmp                   # Temporary files
*.log                   # Log files
build/*                 # Build artifacts
release/*               # Release artifacts
.env.*                  # Environment files
```

#### Version Format

Versions must follow the **YYYY.MM** or **YYYY.MM.P** format:

- **YYYY**: 4-digit year (e.g., 2025)
- **MM**: 1-2 digit month (e.g., 11)
- **P**: Optional patch/fix number (e.g., 1)

Examples:
- ✅ `2025.11` (monthly release)
- ✅ `2025.11.1` (first patch of November 2025)
- ✅ `2025.1.15` (15th patch of January 2025)
- ✅ `2024.12` (December 2024 release)
- ❌ `v2025.11.1` (no prefix)
- ❌ `2025` (missing month)
- ❌ `25.11.1` (2-digit year)

#### Release Notes Format

Release notes must be placed in `docs/ReleaseNotes/{YYYY}/v{VERSION}.md` and should follow this structure:

The script automatically creates year folders (e.g., `2025/`, `2026/`) based on the version number.

```markdown
# Release Notes - v{VERSION}

## Overview
Brief description of the release.

## 🚀 New Features
### Feature Category
- Feature description
- Another feature

## 🔧 Technical Improvements
### Improvement Category  
- Technical improvement
- Another improvement

## 🐛 Bug Fixes
### Bug Category
- Bug fix description
- Another bug fix

## 💥 Breaking Changes
- Breaking change description
- Migration instructions

## 📖 Documentation Updates
- Documentation changes

## 🔄 Migration Guide
Step-by-step upgrade instructions.
```

#### Branch Handling

The script creates versioned release branches differently based on version type:

**Source Branch** (staging): The branch in staging repository to sync from (default: `main`)

**Release Branch** (public): 
- **Main versions** (e.g., `2025.12`): Creates new `dev/release/2025.12` branch
- **Patch versions** (e.g., `2025.12.1`): Uses existing `dev/release/2025.12` branch

**Target Branch** (public): The branch in public repository to create the PR against (default: `main`)

**Workflow**:
1. Clones public repository
2. **For main versions**: Creates `dev/release/{VERSION}` from target branch if it doesn't exist
3. **For patch versions**: Checks out existing `dev/release/{MAIN_VERSION}` (errors if not found)
4. Syncs files from staging repository's source branch
5. Commits and pushes to release branch in public repository
6. Creates Pull Request from release branch → target branch

**Example Workflows**:
- Staging `main` → Public `dev/release/2025.12` → PR to `main`: Monthly release (creates new branch)
- Staging `main` → Public `dev/release/2025.12` → PR to `main`: First patch (uses existing branch)
- Staging `hotfix` → Public `dev/release/2025.12` → PR to `main`: Second patch (uses existing branch)

**Branch Lifecycle**:
1. **2025.12** (main version): Creates `dev/release/2025.12` → PR → merge to main
2. **2025.12.1** (patch): Updates `dev/release/2025.12` → PR → merge to main  
3. **2025.12.2** (patch): Updates `dev/release/2025.12` → PR → merge to main
4. **2026.1** (main version): Creates `dev/release/2026.1` → PR → merge to main

**Benefits**:
- **Safety**: Release branch can be reviewed and tested before merging to main
- **Versioning**: Clear version tracking with dedicated branches
- **Patch Management**: All patches for a version use the same release branch
- **Rollback**: Release branch can be deleted without affecting main if issues are found

**Safe Updates**: Uses `--force-with-lease` when pushing to protect against overwrites

#### Error Handling

Common issues and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid version format" | Version doesn't match YYYY.MM or YYYY.MM.P | Use correct format |
| "Release notes not found" | Missing release notes file | Create file at expected path (docs/ReleaseNotes/{YYYY}/v{VERSION}.md) |
| "Release branch does not exist for patch version" | Trying to create patch before main version | Create main version first (e.g., 2025.12 before 2025.12.1) |
| "Git command failed" | Git repository issues | Check git status and permissions |
| "GitHub CLI not authenticated" | gh not logged in | Run `gh auth login` |
| "Robocopy failed" | File copy issues | Check file permissions |

#### Security Considerations

- Internal scripts are excluded from public releases
- Environment files with secrets are excluded
- Only curated changes are synchronized
- All commits are reviewed via Pull Request process

## Directory Structure

```
scripts/_internal/
├── README.md               # This file
├── SyncToPublic.ps1        # Sync changes to public repo script
└── [future scripts]        # Additional internal tools
```

## Best Practices

### Before Running Sync Script

1. **Verify Changes**: Ensure all desired changes are committed
2. **Test Locally**: Run full build and test suite  
3. **Update Documentation**: Update relevant docs and README files
4. **Create Release Notes**: Write comprehensive release notes
5. **Check Dependencies**: Verify no internal dependencies leak

### After PR is Merged in Public Repo

1. **Create Git Tags**: Tag the release in public repository
2. **Update README**: Update main README.md with latest release link
3. **Create GitHub Release**: Generate release notes and artifacts
4. **Announce**: Communicate release to stakeholders

### Version Management

- Use semantic versioning principles within YYYY.MM[.P] format
- Use YYYY.MM for monthly feature releases (creates new release branch)
- Use YYYY.MM.P for patches and hotfixes (uses existing release branch)
- **Important**: Always create main version (e.g., 2025.12) before patches (e.g., 2025.12.1)
- Patch versions must have corresponding main version release branch already created
- Increment month for feature releases
- Use year boundary for major releases

### Release Notes Guidelines

- Write for external users (not internal team)
- Include migration instructions for breaking changes
- Highlight new features and improvements
- Document known issues and workarounds
- Provide clear upgrade paths

## Contributing

These scripts are maintained by the Microsoft Fabric Extensibility team. For suggestions or issues:

1. Create internal work items for improvements
2. Test changes thoroughly before committing
3. Update documentation for any script modifications
4. Follow PowerShell best practices and error handling

---

**Note**: This directory and its contents are automatically excluded from public repository synchronization.