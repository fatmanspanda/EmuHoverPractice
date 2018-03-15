Emulator Lua script for BizHawk to practice hovering. Based off of [Hyphen-ated's tool of the same purpose](https://github.com/Hyphen-ated/HoverPractice).

## Using this tool
This script will only run on a recognized version of the [NMG practice hack](https://milde.no/lttp/). On starting, it will attempt to use the practice menu to teleport to Turtle Rock.

* The final area before Trinexx is an ideal place to practice hovering, as it contains a large gap to attempt crossing.
* If you fall (or really, take any damage) while this script is running, you will return to your original position.
* The script will also create an area on client that contains a graphical analysis of your hovering technique.
   * The bars above the axis indicate how long you held the `A` button.
   * The bars below the axis indicate how long you released the `A` button.
   * If either action lasted longer than what is allowed for a successful hover, its bar will turn from green to red.
* A line will be drawn and labelled to show your farthest hover each session.
* As a fun bonus, you will earn rupees for successful hover streaks. You will lose rupees for every time you fall. You are only eligible to gain rupees if you are hovering across a gap.

| Input | Action |
| ----- | ------ |
| `L`  | Clear graph |
| `R`  | Toggle rupee rewarding |
| `L` + `R` | Quit |

## Running Lua scripts
1. Download the latest source file from [the releases page](https://github.com/fatmanspanda/EmuHoverPractice/releases).
1. Take the file and place it in a folder you will remember. The default folder for Bizhawk Lua scripts is `\BizHawk-<version>\Lua`.
1. Run BizHawk and open the NMG practice hack.
1. Begin or resume a save file, and be in an idle position that allows you to use the practice menu.
1. Navigate to the Lua console from the menu: `Tools→Lua Console`
1. Open the script.
   * If you haven't used this script before, or its location has changed since moving, you can find it in file explorer by pressing `Ctrl+O`.
   * If you have used this script before, you can find it in the `Recent Scripts` submenu under the `File` menu.
1. On opening, the script will automatically run and take you to Turtle Rock.
   * Do not press any buttons while the script navigates through the practice menu.
1. Use a window size of `x3` or smaller to avoid lag.
