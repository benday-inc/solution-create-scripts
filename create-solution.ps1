[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, HelpMessage = "Project type (console, web, webapi)", Position = 1)]
	[ValidateSet("console", "web", "webapi")]
	[string]$projectType,
	[Parameter(Mandatory = $true, HelpMessage = "Name of the solution / base name for the project", Position = 2)]
	[string]$name,
	[Parameter(Mandatory = $false, HelpMessage = "Directory where the solution will be created off of", Position = 2)]
	[string]$directory = (Join-Path $PSScriptRoot "demos")
)

$directoryAtStartOfScript = $PWD

class SolutionInfo {
	[string] $Name
	[System.Collections.Generic.List[ProjectInfo]] $Projects
	[System.Collections.Generic.List[ProjectReference]] $ProjectReferences

	SolutionInfo() {
		$this.Projects = [System.Collections.Generic.List[ProjectInfo]]::new()
		$this.ProjectReferences = [System.Collections.Generic.List[ProjectReference]]::new()
	}

	[ProjectInfo] AddProject([string]$shortName, [string]$projectType, [string]$folderName, [string]$projectName) {
		$project = [ProjectInfo]::new()
		$project.ShortName = $shortName
		$project.ProjectType = $projectType
		$project.FolderName = $folderName
		$project.ProjectName = $projectName

		$this.Projects.Add($project)

		return $project
	}

	[ProjectReference] AddProjectReference([string]$fromProjectShortName, [string]$toProjectShortName) {
		$projectReference = [ProjectReference]::new()
		$projectReference.FromProjectShortName = $fromProjectShortName
		$projectReference.ToProjectShortName = $toProjectShortName

		$this.ProjectReferences.Add($projectReference)

		return $projectReference
	}
}

class ProjectInfo {
	[string] $ShortName
	[string] $ProjectType
	[string] $FolderName
	[string] $ProjectName
}

class ProjectReference {
	[string] $FromProjectShortName
	[string] $ToProjectShortName
}

$solutionInfo = [SolutionInfo]::new()
$solutionInfo.Name = $name

