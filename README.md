# ROM-Gallery

## What is it?
ROM-Gallery is a PowerShell script that automatically cycles through ROMs in RetroArch with no user input. Configure which cores you want to run and where your ROM files are located, and the script will go and build a dynamic playlist then invoke RetroArch to play the ROMs one after the other, switching after a set interval.

The intended use case is to cycle through different retro games every few minutes, showcasing the demo mode or attract mode screens and iconic pixel art. Get it going on a spare screen and Windows PC, then let it display an ever-changing gallery of retro classics.

![alt text](https://github.com/ligma-code/ROM-Gallery/blob/main/image-rom-gallery-terminal.png)
## How does it work?
The script is quite basic in its core function. It builds a playlist of ROM files, then cycles through the ROMs by running a couple of commands on the RetroArch command-line interface and network command interface. RetroArch does not provide any command-line options to switch ROM or core while it's already running, so the script starts and quits RetroArch for each ROM.

Start:  `retroarch.exe -L <core DLL> <path to ROM> -F`

Quit:   `retroarch.exe --command QUIT`

The QUIT network command allows the script to close RetroArch gracefully instead of just terminating the process. Note that network commands are disabled by default and must be enabled in the RetroArch configuration file. The script will force-terminate RetroArch if the QUIT command doesn't succeed.

## I just want to get it running!
This assumes you already have RetroArch installed and configured with cores.

1. Download the `rom-gallery.ps1` script
2. Set `network_cmd_enable = "true"` in \<RetroArch install dir\>\retroarch.cfg
3. Set these static variables in the script (refer to [Script configuration](https://github.com/ligma-code/ROM-Gallery/new/main?filename=README.md#script-configuration) below for more details):
	- `$CoreIndex`
	- `$RetroarchPath`
4. Open PowerShell and navigate to the script folder, then run `rom-gallery.ps1`

Note unsigned PowerShell scripts must be allowed. Do a web search for 'powershell set execution policy' for more info.

## Script configuration
This section provides information on the static variables that can be configured to customise the script to your requirements.

`$RetroarchPath` and `$CoreIndex` **must** be configured for your particular setup. The other variables' default values can be left alone or customised to your taste.

#### $RetroarchPath
Full path to your RetroArch install folder.

*Example:*

`$RetroarchPath = "C:\RetroArch-Win64"`

#### $CoreIndex
This is an array of one or more hash tables, one hash table (i.e. pair of "{ }" curly brackets) per core/system. Key-value pairs define which Libretro core file to use and where to find its ROM files.

The dll key is mandatory for each core, but usage of the other keys depends on whether you wish to have the script search for ROM files or import a playlist file. See [ROM selection](https://github.com/ligma-code/ROM-Gallery/new/main?filename=README.md#rom-selection) for more information about these options.

Keys:

- `dll`: the core DLL that corresponds to the Libretro system core. You can find the core DLL filenames under your \<RetroArch install dir\>\cores folder.
- `rom_path`: full path to ROM folder to search. Search is recursive.
- `extensions`: comma-separated list of ROM file extensions for the core. Must be included when using rom_path key.
- `playlist`: full path to custom playlist file. `rom_path` and `extensions` keys will be ignored if this key is included. Refer to [ROM selection](https://github.com/ligma-code/ROM-Gallery/new/main?filename=README.md#rom-selection) for more details.
- `custom_cfg` : (optional) custom RetroArch configuration file for the core. If not provided, the default retroarch.cfg config is used.

Example:
```
$CoreIndex = @(
    @{
		"dll"           = "snes9x2010_libretro.dll"
		"rom_path"      = "C:\Games\ROMs\SNES"
		"extensions"    = ".smc,.sfc"
	}
	@{
		"dll"           = "mednafen_saturn_libretro.dll"
		"rom_path"      = "C:\Games\ROMs\Saturn"
		"extensions"    = ".cue"
	}
	@{
		"dll"           = "mame_libretro.dll"
		"playlist"      = "C:\Games\ROMs\MAME\mame_playlist.txt"
		"custom_cfg"    = "$RetroarchPath\retroarch_mame.cfg"
	}
)
```

### Other static variables
| Variable | Description |
| ---------- | ----------- |
| `$RetroarchExe` | Path to retroarch.exe. This should not need to be modified. |
| `$CorePath` | Path to cores subfolder. This should not need to be modified. |
| `$CycleTime` | The interval in [int] seconds between cycling ROMs. |
| `$MaxScriptRuntime` | Maximum runtime in [int] minutes before the script exits. Exit occurs on the next ROM cycle after time limit reached. |
| `$Countdown` | Wait in [int] seconds before invoking first ROM, allowing time to check output or quit. `0` will skip the wait. |
| `$Shuffle` | Shuffle the ROM playlist. If the playlist repeats it will reshuffle. `$True` or `$False`|
| `$Repeat` | Repeat the playlist when the end is reached. `$True` or `$False`|
| `$EqualiseRoms` | Ensures all cores have an equal number of ROMs in the playlist by culling larger ROM lists to match the smallest list. `$True` or `$False`|
| `$Fullscreen` | Run RetroArch in fullscreen mode. `$True` for fullscreen or `$False` for windowed. |
| `$HideTerminal` | Minimise the PowerShell terminal after invoking RetroArch for a cleaner background between ROMs. `$True` or `$False`|
| `$KillExplorer` | Terminate explorer.exe (the Windows GUI shell) for a cleaner background between ROMs. `$True` or `$False`|
| `$AutoShutdown` | Automatically shutdown the PC after reaching the end of the playlist or maximum script runtime. `$True` or `$False`|

## ROM selection

### ROM search
This is probably the easier method to use to select ROMs, provided you have your ROMs split into different folders by system. If you add or remove ROMs from the target folder the script will pick up the changes the next time it runs.

Set `rom_path` to the system's ROM folder, and in `extensions` set the file extensions of the relevant ROM files. The script will do a recursive search for ROMs under that folder and add them to the playlist. `extensions` may contain multiple file extensions in a comma-separated string, e.g. `".sfc,.smc"` for SNES.

*Example:*
```
"rom_path"   = "C:\Games\ROMs\Saturn"
"extensions" = ".cue,.chd"
```
For systems that use ROMs split into multiple files consider which file extensions you include in `extensions`. You may end up with the same ROM added to the playlist multiple times, or run into issues trying to launch. For example, say a PSX ROM has three .bin files and one .cue file, if both ".bin" and ".cue" were included in `extensions` then that ROM would be added to the playlist four times. In this case you should only include the .cue extension. Some cores might fail to launch if you pass the wrong file.

### Playlist files
If you wish to select specific ROMs for a core instead of finding all ROMs under a given folder, you can supply a playlist text file using the `playlist` key. The file should contain a list of full ROM paths, one per line. Each core requires its own playlist file.

*Example key:*

`"playlist" = "C:\Games\ROMs\MAME\mame_playlist.txt"`

*Example contents:*
```
C:\Games\ROMs\MAME\mslug.zip
C:\Games\ROMs\MAME\tmnt.zip
C:\Games\ROMs\MAME\outrun.zip
```
This is particularly useful when using split or merged ROM sets for MAME, and dependencies between ROMs mean you cannot split them into separate folders.

If you include the `playlist` key, the `rom_path` and `extensions` keys will be ignored.

## Advanced setup

### Seamless ROM transitions
You can make transitions between ROMs appear more seamless with these configuration settings:
- Disable RetroArch on-screen notifications: Settings → User Interface → On-Screen Notifications → Off
- Set `$HideTerminal` to `$True` to hide the PowerShell terminal
- Set `$KillExplorer` to `$True` to remove the desktop background, icons and taskbar.
Note that if you do this you may have to open Task Manager (Ctrl + Shift + Escape) to kill the script and restart explorer.t

### Scheduled task
If you have a dedicated PC on which to run the script, you can invoke it automatically on login with a scheduled task for a fully hands-off experience. See this guide for details on running PowerShell scripts via Task Scheduler: [How to Automate PowerShell Scripts with Task Scheduler](https://blog.netwrix.com/how-to-automate-powershell-scripts-with-task-scheduler)

## Troubleshooting
### How do I stop the script while it's running?
With difficulty! You need to terminate the script from the PowerShell terminal by pressing Ctrl + C, but PowerShell will not see this keystroke if another application has focus. If RetroArch is running you need to quit it or switch windows (Alt + Tab) to bring up the PowerShell terminal. Alternatively, you can kill the PowerShell process from Task Manager (Ctrl + Shift + Escape).

### I want to play the game that's currently running. How do I stop it cycling to the next game?
See above.

### PowerShell error: '*.\rom-gallery.ps1 cannot be loaded because running scripts is disabled on this system*'
Running unsigned PowerShell scripts is disabled on Windows by default. The easiest way to allow the script to run is to open an administrative PowerShell prompt and run `Set-ExecutionPolicy Unrestricted`. Note this may make your system vulnerable to malicious scripts.

See this Microsoft documentation for more information: [About Execution Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1)

### RetroArch fails to start, or starts but then closes/crashes straight away
There could be any number of reasons why RetroArch is doing this. You can manually check whether the ROM can be invoked on the command-line by using this syntax:

`retroarch.exe -L <path to core DLL> <path to ROM file>`

*Example:*
```
PS C:\Users\ligma> cd C:\RetroArch-Win64
PS C:\ROM-Gallery\RetroArch-Win64> .\retroarch.exe -L .\cores\mupen64plus_next_libretro.dll "C:\Games\ROMs\Superman 64.n64`
```

The best way to troubleshoot RetroArch issues is to enable verbose logging, which will log what's happening and any errors encountered. This can be enabled in the RetroArch menu under Settings → Logging → Logging Verbosity → On, and additionally you might want to enable Log To File on the same page.

### RetroArch opens but does not run the ROM
See above.

### Script reports "Found 0 ROMs"
Double-check `rom_path` and `extensions` keys are set correctly inside `$CoreIndex`. Refer to [ROM selection](https://github.com/ligma-code/ROM-Gallery/new/main?filename=README.md#rom-selection) for more details.

### The ROM starts then pauses
The RetroArch window may have lost focus and paused itself. You can disable this setting under Settings → User Interface → Pause Content When Not Active → No.

### After a ROM stops it takes too long to start the next one.
This is RetroArch taking a long time to launch the ROM. Disabling complex shaders or using a faster PC will reduce the load time. Additionally, large ROM files, or loading ROMs over a slow network connection may just take longer.

### The playlist is favouring ROMs from one core over another
Setting `$Shuffle` to `$True` will mix the ROMs into random order. If the playlist has more ROMs for one core than another, it will play that core's ROMs more often due to mathematical probability.

You can equalise the number of ROMs each system has in the playlist by setting `$EqualiseRoms` to `$True`. This will find the core with the fewest ROMs, and for any other cores it will cull ROMs, at random, from the playlist until the number of ROMs match.

### I have multiple monitors. Can I change the monitor on which RetroArch opens?
RetroArch does not provide a method for changing the target screen in fullscreen mode; it will always open on the Main display per Windows Display Settings.

If you are happy to run in windowed mode (set `$Fullscreen` to `$False` in the script) then you can enable the Remember Window Position And Size setting in RetroArch and place the window on the target screen. This can be enabled under Settings → Video → Windowed Mode → Remember Window Position And Size → On.

## Compatibility
I see no reason why the script wouldn't work any recent version of RetroArch and Windows. But for reference the script has been tested on:
- Windows 10 and Windows 11
- PowerShell versions 5.1 and 7
- RetroArch v1.19.1 64-bit

PowerShell can be installed on MacOS and some Linux distributions but the script will not work without some tweaks.

## Feedback
When I started writing the script, I thought I would just knock something up in a couple of hours and call it a day. Then I had an idea for a little feature to add, and then another, and then another... and now I've spent way too long on this and I need to stop. Now that it's become a bit more than the quick and dirty script I originally intended, I figure it's decent enough to stick on GitHub and maybe others will find it useful too.

That being said, the script does what I want it to do, and I don’t have plans for further updates. To put it plainly, I don't plan on spending time providing support. I’ve written this README in the hope that it provides enough instructions and details to help users get started and be able to reconfigure the script to suit their preferences. If you run into any issues and wish to contact me, or have any sort of feedback, or want to submit a pull request, I may or may not respond.

If you have ideas for features or improvements, feel free to duplicate the project and make it your own.

## Release history
- 19 OCT 2024 - Initial release
