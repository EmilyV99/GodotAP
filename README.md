## The Project
GodotAP is a Godot project designed to be re-used in other Godot projects for [Archipelago Randomizer](archipelago.gg). It contains a basic implementation to handle the various network communications used by Archipelago, and a custom console that can be used for command input and to display messages from the server (in rich-text format, with tooltips)

## As a CommonClient
Running the project itself will produce just the basic console, designed as an alternative to the Archipelago Text Client (and a base for custom clients to be built from).

### How to Use
- Download and extract the [latest release](https://github.com/EmilyV99/GodotAP/releases)
- Run the `GodotAP_Client.exe`
  - Run `/help` to see all commands.
  - Run `/connect` to connect to a slot
  - Run `/disconnect` to exit a slot
- Use like a standard TextClient
  - Has autofill for all its own `/` commands, and some server `!` commands
    - This includes item/location name filling for '!hint' / '!hint_location'
  - Has a `Hints` tab.
    - LClick a column header to sort by that column (ties remain in previous order)
    - LClick the currently sorted-by column to invert its sort direction
    - RClick a column header that supports filtering (currently only `Status`) to open the filtering menu
      - `Found` hints are filtered out by default
    - Supports [New Hint Statuses](https://github.com/ArchipelagoMW/Archipelago/pull/3506), if connecting to a server that has those changes.
      - Clicking on a new status (of a hint that you are the `Receiving Player` for) will popup a dropdown of buttons, allowing you to select a new status to use.

## In a Project

### How to Use
The intended use is to include `godotap/autoloads/archipelago.tscn` as an AutoLoad for your own Godot project (along with including the entire `godotap` folder). This should enable you to connect to and interact with an Archipelago server via gdscript.

The CommonClient can be popped up as a separate window attached to your game, and can be extended with whatever new tabs and features you care to implement. Simply setting the `Ap Auto Open Console` checkbox on the `archipelago.tscn` root node will cause a default console window to open; or you can open a custom client by following steps similar to `godotap/ui/commonclient_main.gd`.

By listening to the appropriate signals in the `archipelago.gd` script and the `conn: ConnectionInfo` member inside it (which resets each time you reconnect), you can handle incoming messages from the server; and various functions are available to call for outgoing messages to the server.
