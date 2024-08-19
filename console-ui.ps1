[CmdletBinding()]
param(
	[Parameter(Mandatory=$true, HelpMessage="Name of the solution / base name for the project", Position=1)]
	[string]$name,
	[Parameter(Mandatory=$false, HelpMessage="Directory where the solution will be created off of", Position=2)]
	[string]$directory = (Join-Path $PSScriptRoot "demos")
)

$defaultDirectory = (Join-Path $PSScriptRoot "demos")

# if directory is defaultdirectory, create it if it doesn't exist
if ($directory -eq $defaultDirectory) {
	if (-not (Test-Path $directory)) {
		New-Item -Path $directory -ItemType Directory
	}
}

function CreateSolution(
	[System.IO.DirectoryInfo]$solutionDirectory, 
	[string]$solutionName) {

	Push-Location $solutionDirectory.FullName

	try {
		# create solution
		dotnet new sln -n $solutionName

		# create source project(s)
		$srcDirectory = $solutionDirectory.CreateSubdirectory("src")

		Set-Location $srcDirectory.FullName

		$consoleUiDirectory = $srcDirectory.CreateSubdirectory("$solutionName.ConsoleUi")
		
		Set-Location $consoleUiDirectory.FullName

		dotnet new console

		Set-Location $srcDirectory.FullName
		
		$apiDirectory = $srcDirectory.CreateSubdirectory("$solutionName.Api")

		Set-Location $apiDirectory.FullName

		dotnet new classlib
	
		# create test project(s)
		$testDirectory = $solutionDirectory.CreateSubdirectory("test")

		Set-Location $testDirectory.FullName

		$unitTestsDirectory = $testDirectory.CreateSubdirectory("$solutionName.UnitTests")

		Set-Location $unitTestsDirectory.FullName

		dotnet new xunit

		# add nuget package reference to FluentAssertions
		dotnet add $unitTestsDirectory package FluentAssertions

		Set-Location $solutionDirectory.FullName

		# add references between projects
		dotnet add $consoleUiDirectory reference $apiDirectory.FullName
		dotnet add $unitTestsDirectory reference $apiDirectory.FullName

		# add gitignore file
		dotnet new gitignore
		
		# add projects to solution
		dotnet sln add $consoleUiDirectory
		dotnet sln add $apiDirectory
		dotnet sln add $unitTestsDirectory
	}
	finally {
		Pop-Location
	}
}

$solutionName = $name

# make sure project name is not empty
if ([string]::IsNullOrEmpty($solutionName)) {
	Write-Error "Solution / base project name cannot be empty" -ForegroundColor Red
	exit
}

# create a directoryinfo object for the directory where the project will be created
$startingDirectory = New-Object System.IO.DirectoryInfo($directory)

# make sure the directory exists
if (-not $startingDirectory.Exists) {
	Write-Host "Starting directory: $directory"
	Write-Error "Starting directory does not exist" -ForegroundColor Red
	exit
}

# check if the solution directory already exists
$solutionDirectory = $startingDirectory.GetDirectories() | Where-Object { $_.Name -eq $solutionName }

# fail if the solution directory already exists
if ($solutionDirectory) {
	Write-Error "Solution directory already exists" -ForegroundColor Red
	exit
}

# create a new subdirectory for the solution
$solutionDirectory = $startingDirectory.CreateSubdirectory($solutionName)

# fail if the solution directory doesn't exist

if (-not $solutionDirectory.Exists) {
	Write-Error "Failed to create solution directory" -ForegroundColor Red
	exit
}

CreateSolution $solutionDirectory $solutionName




