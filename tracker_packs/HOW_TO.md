# Creating a TrackerPack
Creating a TrackerPack is relatively simple, though encoding all of the game logic is fairly tedious, so it isn't the fastest process.

To start, you can look at an existing pack (including the `example_pack.json`, which is a mostly-blank template to start from). Each of the various fields will be detailed here. You can also simply start with a blank json file, and fill in the necessary fields as defined here.

## TrackerPack Root
From the root of the trackerpack, there are several elements which must be included.

### game
The name of your game. (String, should EXACTLY match the Archipelago name)

### type
The type of TrackerPack you are creating. For now, just leave this as "DATA_PACK".

### description_bar
Optional. A description that shows in the top bar of the Tracker tab, next to the `Enable Tracking` switch.
### description_ttip
Optional. A tooltip that shows when hovering over the `description_bar` area.

### GUI
A [GUI Element](#gui-elements), which acts as the root of the page. This element is displayed below the top bar of the tracker, and takes up the full width of the window, and the full height below the tracker bar.

### statuses
An array of Status objects. A Status object is defined as:
| Key         | Value                                                        |
|-------------|--------------------------------------------------------------|
| "name"      | String; name of the status                                   |
| "ttip"      | String; tooltip for the status to display                    |
| "color"     | a [ColorName](#colors) string for displaying the status name |
| "map_color" | a [ColorName](#colors) string for displaying the map square  |

The statuses named "Found", "Unknown", "Unreachable", and "Not Found" have special meaning.

The statuses "Found", "Unknown", "Unreachable", "Not Found", "Out of Logic", and "Reachable" will be added as defaults if they are missing from your file.

The order statuses are placed in here determines their evaluation order, as well as their sort order. Found locations will always evaluate as `Found`, but otherwise it will evaluate as the LAST status in this order that has its conditions met (thus why `Reachable` is last by default, as it is generally the highest priority rule).

### locations
An array of Location objects. A Location object is defined as:
| Key         | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| "id"        | String; Archipelago name of the location. (alt: int, Archipelago ID of the location) |
| "visname"   | Optional, String; A more readable name to display to the user                        |
| "map_spots" | Optional, An array of [MapSpot](#mapspots) objects                                   |
| status_name | A [Rule](#rules) representing a status's logical state. (Can be repeated for each [status](#statuses)) |

### named_rules
A dictionary of [Rules](#rules), keyed by arbitrary names.

### named_values
A dictionary of [ValueNodes](#value-nodes), keyed by arbitrary names

### variables
A dictionary of values, keyed by arbitrary names.
Each entry should be a `Variable`, defined as:
| Key             | Value                                                  |
|-----------------|--------------------------------------------------------|
| "value"         | int; the starting value                                |
| "item_triggers" | A dictionary of Archipelago Item Names to `Operation`s |

and an `Operation` is defined as:
| Key     | Value                   |
|---------|-------------------------|
| "type"  | "+", "-", "*", "/"      |
| "value" | int, the second operand |

For each item listed in `item_triggers`, the corresponding `Operation` will be applied toe the `value` of the `Variable`.

#### Example: variables
```
"variables" = {
	"Money": {
		"value": 0,
		"item_triggers": {
			"5 Dollars": {
				"type": "+",
				"value": 5
			},
			"20 Dollars": {
				"type": "+",
				"value": 20
			},
			"50 Dollars": {
				"type": "+",
				"value": 50
			}
		}
	}
}
```
In this case, the value of "Money" will be the total number of dollars obtained from the Archipelago items named "5 Dollars", "10 Dollars", and "20 Dollars".

## Rules
Rules are how the tracker interacts directly with the game state. They come in a variety of forms, each with their own formats.

### Boolean Rule
The simplest of all rules. Doesn't even need a dictionary, you can just use `true` or `false` as a rule. And as should be obvious, the return value of the rule is just that boolean.

### Named Rule
The second-simplest rule. Doesn't even need a dictionary, just supply a String. Make sure the string appears as a key in [the named rule list](#named_rules). The return value of this rule, is the return value of THAT rule. Useful to reduce duplication, if the same rule is used in a bunch of places.

### All Rule
Acts as a simple way to `AND` rules together.
| Key     | Value                    |
|---------|--------------------------|
| "type"  | "ALL"                    |
| "rules" | Array of [Rules](#rules) |

Return value is `true` if the return value of ALL rules in `rules` are `true`, and `false` otherwise.

### Any Rule
Acts as a simple way to `OR` rules together.
| Key     | Value                    |
|---------|--------------------------|
| "type"  | "ANY"                    |
| "rules" | Array of [Rules](#rules) |

Return value is `true` if the return value of ANY rule in `rules` is `true`, and `false` otherwise.

### Item Rule
Used to check the items the slot has received.
| Key     | Value                         |
|---------|-------------------------------|
| "type"  | "ITEM"                        |
| "value" | String, Archipelago item name |
| "count" | Optional(default 1) int       |

Return value is `true` if the slot has received at least `count` items matching the `value` item name, and `false` otherwise.

### Variable Rule
Used to check the value of [variables](#variables)
| Key     | Value                            |
|---------|----------------------------------|
| "type"  | "VAR"                            |
| "name"  | String, name of the variable     |
| "op"    | ">", "<", ">=", "<=", "==", "!=" |
| "value" | int, the second operand          |

#### Example: variable reading
To continue from the [prior example](#example-variables):
```
{
	"type": "VAR",
	"name": "Money",
	"op": ">=",
	"value": 100
}
```
This is a rule which would return `true` if the `Money` variable is at least `100`. Unlike, say, making an [item rule](#item-rule) for "50 Dollars" with "count=2", this would catch other combinations, such as receiving "20 Dollars" 5 times, etc, without needing to manually spell out every possible combination.

### Location Collected Rule
This rule isn't really that useful, though it is used internally by the tracker system to update locations to the `Found` status. You can make use of it if you find a purpose for it.
| Key     | Value                                                                                |
|---------|--------------------------------------------------------------------------------------|
| "type"  | "LOCATION_COLLECTED"                                                                 |
| "id"    | String; Archipelago name of the location. (alt: int, Archipelago ID of the location) |

Returns `true` if the specified location has been `Found`.

## Value Nodes
Value nodes function like [Rules](#rules), but instead of returning a boolean, they return an int.

## GUI Elements
GUI elements are used to visually create your tracker. Elements primarily fall into 2 categories, `Containers` and `Content`.

The following keys are valid on EVERY GUI Node (though only `type` is required, all others have defaults)
| Key             | Value                                                     |
|-----------------|-----------------------------------------------------------|
| "type"          | String, determines the type of node (null for Empty node) |
| "halign"        | A [SizeFlag](#sizeflag) value for horizontal growth       |
| "valign"        | A [SizeFlag](#sizeflag) value for vertical growth         |
| "stretch_ratio" | A float that weightedly affects `EXPAND` SizeFlags        |
| "draw_filter"   | A [DrawFilter](#drawfilter) value. Default "INHERIT".     |

### GUI Column
| Key        | Value                                  |
|------------|----------------------------------------|
| "type"     | "Column"                               |
| "children" | Array of [GUI Elements](#gui-elements) |
| "spacing"  | Optional int, spacing between elements |

Container. Arranges the elements vertically, one after another.

### GUI Row
| Key        | Value                                  |
|------------|----------------------------------------|
| "type"     | "Column"                               |
| "children" | Array of [GUI Elements](#gui-elements) |
| "spacing"  | Optional int, spacing between elements |

Container. Arranges the elements horizontally, one after another.

### GUI Grid
| Key        | Value                                             |
|------------|---------------------------------------------------|
| "type"     | "Grid"                                            |
| "columns"  | int, the number of columns                        |
| "children" | Array of [GUI Elements](#gui-elements)            |
| "hspacing" | Optional int, horizontal spacing between elements |
| "vspacing" | Optional int, vertical spacing between elements   |

Container. Arranges the elements in a grid, with the first element in the top left, subsequent elements to the right of that, until it reaches the specified number of columns. After the column limit is reached, the next child starts a new row.

### GUI HSplit
| Key        | Value                                         |
|------------|-----------------------------------------------|
| "type"     | "HSplit"                                      |
| "children" | Array of [GUI Elements](#gui-elements), MAX 2 |

Container. Arranges the elements horizontally, with a resizer bar between them.

### GUI VSplit
| Key        | Value                                         |
|------------|-----------------------------------------------|
| "type"     | "VSplit"                                      |
| "children" | Array of [GUI Elements](#gui-elements), MAX 2 |

Container. Arranges the elements vertically, with a resizer bar between them.

### GUI Margin
| Key      | Value                                               |
|----------|-----------------------------------------------------|
| "type"   | "Margin"                                            |
| "top"    | int, top margin in pixels                           |
| "bottom" | int, bottom margin in pixels                        |
| "left"   | int, left margin in pixels                          |
| "right"  | int, right margin in pixels                         |
| "color"  | [Color string](#colors) to fill the outer area with |
| "child"  | [GUI Element](#gui-elements)                        |

Container. Arranges the single element, with a colored area outside of it.

### GUI Tabs
| Key      | Value                                                |
|----------|------------------------------------------------------|
| "type"   | "Tabs"                                               |
| "tabs"   | Dictionary of names to [GUI Elements](#gui-elements) |

Container. Displays a tab for each element, with the name displayed on the tab handle.

### GUI Label
| Key      | Value                                                |
|----------|------------------------------------------------------|
| "type"   | "Label"                                              |
| "text"   | String, The text to display                          |
| "size"   | int, the font size                                   |
| "color"  | Optional, [ColorName](#colors) to use for the label. |

Content. Draws the specified text.

### GUI Icon

| Key              | Value                                                    |
|------------------|----------------------------------------------------------|
| "type"           | "Icon"                                                   |
| "image"          | String, relative path from the json to the image         |
| "width"          | Optional int, set the width of the icon                  |
| "height"         | Optional int, set the height of the icon                 |
| "tooltip"        | Optional String, tooltip to show when hovered over       |
| "modulate_color" | Optional, [ColorName](#colors) to modulate the image by. |
| "value"          | Optionally relate a value to the icon. See below.        |

Content. Displays an image.

- Size defaults to image source size, if width/height are not specified. If only one is specified, the other defaults to maintain the source aspect ratio.
- The default "modulate_color" is "white", which indicates "no change" to the image.

"value" should contain the following information, if given:
| Key              | Value                                                           |
|------------------|-----------------------------------------------------------------|
| "val"            | [ValueNode](#value-nodes) giving the value.                     |
| "gray_under"     | Optional, [ValueNode](#value-nodes) giving the grayscale value. |
| "max"            | Optional, [ValueNode](#value-nodes) giving the max value.       |
| "show_max"       | Optional, bool. If true, always shows the max value.            |
| "color"          | Optional, [ColorName](#colors) to use for the number display.   |
| "max_color"      | Optional, [ColorName](#colors) to use instead when val >= max.  |

- If the "val" is less than "gray_under", the icon will be grayscaled.
- If the "val" is 0 or "max" is 1, no number will be shown (unless "show_max" is true)
- If "show_max" is true, the value will be shown as a fraction, ex. `1 / 5`, `2 / 2` instead of just showing the current value.
- If no gray_under is given, it uses a default of 1.
- If no max is given, it uses a default of 999.
- The default "color" is "white", and the default "max_color" is "green".

### GUI LocationConsole
| Key           | Value                                               |
|---------------|-----------------------------------------------------|
| "type"        | "LocationConsole"                                   |
| "hint_status" | bool, if the `Hint Status` column should be visible |

Content. Displays a console-style, sortable, filterable list of all [Locations](#locations), and their currently determined [status](#statuses).

### GUI LocationMap
| Key                    | Value                                                                      |
|------------------------|----------------------------------------------------------------------------|
| "type"                 | "LocationMap"                                                              |
| "id"                   | String, name of this map (matching [MapSpot](#mapspots))                   |
| "image"                | String, relative path from the json to the image                           |
| "some_reachable_color" | a [ColorName](#colors) for when some but not all locations are 'Reachable' |
| "square_size"          | int, the size of the squares on the map                                    |

Content. Displays a map image. Any [MapSpots](#mapspots) on locations with an id matching the LocationMap's id will appear as colored squares on the map, whose color is determined as follows:
- The color will match the `map_color` of the highest-priority status of all locations sharing the [MapSpot](#mapspots).
- If that status is `Reachable`, there is an exception: Unless every location at the [MapSpot](#mapspots) is `Found` or `Reachable`, the `some_reachable_color` will be used in place of `Reachable`'s `map_color`.
- `Found` is not considered highest-priority for the coloring order, despite it being highest-priority when determining a location's status. This generally means `Found` will be the lowest priority, thus only showing its' color when every location at the [MapSpot](#mapspots) is `Found`.

When hovering over a square, it will show the list of locations at that spot, and their respective statuses. `Found` locations / fully `Found` squares can be hidden via an option in Settings.

### GUI ItemConsole
| Key            | Value                                       |
|----------------|---------------------------------------------|
| "type"         | "ItemConsole"                               |
| "values"       | An array of objects, as defined below       |
| "show_index"   | bool, if the 'Index' column should appear   |
| "show_totals"  | bool, if the 'Totals' column should appear  |
| "show_percent" | bool, if the 'Percent' column should appear |

Content. Displays a console-style list of values. Sortable by the 'Index', 'Name', 'Count', 'Totals', and 'Percent' columns, and filterable by the item flags (on the 'Name' column).

The 'Index' column shows the number index in the values array of the item (allowing it to remain sorted in the order you list the values in, to provide a "defined order").

The 'Count' and 'Total' columns values are determined by [ValueNodes](#value-nodes) in the objects (see below). The 'Percent' column will automatically calculate 'count * 100 / total'.

#### ItemConsole "values" Objects
Values objects can either be "Items" or "Display Variables"
| Key        | Value                                                                                 |
|------------|---------------------------------------------------------------------------------------|
| "type"     | "ITEM"                                                                                |
| "name"     | Archipelago Item Name                                                                 |
| "total"    | Optional, [ValueNode](#value-nodes) indicating the total number of this item present. |
| "flags"    | The archipelago item flags to use by default (if none have been received). (0 = filler, 1 = progression, 2 = useful, 4 = trap) |

| Key        | Value                                                                                      |
|------------|--------------------------------------------------------------------------------------------|
| "type"     | "DISPLAY_VAR"                                                                              |
| "name"     | Display name (arbitrary)                                                                   |
| "count"    | [ValueNode](#value-nodes) indicating the current value of this display variable.           |
| "total"    | Optional, [ValueNode](#value-nodes) indicating a "total" number for this display variable. |
| "tooltip"  | Optional, String tooltip to display                                                        |
| "color"    | Optional, [ColorName](#colors) to use for the display name                                 |


### GUI Empty Element
A completely empty dictionary `{}` is also a valid element- or rather, represents the LACK of an element. Useful as a placeholder while designing, so you can test while the gui is partly-completed.

Empty elements can take the properties listed under [GUI Elements](#gui-elements) that apply for all nodes, as well as the following extra optional properties:
| Key      | Value                                     |
|----------|-------------------------------------------|
| "width"  | Optional int, sets the width of the node  |
| "height" | Optional int, sets the height of the node |

## Colors
A color string can be any of the following:
- A color in the `archipelago.gd` `rich_colors` list (red, green, yellow, blue, magenta, cyan, white, black, slateblue, plum, salmon, orange, default)
- A color code in 6-digit hex format (ex. `FF0000` = red)
- A color name that Godot's `Color.from_string()` recognizes

## SizeFlag
A string representing a particular type of growth.
| Flag            | Effect                                                                                 |
|-----------------|----------------------------------------------------------------------------------------|
| "FILL"          | Grows to fit its' container, passively.                                                |
| "EXPAND"        | Grows to fit its' container, pushing other nodes. Other 'EXPAND' nodes will push back. |
| "EXPAND_FILL"   | Both "FILL" and "EXPAND"?                                                              |
| "SHRINK_BEGIN"  | Shrinks towards the top/left edge                                                      |
| "SHRINK_CENTER" | Shrinks towards the center                                                             |
| "SHRINK_END"    | Shrinks towards the bottom/right edge                                                  |

## DrawFilter
A string representing a draw filter mode.
| Value     | Effect                                                             |
|-----------|--------------------------------------------------------------------|
| "INHERIT" | Uses the draw filter of the parent node.                           |
| "LINEAR"  | Draws with a linear filter (good for high-res, bad for pixel art)  |
| "NEAREST" | Drwas with a nearest filter (good for pixel art, bad for high-res) |

## MapSpots
Intended for indicating a visual position on a [LocationMap](#gui-locationmap) for the location. Format:
| Key  | Value                                               |
|------|-----------------------------------------------------|
| "id" | String, name of the [LocationMap](#gui-locationmap) |
| "x"  | int, the x coordinate                               |
| "y"  | int, the y coordinate                               |


