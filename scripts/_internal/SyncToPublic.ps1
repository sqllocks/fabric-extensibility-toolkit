<#
.SYNOPSIS
    Syncs changes from staging repository to public repository and creates a Pull Request

.DESCRIPTION
    This script automates syncing changes to the public Microsoft Fabric Extensibility Toolkit repository:
    1. Validates the version number format
    2. Checks for corresponding release notes
    3. Creates/updates sync branch (dev/sync/{VERSION})
    4. Syncs changes to public repository (with exclusions)
    5. Creates a Pull Request for review

.PARAMETER Version
    The version number in format YYYY.MM.P (e.g., 2025.11.1)

.PARAMETER PublicRepoUrl
    The URL of the public GitHub repository (default: https://github.com/microsoft/fabric-extensibility-toolkit.git)

.PARAMETER PublicRepoOwner
    The owner of the public repository (default: microsoft)

.PARAMETER PublicRepoName
    The name of the public repository (default: fabric-extensibility-toolkit)

.PARAMETER SourceBranch
    The source branch to sync from (default: main)

.PARAMETER TargetBranch
    The target branch for the Pull Request (default: main)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER DryRun
    Perform a dry run - show what would be done without making changes (alias: WhatIf)

.EXAMPLE
    .\SyncToPublic.ps1 -Version "2025.11"
    Syncs changes and creates PR for version 2025.11

.EXAMPLE
    .\SyncToPublic.ps1 -Version "2025.11" -DryRun
    Shows what would be done without making changes

.EXAMPLE
    .\SyncToPublic.ps1 -Version "2025.11.1" -Force
    Syncs patch release changes with confirmation prompts skipped

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
    
    # Create robocopy exclude file
    $excludeFile = Join-Path $env:TEMP "robocopy-exclude-$(Get-Random).txt"
    $ExcludePatterns | Out-File -FilePath $excludeFile -Encoding UTF8
    
    try {
        # Use robocopy for efficient copying with exclusions
        $robocopyArgs = @(
            $SourcePath
            $DestinationPath
            "/MIR"  # Mirror directory tree
            "/XF"   # Exclude files
            "/XD"   # Exclude directories
        )
        
        # Add exclude patterns
        foreach ($pattern in $ExcludePatterns) {
            if ($pattern.EndsWith("/*")) {
                $robocopyArgs += "/XD"
                $robocopyArgs += $pattern.Replace("/*", "")
            } else {
                $robocopyArgs += "/XF"
                $robocopyArgs += $pattern
            }
        }
        
        $robocopyArgs += "/NFL" # No file list
        $robocopyArgs += "/NDL" # No directory list
        $robocopyArgs += "/NP"  # No progress
        
        $result = & robocopy @robocopyArgs
        
        # Robocopy exit codes: 0-7 are success, 8+ are errors
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed with exit code $LASTEXITCODE"
        }
        
        Write-StepSuccess "Files copied successfully"
    }
    finally {
        if (Test-Path $excludeFile) {
            Remove-Item $excludeFile -Force
        }
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

function New-SyncBranch {
    param(
        [string]$Version,
        [string]$WorkingDirectory,
        [string]$TargetBranch = "main"
    )
    
    $branchName = "dev/sync/$Version"
    
    try {
        Push-Location $WorkingDirectory
        
        # First, ensure we're on the target branch and it's up to date
        try {
            Invoke-GitCommand "checkout $TargetBranch" -WorkingDirectory $WorkingDirectory
            Invoke-GitCommand "pull origin $TargetBranch" -WorkingDirectory $WorkingDirectory
            Write-StepSuccess "Updated $TargetBranch branch"
        }
        catch {
            Write-StepWarning "Could not update $TargetBranch branch: $_"
        }
        
        # Check if branch already exists locally
        $localBranchExists = (git branch --list $branchName) -ne ""
        
        # Check if branch exists on remote
        $remoteBranchExists = $false
        try {
            git ls-remote --heads origin $branchName | Out-Null
            $remoteBranchExists = $LASTEXITCODE -eq 0
        }
        catch {
            $remoteBranchExists = $false
        }
        
        if ($localBranchExists) {
            # Switch to existing local branch
            Invoke-GitCommand "checkout $branchName" -WorkingDirectory $WorkingDirectory
            Write-StepSuccess "Switched to existing branch: $branchName"
            
            if ($remoteBranchExists) {
                # Pull latest changes from remote
                try {
                    Invoke-GitCommand "pull origin $branchName" -WorkingDirectory $WorkingDirectory
                    Write-StepSuccess "Updated branch with latest changes from remote"
                }
                catch {
                    Write-StepWarning "Could not pull from remote branch, continuing with local version"
                }
            }
            
            # Merge latest changes from target branch
            try {
                Invoke-GitCommand "merge origin/$TargetBranch" -WorkingDirectory $WorkingDirectory
                Write-StepSuccess "Merged latest changes from $TargetBranch"
            }
            catch {
                Write-StepWarning "Could not merge from $TargetBranch, continuing with current state"
            }
        }
        elseif ($remoteBranchExists) {
            # Checkout remote branch
            Invoke-GitCommand "checkout -b $branchName origin/$branchName" -WorkingDirectory $WorkingDirectory
            Write-StepSuccess "Checked out existing remote branch: $branchName"
            
            # Merge latest changes from target branch
            try {
                Invoke-GitCommand "merge origin/$TargetBranch" -WorkingDirectory $WorkingDirectory
                Write-StepSuccess "Merged latest changes from $TargetBranch"
            }
            catch {
                Write-StepWarning "Could not merge from $TargetBranch, continuing with current state"
            }
        }
        else {
            # Create new branch from target branch
            Invoke-GitCommand "checkout -b $branchName origin/$TargetBranch" -WorkingDirectory $WorkingDirectory
            Write-StepSuccess "Created new sync branch: $branchName from $TargetBranch"
        }
        
        return $branchName
    }
    catch {
        throw "Failed to create/checkout sync branch: $_"
    }
    finally {
        Pop-Location
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
        Write-StepHeader "DRY RUN MODE - Showing what would be done:"
        Write-Information "✓ Version: $Version"
        Write-Information "✓ Release notes: $releaseNotesPath"
        Write-Information "✓ Public repo URL: $PublicRepoUrl"
        Write-Information "✓ Sync branch: dev/sync/$Version"
        Write-Information "✓ Target branch: $TargetBranch"
        Write-Information "✓ Would sync files from: $ProjectRoot"
        Write-Information "✓ Would exclude patterns: $($ExcludePatterns -join ', ')"
        
        if (-not $skipPR) {
            Write-Information "✓ Would create Pull Request with GitHub CLI"
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
    
    # Create or checkout sync branch
    $syncBranch = New-SyncBranch -Version $Version -WorkingDirectory $publicRepoDir -TargetBranch $TargetBranch
    
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
    
    # Step 6: Push branch
    Write-StepHeader "Step 6: Pushing Sync Branch"
    
    try {
        # Use --force-with-lease to safely update existing branches
        Invoke-GitCommand "push origin $syncBranch --force-with-lease" -WorkingDirectory $publicRepoDir
        Write-StepSuccess "Pushed sync branch to remote"
    }
    catch {
        try {
            # Fallback to regular push for new branches
            Invoke-GitCommand "push origin $syncBranch" -WorkingDirectory $publicRepoDir
            Write-StepSuccess "Pushed new sync branch to remote"
        }
        catch {
            Write-StepError "Failed to push sync branch: $_"
            throw
        }
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
            
            $prTitle = "Sync v$Version"
            gh pr create --title $prTitle --body $prBody --base $TargetBranch --head $syncBranch
            Write-StepSuccess "Pull Request created successfully"
            Write-Information "✓ Sync branch: $syncBranch"
            Write-Information "✓ Target for merge: $TargetBranch"
            Write-Information "✓ PR must be reviewed and merged to complete sync"
        }
        catch {
            Write-StepError "Failed to create PR: $_"
            Write-Information "You can manually create a PR from branch: $syncBranch"
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Information "Skipping PR creation (GitHub CLI not available)"
        Write-Information "Manual PR creation required from branch: $syncBranch"
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
    Write-Information "Sync Branch: $syncBranch"
    Write-Information "Public Repository: $PublicRepoUrl"
    
    if (-not $skipPR) {
        Write-Information "Pull Request: Created automatically and ready for review"
        Write-Information "⚠️  NEXT STEPS: Review and merge the PR to sync changes to public repository"
    } else {
        Write-Information "Pull Request: Manual creation required"
        Write-Information "⚠️  NEXT STEPS: Create PR manually from branch: $syncBranch"
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