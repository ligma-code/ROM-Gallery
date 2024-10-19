<#
.SYNOPSIS
Cycles through ROMs in RetroArch at a set interval with no user input.

.DESCRIPTION
ROM-Gallery automatically cycles through ROMs in RetroArch with no user input. Configure which
cores you want to run and where your ROM files are located, and the script will go and build a
dynamic playlist then invoke RetroArch to play the ROMs one after the other, switching after a
set interval.

Required configuration:
- Set `network_cmd_enable = "true"` in your `retroarch.cfg`
- Configure these static vars to match your setup:
    - $RetroarchFolder
    - $CoreIndex

.LINK
https://github.com/ligma-code/ROM-Gallery

.NOTES
Version: 1.0
Date: 19/10/2024

Copyright (C) 2024 Michael G

This program is free software: you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation, either version 3 of the
License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not,
see <http://www.gnu.org/licenses/>.
#>

# --- Static vars ---
# RetroArch Paths
$RetroarchFolder = "C:\RetroArch-Win64"
$RetroarchExe = "$RetroarchFolder\retroarch.exe"
$CorePath = "$RetroarchFolder\cores"

# Cycle configuration
$CycleTime = 300 # Seconds
$MaxScriptRuntime = 60 # Minutes
$Countdown = 30 # Seconds
$Shuffle = $True
$Repeat = $True
$EqualiseRoms = $False
$Fullscreen = $True
$HideTerminal = $False
$KillExplorer = $False
$AutoShutdown = $False

# Index of cores to ROMs. Can contain one or many cores, each in its own "@{}" hash table
$CoreIndex = @(
    @{
        "dll"           = "snes9x2010_libretro.dll" # Core DLL
        "rom_path"      = "C:\Games\ROMs\SNES"      # Full path to ROM folder. Subfolders will be included.
        "extensions"    = ".smc,.sfc"               # Comma-separated list of ROM file extensions to search for
    }
    @{
        "dll"           = "mame_libretro.dll"
        "playlist"      = "C:\Games\ROMS\MAME\mame_playlist.txt"    # Playlist file from which to select ROMs
        "custom_cfg"    = "$RetroarchFolder\retroarch_mame.cfg"       # Optional custom config, otherwise retroarch.cfg assumed
    }
    @{
        "dll"           = "mupen64plus_next_libretro.dll"
        "rom_path"      = "C:\Games\ROMs\N64"
        "extensions"    = ".n64"
    }
)
# --- End of static vars

# --- Helper functions ---
function Hide-Terminal {
    param ($Hide)

    if ($Hide) {
        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '

        $Console = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($Console, 0) | Out-Null
    }
    else { return $Null }
}