if ($projectType -eq "console") {
	$consoleUiProject = $solutionInfo.AddProject("console", "console", "src", "$name.ConsoleUi")
	$apiProject = $solutionInfo.AddProject("api", "classlib", "src", "$name.Api")
	$unitTestsProject = $solutionInfo.AddProject("unittests", "xunit", "test", "$name.UnitTests")

	$solutionInfo.AddProjectReference($consoleUiProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($unitTestsProject.ShortName, $apiProject.ShortName)
}
elseif ($projectType -eq "web") {
	$webProject = $solutionInfo.AddProject("web", "web", "src", "$name.Web")
	$apiProject = $solutionInfo.AddProject("api", "classlib", "src", "$name.Api")
	$unitTestsProject = $solutionInfo.AddProject("unittests", "xunit", "test", "$name.UnitTests")
	$integrationTestsProject = $solutionInfo.AddProject("integrationtests", "xunit", "test", "$name.IntegrationTests")

	$solutionInfo.AddProjectReference($webProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($unitTestsProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($unitTestsProject.ShortName, $webProject.ShortName)
	$solutionInfo.AddProjectReference($integrationTestsProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($integrationTestsProject.ShortName, $webProject.ShortName)
}
elseif ($projectType -eq "webapi") {
	$webProject = $solutionInfo.AddProject("webapi", "webapi", "src", "$name.WebApi")
	$apiProject = $solutionInfo.AddProject("api", "classlib", "src", "$name.Api")
	$unitTestsProject = $solutionInfo.AddProject("unittests", "xunit", "test", "$name.UnitTests")
	$integrationTestsProject = $solutionInfo.AddProject("integrationtests", "xunit", "test", "$name.IntegrationTests")

	$solutionInfo.AddProjectReference($webProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($unitTestsProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($unitTestsProject.ShortName, $webProject.ShortName)
	$solutionInfo.AddProjectReference($integrationTestsProject.ShortName, $apiProject.ShortName)
	$solutionInfo.AddProjectReference($integrationTestsProject.ShortName, $webProject.ShortName)
}
else {
	Write-Error "Invalid project type"
	exit
}

$defaultDirectory = (Join-Path $PSScriptRoot "demos")

# if directory is defaultdirectory, create it if it doesn't exist
if ($directory -eq $defaultDirectory) {
	if (-not (Test-Path $directory)) {
		New-Item -Path $directory -ItemType Directory
	}
}

# make sure project name is not empty
if ([string]::IsNullOrEmpty($solutionInfo.Name)) {
	Write-Error "Solution / base project name cannot be empty"
	exit
}

# create a directoryinfo object for the directory where the project will be created
$startingDirectory = New-Object System.IO.DirectoryInfo($directory)

# make sure the directory exists
if (-not $startingDirectory.Exists) {
	Write-Host "Starting directory: $directory"
	Write-Error "Starting directory does not exist"
	exit
}

# check if the solution directory already exists
$solutionDirectory = $startingDirectory.GetDirectories() | Where-Object { $_.Name -eq $solutionInfo.Name }

# fail if the solution directory already exists
if ($solutionDirectory) {
	Write-Error "Solution directory already exists"
	exit
}

# create a new subdirectory for the solution
$solutionDirectory = $startingDirectory.CreateSubdirectory($solutionInfo.Name)

# fail if the solution directory doesn't exist

if (-not $solutionDirectory.Exists) {
	Write-Error "Failed to create solution directory"
	exit
}

Set-Location $solutionDirectory.FullName

Write-Host "Creating solution in $solutionDirectory..."

# create the solution
dotnet new sln -n $solutionInfo.Name

Write-Host "Creating projects..."

foreach ($project in $solutionInfo.Projects) {
	Write-Host "Creating project $($project.ProjectName)..."

	$parentFolder = Join-Path $solutionDirectory $project.FolderName

	if (-not (Test-Path $parentFolder)) {
		New-Item -Path $parentFolder -ItemType Directory
	}
	
	Set-Location $parentFolder

	$projectDirectory = Join-Path $parentFolder $project.ProjectName

	if (-not (Test-Path $projectDirectory)) {
		New-Item -Path $projectDirectory -ItemType Directory
	}

	Set-Location $projectDirectory

	dotnet new $project.ProjectType
}

Set-Location $solutionDirectory

Write-Host "Adding project references..."

foreach ($projectReference in $solutionInfo.ProjectReferences) {
	Write-Host "Adding reference from $($projectReference.FromProjectShortName) to $($projectReference.ToProjectShortName)..."

	$fromProjectInfo = $solutionInfo.Projects | Where-Object { $_.ShortName -eq $projectReference.FromProjectShortName }
	$toProjectInfo = $solutionInfo.Projects | Where-Object { $_.ShortName -eq $projectReference.ToProjectShortName }

	# if either project is not found, exit
	if (-not $fromProjectInfo -or -not $toProjectInfo) {
		Write-Error "Project to or from not found"
		exit
	}

	$fromParentFolder = Join-Path $solutionDirectory $fromProjectInfo.FolderName
	$toParentFolder = Join-Path $solutionDirectory $toProjectInfo.FolderName

	$fromProjectDirectory = Join-Path $fromParentFolder $fromProjectInfo.ProjectName
	$toProjectDirectory = Join-Path $toParentFolder $toProjectInfo.ProjectName

	dotnet add $fromProjectDirectory reference $toProjectDirectory
}

Set-Location $solutionDirectory

Write-Host "Adding projects to solution..."

# add projects to solution
foreach ($project in $solutionInfo.Projects) {
	$parentFolder = Join-Path $solutionDirectory $project.FolderName
	$projectDirectory = Join-Path $parentFolder $project.ProjectName

	dotnet sln add $projectDirectory
}

Write-Host "Solution created in $solutionDirectory"

Set-Location $directoryAtStartOfScript



