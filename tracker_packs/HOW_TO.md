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
| Key     | Value                                     |
|---------|-------------------------------------------|
| "name"  | String; name of the status                |
| "ttip"  | String; tooltip for the status to display |
| "color" | a [ColorName](#colors) string             |

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

## GUI Elements
GUI elements are used to visually create your tracker. Elements primarily fall into 2 categories, `Containers` and `Content`.

### GUI Column
| Key        | Value                                  |
|------------|----------------------------------------|
| "type"     | "Column"                               |
| "children" | Array of [GUI Elements](#gui-elements) |

Container. Arranges the elements vertically, one after another.

### GUI Row
| Key        | Value                                  |
|------------|----------------------------------------|
| "type"     | "Column"                               |
| "children" | Array of [GUI Elements](#gui-elements) |

Container. Arranges the elements horizontally, one after another.

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

### GUI LocationConsole
| Key           | Value                                               |
|---------------|-----------------------------------------------------|
| "type"        | "LocationConsole"                                   |
| "hint_status" | bool, if the `Hint Status` column should be visible |

Content. Displays a console-style, sortable, filterable list of all [Locations](#locations), and their currently determined [status](#statuses).

### GUI Empty Element
A completely empty dictionary `{}` is also a valid element- or rather, represents the LACK of an element. Useful as a placeholder while designing, so you can test while the gui is partly-completed.

## Colors
A color string can be any of the following:
- A color in the `archipelago.gd` `rich_colors` list (red, green, yellow, blue, magenta, cyan, white, black, slateblue, plum, salmon, orange, default)
- A color code in 6-digit hex format (ex. `FF0000` = red)
- A color name that Godot's `Color.from_string()` recognizes

## MapSpots
Currently unused. Intended for indicating a visual position on a map for the location. Format:
| Key  | Value                   |
|------|-------------------------|
| "id" | String, name of the map |
| "x"  | int, the x coordinate   |
| "y"  | int, the y coordinate   |