function Check-NetworkCmd {
    param ($Core)

    $ConfigFile = if ($Core.ContainsKey('custom_cfg')) { $Core['custom_cfg'] } else { "$RetroarchFolder\retroarch.cfg" }
    
    $ConfigContent = Get-Content $ConfigFile
    if (-not ($ConfigContent | Select-String 'network_cmd_enable = "true"')) {
        Write-Warning "The 'network_cmd_enable = `"true`"' setting was not found in RetroArch config file. RetroArch will be force-terminated when cycling ROMs for this core. Configure setting in $ConfigFile to remove this message."
    }
}

function Handle-Explorer {
    param ($Kill)

    if ($Kill) {
        Write-Host "Killing explorer.exe"
        taskkill /F /IM explorer.exe
    } else {
        $Explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if (-not $Explorer) {
            Write-Host "Restarting explorer.exe"
            Start-Process explorer.exe
        }
    }
}

function Cull-Roms {
    param (
        $Playlist,
        $Count
    )

    $CulledList = New-Object System.Collections.Generic.List[System.Object]

    $i = 0
    foreach ($rom in $Playlist) {
        if (i -ge $count) { break }
        $CulledList.Add($rom)
        $i++
    }

    return $CulledList
}

function Check-MaxRuntime {
    param (
        $Stopwatch,
        $MaxRuntime
    )

    if ($Stopwatch.Elapsed -ge $MaxRuntime) {
        if ($AutoShutdown) {
            Write-Host "Max script time reached; shutting down PC."
            shutdown.exe /s /t 10
        } else {
            Write-Host "Max script time reached"
            Handle-Explorer $False
        }
        exit
    }
}

function Start-Countdown {
    param (
        [int]$Seconds
    )

    if ($Seconds -gt 0) {
        Write-Host "Invoking RetroArch in $Seconds seconds. Press Ctrl+C to quit."
        $Waiting = 0
        while ($Waiting -lt $Seconds) {
            Start-Sleep 1
            Write-Host -NoNewline "."
            $Waiting++
        }
    }
    Write-Host "`nRunning RetroArch"
}

function Get-Roms {
    param (
        [hashtable]$Core,
        [string]$CorePath
    )

    $TempList = New-Object System.Collections.Generic.List[System.Object]

    # Import playlist file
    if ($Core.ContainsKey("playlist")) {
        Write-Host "Custom playlist: $($Core['playlist'])`nImporting playlist contents"
        $CustomPlaylist = Get-Content -Path $($Core['playlist']) -ErrorAction Stop
        foreach ($line in $CustomPlaylist) {
            if (-Not (Test-Path $line -PathType Leaf)) {
                Write-Error "Error finding file $line"
                exit
            }
            $TempList.Add("$($Core['dll']), $line")
        }
    }
    # Or search for ROMs
    else {
        $ExtensionList = $Core['extensions'].Split(",").Trim()
        Write-Host "ROM Path: $($Core['rom_path'])`nExtensions: $ExtensionList`nSearching for ROMs"
        $Roms = Get-ChildItem -Path $Core['rom_path'] -File -Recurse | Where-Object {$_.extension -in $ExtensionList} | Select-Object FullName
        foreach ($Rom in $Roms) {
            $TempList.Add("$($Core['dll']), $($Rom.FullName)")
        }
    }

    return $TempList
}

function Generate-Playlist {

    Write-Host "`n---Generating ROM playlist`nGathering ROMs"
    $RomList = New-Object System.Collections.Generic.List[System.Object]
    $CoreRomCounts = @{}
    $TempListArray = @{}

    foreach ($Core in $CoreIndex) {
        $CoreDllPath = "$CorePath\$($Core['dll'])"
        if (-not (Test-Path $CoreDllPath)) {
            Write-Error "Error finding core at $CoreDllPath"
            exit
        }

        Write-Host "`nCore: $($Core['dll'])"
        Check-NetworkCmd $Core

        $TempList = Get-Roms -Core $Core -CorePath $CorePath
        Write-Host "Found $($TempList.Count) ROMs"

        $CoreRomCounts[$Core['dll']] = $TempList.Count
        $TempListArray[$Core['dll']] = $TempList
    }

    Write-Host "Finished gathering ROMs`n"
    
    # Equalise per-core ROMs if enabled
    if ($EqualiseRoms -and $CoreRomCounts.Count -gt 0) {
        $MinCount = ($CoreRomCounts.Values | Measure-Object -Minimum).Minimum
        Write-Host "Equalising ROMs per core. Culling to $MinCount ROMs each."

        foreach ($Core in $CoreIndex) {
            $CoreDll = $Core['dll']
            $TempList = $TempListArray[$CoreDll]
            if ($TempList.Count -gt $MinCount) {
                $TempListArray[$CoreDll] = $TempList | Get-Random -Count $MinCount
            }
        }
    }

    # Add final ROMs to the master list
    foreach ($CoreDll in $TempListArray.Keys) {
        $RomList.AddRange($TempListArray[$CoreDll])
    }

    if ($Shuffle) {
        Write-Host "Shuffling ROMs"
        $RomList = $RomList | Get-Random -Count $RomList.Count
    }

    Write-Host "Total playlist count: $($RomList.Count)"
    return $RomList
}

function Cycle-Rom {
    param (
        [string]$RunCore,
        [string]$RunRom,
        [string]$CustomConfig = $null
    )

    $Cmd = "& `"$RetroarchExe`" -L `"$CorePath\$RunCore`" `"$RunRom`""
    if ($CustomConfig) { $Cmd += " --config `"$CustomConfig`"" }
    if ($Fullscreen) { $Cmd += " -f" }

    Write-Host "---Running: $Cmd"
    Invoke-Expression $Cmd

    Start-Sleep $CycleTime

    # Send QUIT twice to close RetroArch then if it's still running do a force terminate
    & "$RetroarchExe" --command QUIT
    Start-Sleep -Milliseconds 500
    & "$RetroarchExe" --command QUIT
    Start-Sleep 1
    if (Get-Process -Name retroarch -ErrorAction SilentlyContinue) {
        Stop-Process -Name retroarch -Force
    }
}

# --- Main script ---
Write-Host "`n===Running Gallery script"
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$MaxRuntime = [TimeSpan]::FromMinutes($MaxScriptRuntime)

$Playlist = Generate-Playlist

$Details = @"

---Cycle configuration
Cycle time: $CycleTime seconds
Runtime limit: $MaxScriptRuntime minutes
Fullscreen: $Fullscreen
Shuffle: $Shuffle
Equalise ROMs: $EqualiseRoms
Shutdown on end: $AutoShutdown
Hide terminal: $HideTerminal
Kill explorer: $KillExplorer
"@
Write-Host $Details

Start-Countdown $Countdown
Hide-Terminal $HideTerminal
Handle-Explorer $KillExplorer

while ($true) {
    foreach ($Rom in $Playlist) {
        Check-MaxRuntime -Stopwatch $Stopwatch -MaxRuntime $MaxRuntime
        $Run = $Rom.split(",", 2)
        $Core = $CoreIndex | Where-Object { $_.dll -eq $Run[0] }
        $CustomConfig = if ($Core.ContainsKey("custom_cfg")) { $Core["custom_cfg"] } else { $null }
        
        Cycle-Rom -RunCore $Run[0] -RunRom $Run[1].TrimStart() -CustomConfig $CustomConfig
    }

    if (-not $Repeat) {
        break
    }

    # Shuffle before repeating
    if ($Shuffle) {$Playlist = Generate-Playlist }
}

Write-Host "Reached end of playlist. Quitting."
Handle-Explorer $False
Write-Host "Script finished."
