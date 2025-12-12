<#
.SYNOPSIS
    Syncs changes from staging repository to public repository and creates a Pull Request

.DESCRIPTION
    This script automates syncing changes to the public Microsoft Fabric Extensibility Toolkit repository:
    1. Validates the version number format
    2. Checks for corresponding release notes
    3. Creates or updates dev/release/{VERSION} branch in public repository
    4. Syncs changes from staging source branch to release branch (with exclusions)
    5. Creates a Pull Request from dev/release/{VERSION} to target branch

.PARAMETER Version
    The version number in format YYYY.MM.P (e.g., 2025.11.1)

.PARAMETER PublicRepoUrl
    The URL of the public GitHub repository (default: https://github.com/microsoft/fabric-extensibility-toolkit.git)

.PARAMETER PublicRepoOwner
    The owner of the public repository (default: microsoft)

.PARAMETER PublicRepoName
    The name of the public repository (default: fabric-extensibility-toolkit)

.PARAMETER SourceBranch
    The source branch in staging repository to sync from (default: main)

.PARAMETER TargetBranch
    The target branch for the Pull Request in public repository (default: main)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER DryRun
    Perform a dry run - show what would be done without making changes (alias: WhatIf)

.EXAMPLE
    .\SyncToPublic.ps1 -Version "2025.11"
    Syncs from staging/main to public/dev/release/2025.11 and creates PR to main

.EXAMPLE
    .\SyncToPublic.ps1 -Version "2025.11" -DryRun
    Shows what would be done without making changes

.EXAMPLE
    .\SyncToPublic.ps1 -Version "2025.11.1" -SourceBranch "dev" -TargetBranch "main"
    Syncs from staging/dev to public/dev/release/2025.11.1 and creates PR to main

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter()]
    [string]$PublicRepoUrl = "https://github.com/microsoft/fabric-extensibility-toolkit.git",
    
    [Parameter()]
    [string]$PublicRepoOwner = "microsoft",
    
    [Parameter()]
    [string]$PublicRepoName = "fabric-extensibility-toolkit",
    
    [Parameter()]
    [string]$SourceBranch = "main",
    
    [Parameter()]
    [string]$TargetBranch = "main",
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [Alias("WhatIf")]
    [switch]$DryRun
)

# Script configuration
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# Paths
$ScriptRoot = $PSScriptRoot
$ProjectRoot = Split-Path (Split-Path $ScriptRoot -Parent) -Parent
$ReleaseNotesDir = Join-Path $ProjectRoot "docs\ReleaseNotes"
$TempDir = Join-Path $env:TEMP "fabric-sync-$Version"

# Files and directories to exclude from sync
$ExcludePatterns = @(
    "scripts/_internal/*",
    "Workload/node_modules/*",
    ".git/*",
    ".vs/*",
    ".vscode/*",
    "*.tmp",
    "*.log",
    "build/*",
    "release/*",
    ".env.*"
)

#region Helper Functions

function Write-StepHeader {
    param([string]$Message)
    Write-Information "`n=== $Message ===" -InformationAction Continue
}

