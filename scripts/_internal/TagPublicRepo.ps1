<#
.SYNOPSIS
    Creates a Git tag in the public repository for a released version

.DESCRIPTION
    This script automates tagging releases in the public Microsoft Fabric Extensibility Toolkit repository:
    1. Validates the version number format
    2. Checks that release notes exist in the main branch of the public repository
    3. Creates an annotated Git tag (v{VERSION}) on the main branch
    4. Pushes the tag to the public repository

.PARAMETER Version
    The version number in format YYYY.MM or YYYY.MM.P (e.g., 2025.11 or 2025.11.1)
    Tags will be created as v{VERSION} (e.g., v2025.11 or v2025.11.1)

.PARAMETER PublicRepoUrl
    The URL of the public GitHub repository (default: https://github.com/microsoft/fabric-extensibility-toolkit.git)

.PARAMETER PublicRepoOwner
    The owner of the public repository (default: microsoft)

.PARAMETER PublicRepoName
    The name of the public repository (default: fabric-extensibility-toolkit)

.PARAMETER Branch
    The branch to tag in the public repository (default: main)

.PARAMETER Force
    Skip confirmation prompts and overwrite existing tags

.PARAMETER DryRun
    Perform a dry run - show what would be done without making changes (alias: WhatIf)

.EXAMPLE
    .\TagPublicRepo.ps1 -Version "2025.12"
    Creates tag v2025.12 on the main branch of the public repository

.EXAMPLE
    .\TagPublicRepo.ps1 -Version "2025.12.1"
    Creates tag v2025.12.1 on the main branch (patch release)

.EXAMPLE
    .\TagPublicRepo.ps1 -Version "2025.12" -DryRun
    Shows what would be done without creating the tag

.EXAMPLE
    .\TagPublicRepo.ps1 -Version "2025.12" -Force
    Overwrites tag v2025.12 if it already exists

.NOTES
    This script should be run AFTER the release PR has been merged to main.
    It verifies that the release notes file exists in the main branch before tagging.

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
    [string]$Branch = "main",
    
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
$TempDir = Join-Path $env:TEMP "fabric-tag-$Version"

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

function Test-VersionFormat {
    param([string]$Version)
    # Allow YYYY.MM or YYYY.MM.P format
    return $Version -match '^\d{4}\.\d{1,2}(\.\d+)?$'
}

function Get-ReleaseNotesPath {
    param([string]$Version)
    # Extract year from version (format: YYYY.MM or YYYY.MM.P)
    $year = $Version.Split('.')[0]
    return "docs/ReleaseNotes/$year/v$Version.md"
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
    Write-StepHeader "Starting Tag Process for Version $Version"

    # Step 1: Validate environment
    Write-StepHeader "Step 1: Validating Environment"
    
    # Validate version format
    if (-not (Test-VersionFormat $Version)) {
        throw "Invalid version format. Expected format: YYYY.MM or YYYY.MM.P (e.g., 2025.11 or 2025.11.1)"
    }
    Write-StepSuccess "Version format is valid: $Version"
    
    # Check GitHub CLI
    if (-not (Test-GitHubCLI)) {
        throw "GitHub CLI not authenticated. Please run 'gh auth login' first."
    }
    Write-StepSuccess "GitHub CLI authenticated"
    
    # Determine public repository URL
    if ([string]::IsNullOrEmpty($PublicRepoUrl)) {
        $PublicRepoUrl = "https://github.com/$PublicRepoOwner/$PublicRepoName.git"
    }
    Write-Information "Public repository: $PublicRepoUrl"
    
    # Step 2: Check if release notes exist in main branch
    Write-StepHeader "Step 2: Verifying Release Notes in Main Branch"
    
    $releaseNotesPath = Get-ReleaseNotesPath $Version
    Write-Information "Looking for release notes at: $releaseNotesPath"
    
    try {
        $response = gh api "repos/$PublicRepoOwner/$PublicRepoName/contents/$releaseNotesPath?ref=$Branch" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-StepSuccess "Release notes found in $Branch branch: $releaseNotesPath"
        } else {
            throw "Release notes not found"
        }
    }
    catch {
        Write-StepError "Release notes not found in $Branch branch: $releaseNotesPath"
        throw "Cannot create tag - release notes must be merged to $Branch first. Please complete the release PR merge before tagging."
    }
    
    # Step 3: Check if tag already exists
    Write-StepHeader "Step 3: Checking for Existing Tag"
    
    $tagName = "v$Version"
    $tagExists = $false
    
    try {
        $existingTag = gh api "repos/$PublicRepoOwner/$PublicRepoName/git/refs/tags/$tagName" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $tagExists = $true
            if ($Force) {
                Write-StepWarning "Tag $tagName already exists - will be overwritten (Force mode)"
            } else {
                Write-StepError "Tag $tagName already exists"
                throw "Tag $tagName already exists. Use -Force to overwrite."
            }
        }
    }
    catch {
        Write-StepSuccess "Tag $tagName does not exist - ready to create"
    }
    
    # Handle DryRun mode
    if ($DryRun) {
        Write-StepHeader "DRY RUN MODE - Showing what would be done:"
        Write-Information "✓ Version: $Version"
        Write-Information "✓ Tag name: $tagName"
        Write-Information "✓ Public repo: $PublicRepoUrl"
        Write-Information "✓ Branch: $Branch"
        Write-Information "✓ Release notes verified: $releaseNotesPath"
        
        if ($tagExists) {
            Write-Information "✓ Would overwrite existing tag (Force mode)"
        } else {
            Write-Information "✓ Would create new tag"
        }
        
        Write-StepSuccess "DRY RUN completed - no changes made"
        return
    }
    
    # Step 4: Clone repository and checkout branch
    Write-StepHeader "Step 4: Preparing Repository"
    
    if (Test-Path $TempDir) {
        Write-Information "Removing existing temp directory: $TempDir"
        Remove-Item $TempDir -Recurse -Force
    }
    
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
    $publicRepoDir = Join-Path $TempDir "public-repo"
    
    Write-Information "Cloning public repository..."
    git clone --depth 1 --branch $Branch $PublicRepoUrl $publicRepoDir 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository"
    }
    Write-StepSuccess "Cloned public repository and checked out $Branch branch"
    
    # Step 5: Create and push tag
    Write-StepHeader "Step 5: Creating Git Tag"
    
    Push-Location $publicRepoDir
    try {
        # Read release notes for tag message
        $releaseNotesFile = Join-Path $publicRepoDir $releaseNotesPath
        if (Test-Path $releaseNotesFile) {
            $releaseNotesContent = Get-Content $releaseNotesFile -Raw
            $tagMessage = "Release $Version`n`n$releaseNotesContent"
        } else {
            $tagMessage = "Release $Version"
        }
        
        # Create annotated tag
        Write-Information "Creating annotated tag: $tagName"
        
        if ($tagExists -and $Force) {
            # Delete existing tag locally and remotely
            git tag -d $tagName 2>&1 | Out-Null
            git push origin --delete $tagName 2>&1 | Out-Null
        }
        
        git tag -a $tagName -m $tagMessage
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create tag"
        }
        Write-StepSuccess "Created tag: $tagName"
        
        # Step 6: Push tag
        Write-StepHeader "Step 6: Pushing Tag to Remote"
        
        Write-Information "Pushing tag to remote..."
        if ($Force) {
            git push origin $tagName --force 2>&1 | Out-Null
        } else {
            git push origin $tagName 2>&1 | Out-Null
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push tag"
        }
        Write-StepSuccess "Pushed tag to remote repository"
    }
    finally {
        Pop-Location
    }
    
    # Step 7: Cleanup
    Write-StepHeader "Step 7: Cleanup"
    
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force
        Write-StepSuccess "Cleaned up temporary directory"
    }
    
    # Success summary
    Write-StepHeader "Tag Process Completed Successfully!"
    Write-Information "Version: $Version"
    Write-Information "Tag: $tagName"
    Write-Information "Branch: $Branch"
    Write-Information "Repository: $PublicRepoUrl"
    Write-Information "Tag URL: https://github.com/$PublicRepoOwner/$PublicRepoName/releases/tag/$tagName"
    Write-Information ""
    Write-Information "⚠️  NEXT STEPS: Create a GitHub Release from this tag at:"
    Write-Information "https://github.com/$PublicRepoOwner/$PublicRepoName/releases/new?tag=$tagName"
    
}
catch {
    Write-StepError "Tag process failed: $_"
    
    # Cleanup on error
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}

#endregion
