Emulator Lua script for BizHawk to practice hovering. Based off of [Hyphen-ated's tool of the same purpose](https://github.com/Hyphen-ated/HoverPractice); with help from [raekuul](https://github.com/raekuul) and myramong.

## Using this tool
This script will only run itself on a recognized version of the [NMG practice hack](https://milde.no/lttp/). On starting, it will look in the directory of the script for `HoverPractice.State`.

* `HoverPractice.State` is a save state that will position you outside of Trinexx's room, on the bottom-most pixel of the platform, facing south.
* The final area before Trinexx is an ideal place to practice hovering, as it contains a long vertical gap to attempt crossing.
* If you fall (or really, take any damage) while this script is running, it will immediately load the save state.
* The script will also create a new window that contains a graphical analysis of your hovering technique.
   * The bars above the axis indicate how long you held the `A` button.
   * The bars below the axis indicate how long you released the `A` button.
   * If either action lasted longer than what is allowed for a successful hover, its bar will turn from green to red.
* To terminate this script without navigating to the Lua console, press `L+R` together in game.

## Running Lua scripts
1. Download the latest files from [the releases page](https://github.com/fatmanspanda/EmuHoverPractice/releases).
1. Extract the files and place them in the same folder. The default folder for Bizhawk Lua scripts is `\BizHawk-<version>\Lua`.
1. Run BizHawk and open the NMG practice hack.
1. Navigate to the Lua console from the menu: `Tools→Lua Console`
1. Open the script.
   * If you haven't used this script before, or its location has changed since moving, you can find it in file explorer by pressing `Ctrl+O`.
   * If you have used this script before, you can find it in the `Recent Scripts` submenu under the `File` menu.
1. On opening, the script will automatically run.
1. The script can be toggled or stopped from the graphical menu.