function Write-StepSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-StepWarning {
    param([string]$Message)
    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Write-StepError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-GitRepository {
    try {
        git status | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-GitRemoteUrl {
    param([string]$RemoteName = "origin")
    try {
        $remoteUrl = git remote get-url $RemoteName 2>$null
        return $remoteUrl
    }
    catch {
        return $null
    }
}

function Test-VersionFormat {
    param([string]$Version)
    # Allow YYYY.MM or YYYY.MM.P format
    return $Version -match '^\d{4}\.\d{1,2}(\.\d+)?$'
}

function Test-IsPatchVersion {
    param([string]$Version)
    # Check if version has patch number (YYYY.MM.P format)
    return $Version -match '^\d{4}\.\d{1,2}\.\d+$'
}

function Get-MainVersion {
    param([string]$Version)
    # Extract main version (YYYY.MM) from full version
    if ($Version -match '^(\d{4}\.\d{1,2})') {
        return $matches[1]
    }
    return $Version
}

function Test-ReleaseNotesExist {
    param([string]$Version)
    $releaseNotesPath = Get-ReleaseNotesPath $Version
    return Test-Path $releaseNotesPath
}

function Get-ReleaseNotesPath {
    param([string]$Version)
    # Extract year from version (format: YYYY.MM or YYYY.MM.P)
    $year = $Version.Split('.')[0]
    $yearFolder = Join-Path $ReleaseNotesDir $year
    return Join-Path $yearFolder "v$Version.md"
}

function Ensure-ReleaseNotesYearFolder {
    param([string]$Version)
    $year = $Version.Split('.')[0]
    $yearFolder = Join-Path $ReleaseNotesDir $year
    if (-not (Test-Path $yearFolder)) {
        Write-Information "Creating release notes folder for year: $year"
        New-Item -Path $yearFolder -ItemType Directory -Force | Out-Null
    }
    return $yearFolder
}

function Invoke-GitCommand {
    param(
        [string]$Command,
        [string]$WorkingDirectory = (Get-Location).Path,
        [switch]$SuppressOutput
    )
    
    try {
        Push-Location $WorkingDirectory
        if ($SuppressOutput) {
            $result = Invoke-Expression "git $Command" 2>$null
        } else {
            $result = Invoke-Expression "git $Command"
        }
        return $result
    }
    catch {
        throw "Git command failed: git $Command`nError: $_"
    }
    finally {
        Pop-Location
    }
}

function Copy-FilesWithExclusions {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string[]]$ExcludePatterns
    )
    
    Write-Information "Copying files from $SourcePath to $DestinationPath..."
    
    try {
        # Build robocopy arguments
        $robocopyArgs = @(
            $SourcePath
            $DestinationPath
            "/MIR"  # Mirror directory tree
            "/NFL"  # No file list
            "/NDL"  # No directory list
            "/NP"   # No progress
        )
        
        # Separate directories and files to exclude
        $excludeDirs = @()
        $excludeFiles = @()
        
        foreach ($pattern in $ExcludePatterns) {
            # Normalize path separators to backslashes for Windows
            $normalizedPattern = $pattern.Replace("/", "\")
            
            if ($normalizedPattern.EndsWith("\*")) {
                # Directory pattern - remove the \* suffix
                $dirPath = $normalizedPattern.Substring(0, $normalizedPattern.Length - 2)
                $excludeDirs += $dirPath
            } elseif ($normalizedPattern.Contains("\")) {
                # Path with directory - exclude the directory
                $dirPath = Split-Path $normalizedPattern -Parent
                if ($dirPath) {
                    $excludeDirs += $dirPath
                }
            } else {
                # File pattern (e.g., *.tmp, *.log)
                $excludeFiles += $normalizedPattern
            }
        }
        
        # Add directory exclusions
        if ($excludeDirs.Count -gt 0) {
            $robocopyArgs += "/XD"
            $robocopyArgs += $excludeDirs
        }
        
        # Add file exclusions
        if ($excludeFiles.Count -gt 0) {
            $robocopyArgs += "/XF"
            $robocopyArgs += $excludeFiles
        }
        
        Write-Information "Excluding directories: $($excludeDirs -join ', ')"
        Write-Information "Excluding file patterns: $($excludeFiles -join ', ')"
        
        $result = & robocopy @robocopyArgs
        
        # Robocopy exit codes: 0-7 are success, 8+ are errors
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
        
        # Remove specific excluded directories from destination that shouldn't exist in public repo
        # Don't remove .git, .vs, .vscode as these are excluded from copying but shouldn't be removed from destination
        $dirsToRemove = @("scripts\_internal", "Workload\node_modules", "build", "release")
        foreach ($dir in $dirsToRemove) {
            $fullPath = Join-Path $DestinationPath $dir
            if (Test-Path $fullPath) {
                Write-Information "Removing excluded directory: $dir"
                Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-StepSuccess "Files copied successfully"
    }
    catch {
        throw "File copy failed: $_"
    }
}

function Test-GitHubCLI {
    try {
        gh auth status | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

#endregion

#region Main Script

try {
    Write-StepHeader "Starting Sync Process for Version $Version"

    # Step 1: Validate environment
    Write-StepHeader "Step 1: Validating Environment"
    
    # Check if we're in a git repository
    if (-not (Test-GitRepository)) {
        throw "Current directory is not a Git repository"
    }
    Write-StepSuccess "Git repository detected"
    
    # Validate version format
    if (-not (Test-VersionFormat $Version)) {
        throw "Invalid version format. Expected format: YYYY.MM or YYYY.MM.P (e.g., 2025.11 or 2025.11.1)"
    }
    Write-StepSuccess "Version format is valid: $Version"
    
    # Check for release notes
    if (-not (Test-ReleaseNotesExist $Version)) {
        $releaseNotesPath = Get-ReleaseNotesPath $Version
        throw "Release notes not found at: $releaseNotesPath"
    }
    $releaseNotesPath = Get-ReleaseNotesPath $Version
    Write-StepSuccess "Release notes found: $releaseNotesPath"
    
    # Check GitHub CLI
    if (-not (Test-GitHubCLI)) {
        Write-StepWarning "GitHub CLI not authenticated. PR creation will be skipped."
        $skipPR = $true
    } else {
        Write-StepSuccess "GitHub CLI authenticated"
        $skipPR = $false
    }
    
    # Handle DryRun mode
    if ($DryRun) {
        $isPatch = Test-IsPatchVersion $Version
        if ($isPatch) {
            $mainVersion = Get-MainVersion $Version
            $releaseBranch = "dev/release/$mainVersion"
            $branchNote = "(patch version - uses existing release branch)"
        } else {
            $releaseBranch = "dev/release/$Version"
            $branchNote = "(main version - creates new release branch)"
        }
        
        Write-StepHeader "DRY RUN MODE - Showing what would be done:"
        Write-Information "✓ Version: $Version"
        Write-Information "✓ Release notes: $releaseNotesPath"
        Write-Information "✓ Public repo URL: $PublicRepoUrl"
        Write-Information "✓ Source branch (staging): $SourceBranch"
        Write-Information "✓ Release branch (public): $releaseBranch $branchNote"
        Write-Information "✓ Target branch (public): $TargetBranch"
        Write-Information "✓ Would sync files from: $ProjectRoot"
        Write-Information "✓ Would exclude patterns: $($ExcludePatterns -join ', ')"
        
        if (-not $skipPR) {
            Write-Information "✓ Would create Pull Request from $releaseBranch to $TargetBranch"
        } else {
            Write-Information "⚠ Would skip PR creation (GitHub CLI not available)"
        }
        
        Write-StepSuccess "DRY RUN completed - no changes made"
        return
    }
    
    # Determine public repository URL
    if ([string]::IsNullOrEmpty($PublicRepoUrl)) {
        $PublicRepoUrl = "https://github.com/$PublicRepoOwner/$PublicRepoName.git"
    }
    Write-Information "Public repository: $PublicRepoUrl"
    
    # Step 2: Prepare working directory
    Write-StepHeader "Step 2: Preparing Working Directory"
    
    if (Test-Path $TempDir) {
        Write-Information "Removing existing temp directory: $TempDir"
        Remove-Item $TempDir -Recurse -Force
    }
    
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
    Write-StepSuccess "Created working directory: $TempDir"
    
    # Step 3: Clone public repository
    Write-StepHeader "Step 3: Cloning Public Repository"
    
    $publicRepoDir = Join-Path $TempDir "public-repo"
    Invoke-GitCommand "clone $PublicRepoUrl `"$publicRepoDir`"" -WorkingDirectory $TempDir
    Write-StepSuccess "Cloned public repository"
    
    # Checkout or create dev/release branch in public repo
    Write-StepHeader "Step 3.1: Preparing Release Branch"
    
    # Determine which branch to use based on version type
    $isPatch = Test-IsPatchVersion $Version
    if ($isPatch) {
        # Patch versions use the main version's release branch (e.g., 2025.12.1 uses dev/release/2025.12)
        $mainVersion = Get-MainVersion $Version
        $releaseBranch = "dev/release/$mainVersion"
        Write-Information "Patch version detected - using release branch: $releaseBranch"
    } else {
        # Main versions create their own release branch (e.g., 2025.12 creates dev/release/2025.12)
        $releaseBranch = "dev/release/$Version"
        Write-Information "Main version detected - using release branch: $releaseBranch"
    }
    
    try {
        Push-Location $publicRepoDir
        
        # Check if release branch exists on remote
        $remoteBranchExists = $false
        $remoteBranchCheck = git ls-remote --heads origin $releaseBranch 2>&1
        if ($LASTEXITCODE -eq 0 -and $remoteBranchCheck) {
            $remoteBranchExists = $true
        }
        
        if ($remoteBranchExists) {
            # Checkout existing remote branch
            Write-Information "Checking out existing branch: $releaseBranch"
            git checkout $releaseBranch 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to checkout branch $releaseBranch"
            }
            git pull origin $releaseBranch 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull branch $releaseBranch"
            }
            Write-StepSuccess "Checked out existing release branch: $releaseBranch"
        }
        else {
            if ($isPatch) {
                Write-StepError "Release branch $releaseBranch does not exist for patch version $Version"
                throw "Patch versions require an existing release branch. Please create main version $mainVersion first."
            }
            # Create new branch from target branch (only for main versions)
            Write-Information "Creating new branch: $releaseBranch from origin/$TargetBranch"
            git checkout -b $releaseBranch origin/$TargetBranch 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create branch $releaseBranch from origin/$TargetBranch"
            }
            Write-StepSuccess "Created new release branch: $releaseBranch from $TargetBranch"
        }
    }
    finally {
        Pop-Location
    }
    
    # Step 4: Sync changes
    Write-StepHeader "Step 4: Syncing Changes"
    
    Copy-FilesWithExclusions -SourcePath $ProjectRoot -DestinationPath $publicRepoDir -ExcludePatterns $ExcludePatterns
    
    # Step 5: Commit changes
    Write-StepHeader "Step 5: Committing Changes"
    
    Invoke-GitCommand "add ." -WorkingDirectory $publicRepoDir
    
    # Check if there are any changes to commit
    $changes = Invoke-GitCommand "diff --cached --name-only" -WorkingDirectory $publicRepoDir
    if ([string]::IsNullOrWhiteSpace($changes)) {
        Write-StepWarning "No changes detected. Skipping commit and PR creation."
        return
    }
    
    $commitMessage = "Sync v$Version`n`nSynced changes from staging repository for version $Version"
    Invoke-GitCommand "commit -m `"$commitMessage`"" -WorkingDirectory $publicRepoDir
    Write-StepSuccess "Committed changes"
    
    # Step 6: Push release branch
    Write-StepHeader "Step 6: Pushing Release Branch"
    
    Push-Location $publicRepoDir
    try {
        # Try regular push first for new branches
        Write-Information "Pushing $releaseBranch to remote..."
        $pushOutput = git push origin $releaseBranch 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-StepSuccess "Pushed release branch to remote"
        } else {
            # Try force-with-lease for existing branches
            Write-Information "Regular push failed, trying force-with-lease..."
            $pushOutput = git push origin $releaseBranch --force-with-lease 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-StepSuccess "Pushed release branch to remote with force-with-lease"
            } else {
                Write-StepError "Failed to push release branch"
                Write-Error "Git output: $pushOutput"
                throw "Failed to push $releaseBranch to remote repository"
            }
        }
    }
    finally {
        Pop-Location
    }
    
    # Step 7: Create Pull Request
    Write-StepHeader "Step 7: Creating Pull Request"
    
    if (-not $skipPR) {
        try {
            Push-Location $publicRepoDir
            
            # Read release notes for PR body
            $releaseNotes = Get-Content $releaseNotesPath -Raw
            $prBody = @"
## Sync v$Version

This PR syncs changes from the staging repository for version $Version.

### Release Notes

$releaseNotes

### Changes Included
- Synced all changes from staging repository
- Excluded internal scripts and build artifacts
- Updated documentation and examples

### Checklist
- [x] Release notes added
- [x] Version validated
- [x] Changes synced from staging
- [ ] Tests pass
- [ ] Documentation reviewed
- [ ] Ready for merge

/cc @$PublicRepoOwner
"@
            
            # Open PR creation in browser (bypasses EMU restrictions)
            Write-Information "Opening PR creation in browser..."
            gh pr create --repo $PublicRepoOwner/$PublicRepoName --base $TargetBranch --head $releaseBranch --web
            if ($LASTEXITCODE -eq 0) {
                Write-StepSuccess "Opened PR creation page in browser"
                Write-Information "✓ Release branch: $releaseBranch"
                Write-Information "✓ Target branch: $TargetBranch"
                Write-Information "✓ Complete the PR creation in your browser"
            } else {
                Write-StepWarning "Failed to open browser"
                Write-Information "You can manually create a PR at:"
                Write-Information "https://github.com/$PublicRepoOwner/$PublicRepoName/compare/$TargetBranch...$releaseBranch"
            }
        }
        catch {
            Write-StepWarning "Failed to create PR: $_"
            Write-Information "You can manually create a PR from branch: $releaseBranch to $TargetBranch"
            Write-Information "Or use: gh pr create --repo $PublicRepoOwner/$PublicRepoName --base $TargetBranch --head $releaseBranch"
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Information "Skipping PR creation (GitHub CLI not available)"
        Write-Information "Manual PR creation required from branch: $releaseBranch to $TargetBranch"
    }
    
    # Step 8: Cleanup
    Write-StepHeader "Step 8: Cleanup"
    
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force
        Write-StepSuccess "Cleaned up temporary directory"
    }
    
    # Success summary
    Write-StepHeader "Sync Process Completed Successfully!"
    Write-Information "Version: $Version"
    Write-Information "Source Branch (staging): $SourceBranch"
    Write-Information "Release Branch (public): $releaseBranch"
    Write-Information "Target Branch (public): $TargetBranch"
    Write-Information "Public Repository: $PublicRepoUrl"
    
    if (-not $skipPR) {
        Write-Information "Pull Request: Check output above for status"
        Write-Information "⚠️  NEXT STEPS: If PR was created, review and merge. Otherwise create manually from $releaseBranch to $TargetBranch"
    } else {
        Write-Information "Pull Request: Manual creation required"
        Write-Information "⚠️  NEXT STEPS: Create PR manually from branch: $releaseBranch to $TargetBranch"
    }
    
}
catch {
    Write-StepError "Sync process failed: $_"
    
    # Cleanup on error
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}

#endregion