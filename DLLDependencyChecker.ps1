
# Program: DLL Dependency Checker
# Description: A PowerShell script to analyze a DLL file for its dependencies using dumpbin and check if these dependencies are available in the system's PATH.
# Author: [Your Name]

# Function to display the title
function Display-Title {
    $title = @"
==========================================
          DLL Dependency Checker          
==========================================
Analyze DLL files for missing dependencies
------------------------------------------
"@
    Write-Host $title -ForegroundColor Cyan
}

# Function to log messages with a timestamp
function Log-Message {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$level] $message"
    
    # Output to console
    Write-Host $logEntry
    
    # Optionally, log to file
    if ($logFilePath) {
        Add-Content -Path $logFilePath -Value $logEntry
    }
}

# Function to check if a file exists
function Check-FileExists {
    param (
        [string]$filePath
    )

    if (-Not (Test-Path $filePath)) {
        Log-Message "File not found: $filePath" "ERROR"
        throw "File not found: $filePath"
    } else {
        Log-Message "File found: $filePath" "INFO"
    }
}

# Function to run dumpbin and extract dependencies
function Get-DLLDependencies {
    param (
        [string]$dumpbinPath,
        [string]$dllPath
    )
    
    Log-Message "Running dumpbin on $dllPath" "INFO"
    try {
        $output = & "$dumpbinPath" /DEPENDENTS "$dllPath" 2>&1
        Log-Message "Dumpbin output:" "DEBUG"
        $output | ForEach-Object { Log-Message $_ "DEBUG" }

        if ($output -match "Dump of file") {
            Log-Message "Successfully analyzed $dllPath" "INFO"
            $dlls = $output | Select-String -Pattern "\.dll" | ForEach-Object { $_.ToString().Trim() }
            if ($dlls.Count -eq 0) {
                Log-Message "No DLL dependencies found in the output." "WARN"
            }
            return $dlls
        } else {
            Log-Message "Failed to analyze $dllPath. dumpbin output: $output" "ERROR"
            throw "Failed to analyze $dllPath"
        }
    } catch {
        Log-Message $_.Exception.Message "ERROR"
        throw
    }
}

# Function to check if a DLL exists in the system paths
function Check-DLLInPaths {
    param (
        [string[]]$dlls,
        [string[]]$paths
    )

    $results = @()

    foreach ($dll in $dlls) {
        if ($dll -eq "") { continue }  # Skip empty lines
        $found = $false
        foreach ($path in $paths) {
            if ($path -ne '' -and (Test-Path $path)) {
                $fullPath = Join-Path -Path $path -ChildPath $dll
                if (Test-Path $fullPath) {
                    $results += [PSCustomObject]@{
                        DLLName = $dll
                        Status  = "Found"
                        Path    = $fullPath
                    }
                    $found = $true
                    break
                }
            }
        }
        if (-Not $found) {
            $results += [PSCustomObject]@{
                DLLName = $dll
                Status  = "Missing"
                Path    = ""
            }
        }
    }

    return $results
}

# Function to display results in a table with colors
function Display-Results {
    param (
        [array]$results
    )

    $results | ForEach-Object {
        if ($_.Status -eq "Found") {
            Write-Host "$($_.DLLName) - $($_.Status) - $($_.Path)" -ForegroundColor Green
        } else {
            Write-Host "$($_.DLLName) - $($_.Status)" -ForegroundColor Red
        }
    }
}

# Main script execution
Display-Title

# Define the path to the DLL you want to analyze
$dllPath = "C:\gstreamer\1.0\msvc_x86_64\lib\gstreamer-1.0\gstd3d12.dll"

# Define the path to dumpbin.exe (ensure this is correct for your environment)
$dumpbinPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.40.33807\bin\Hostx64\x64\dumpbin.exe"

try {
    # Check if the DLL and dumpbin paths exist
    Check-FileExists -filePath $dllPath
    Check-FileExists -filePath $dumpbinPath

    # Get DLL dependencies using dumpbin
    $dlls = Get-DLLDependencies -dumpbinPath $dumpbinPath -dllPath $dllPath

    # Validate that dependencies were found
    if ($dlls.Count -eq 0) {
        Log-Message "No dependencies found for $dllPath." "WARN"
    } else {
        # Get the system PATH environment variable and split it into individual paths
        $paths = $env:PATH -split ';'

        # Check each DLL in system paths
        $results = Check-DLLInPaths -dlls $dlls -paths $paths

        # Display results in a table with colors
        Display-Results -results $results
    }

    Log-Message "Dependency check completed." "INFO"

} catch {
    Log-Message "Script execution failed: $_" "ERROR"
    exit 1
}
