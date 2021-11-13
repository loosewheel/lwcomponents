LWComponents
	by loosewheel


Licence
=======
Code licence:
LGPL 2.1

Media licence
CC BY-SA 3.0


Version
=======
0.1.2


Minetest Version
================
This mod was developed on version 5.4.0


Dependencies
============
default


Optional Dependencies
=====================
lwdrops
mesecons
digilines
unifieddyes
intllib
hopper


Installation
============
Copy the 'lwcomponents' folder to your mods folder.


Bug Report
==========
https://forum.minetest.net/viewtopic.php?f=9&t=27425


Description
===========
Various components for mesecons and digilines.



Dropper
-------
* This block is only available if digilines and/or mesecons are loaded.

Contains an inventory and drops an item on command. Also acts as a
digilines conductor. If the hopper mod is loaded, will take items from the
top and sides, and release them from the bottom.

UI

Channel - digilines channel of dropper.
Top 16 slot inventory - storage of items to drop.
Bottom 32 slot inventory - player's inventory.

Mesecons
	Drops the next item when power is turned on.

Digilines messages

"drop"
	Drops the next item. No drop if dropper is empty.

"drop <slot>"
	Drops 1 item from the given slot (1 to 16). No drop if slot is empty.
	eg. "drop 7"

"drop <itemname>"
	Drops 1 item of the given name. No drop if dropper does not contain the
	item.
	eg. "drop default:stone"

When an item is dropped a digilines message is sent with the dropper's
channel. The message is a table with the following keys:
{
	action = "drop",
	name = "<itemname>", -- name of dropped item
	slot = <slot> -- slot number the item was taken from (1 to 16).
}



Dispenser
---------
* This block is only available if digilines and/or mesecons are loaded.

Contains an inventory and dispenses (with velocity) an item on command.
Also acts as a digilines conductor. If the hopper mod is loaded, will take
items from the top and sides, and release them from the bottom.

Dispensers support mobs mod if loaded. Will spawn the entity from an 'egg'
if possible, or the 'egg' is dispensed. If a chicken egg is dispensed a
10% chance a chicken is dispensed instead.

UI

Channel - digilines channel of dispenser.
Top 16 slot inventory - storage of items to dispense.
Bottom 32 slot inventory - player's inventory.

Mesecons
	Dispenses the next item when power is turned on.

Digilines messages

"dispense"
	Dispenses the next item. No dispense if dispenser is empty.

"dispense <slot>"
	Dispenses 1 item from the given slot (1 to 16). No dispense if slot is
	empty.
	eg. "dispense 7"

"dispense <itemname>"
	Dispenses 1 item of the given name. No dispense if dispenser does not
	contain the item.
	eg. "dispense default:stone"

When an item is dropped a digilines message is sent with the dropper's
channel. The message is a table with the following keys:
{
	action = "dispense",
	name = "<itemname>", -- name of dropped item
	slot = <slot> -- slot number the item was taken from (1 to 16).
}



Collector
---------
* This block is only available if digilines is loaded.

Picks up dropped items in adjacent block, with optional filtering. Also
acts as a digilines conductor. If the hopper mod is loaded, will take items
from the top and sides, and release them from the bottom.

UI

Channel - digilines channel of collector.
Left 16 slot inventory - storage of picked up items.
Right 8 slot inventory - Filter list. Place what items should be picked
	up in this list. Leave empty to pick up all.
Bottom 32 slot inventory - player's inventory.

Digilines messages

"start"
	Start the collector.

"stop"
	Stop the collector.

When items are picked up a digilines message is sent with the collector's
channel. The message is a table with the following keys:
{
	action = "collect",
	name = "<itemname>", -- name of picked up items.
	count = <count> -- number of the item picked up.
}



Detector
--------
* This block is only available if digilines and/or mesecons are loaded.

Detects items or entities within a given radius. Also acts as a
digilines conductor.

UI

Channel - digilines channel of detector.
Radius - block distance from detector to detect.
Entities - if checked detects entities.
Players - if checked detects players.
Drops - if checked detects drops.
Nodes - if checked detects nodes.

mode:
	All - detects to radius in all directions, including diagonal.
	Forward - detects to radius directly in front of the detector (one block high).
	Up - detects to radius directly above the detector (one block wide).
	Down - detects to radius directly below the detector (one block wide).

Mesecons
	Mesecons power is turned on when something is detected, and turned off
	when nothing is detected.

Digilines messages

"start"
	Start the detector.

"stop"
	Stop the detector.

"radius <n>"
	Set radius of the detector. <n> should be a number from 1 to 5, and is
	trimmed to this range.

"entities <true|false>"
	Set detection of entities on or off.

"players <true|false>"
	Set detection of players on or off.

"drops <true|false>"
	Set detection of drops on or off.

"nodes <true|false>"
	Set detection of nodes on or off.

"mode all"
"mode forward"
"mode up"
"mode down"
	Set the detector's mode.

When items or entities are detected a digilines message is sent with the
detector's channel. A message is sent for each found item/entity. The
message is a table with the following keys:
{
	action = "detect",
	type = "<type>", -- will be "entity", "player", "drop" or "node"
	name = "<name>",
	label = "<label>",
	pos = { x = n, y = n, z = n },
	count = <count>,
	hp = <number>,
	height = <number>
}

type
	Will be "entity", "player", "drop" or "node".

name
	For "entity" the registered entity name.
	For "player" the player's name.
	For "drop" the registered item name.
	For "node" the registered item name.

label
	For "entity" the name tag text.
	For "player" the player's name.
	For "drop" the registered item name.
	For "node" the registered item name.

pos
	The relative position of the detected item/entity from the detector,
	facing the direction of the detector.
	+x = right
	-x = left
	+z = forward
	-z = behind
	+y = above
	-y = below

count
	The count of items for a "drop", or 1 for everything else.

hp
	Health points for players and entities. Zero for everything else.

height
	Height for players and entities. Zero for everything else. This is simply
	the top position of the object's collision box.


Siren
-----
* This block is only available if digilines and/or mesecons are loaded.

Plays a sound repeatedly while active. Also acts as a digilines conductor.

UI

Channel - digilines channel of siren.
Distance - block distance the sound can be heard (range 0 to 100).
Volume - volume the sound is played.
Sound - select Buzzer, Horn, Raid or Siren.

Mesecons
	Sound plays while mesecons power is applied.

Digilines messages

"start"
	Start the siren (turn on).

"stop"
	Stop the siren (turn off).

"distance <n>"
	Set block distance the sound can be heard. <n> should be a number
	from 1 to 100, and is trimmed to this range.

"volume <n>"
	Set the sound volume. <n> should be a number from 1 to 100, and is
	trimmed to this range.

"sound buzzer"
"sound horn"
"sound raid"
"sound siren"
	Set the sound of the siren.

"siren on"
	Activate the siren, if its on.

"siren off"
	deactivate the siren.



Puncher
-------
* This block is only available if digilines and/or mesecons are loaded.

Punches players or entities within a given reach. Also acts as a
digilines conductor.

UI

Channel - digilines channel of detector.
Reach - block distance from puncher to punch.
Entities - if checked punches entities.
Players - if checked punches players.

mode:
	Forward - punches to reach extent directly in front of the puncher (one block high).
	Up - detects to reach extent directly above the puncher (one block wide).
	Down - detects to reach extent directly below the puncher (one block wide).

Mesecons
	Punches the next item when power is turned on.

Digilines messages

"start"
	Start the puncher.

"stop"
	Stop the puncher.

"reach <n>"
	Set reach of the puncher. <n> should be a number from 1 to 5, and is
	trimmed to this range.

"entities <true|false>"
	Set punching of entities on or off.

"players <true|false>"
	Set punching of players on or off.

"mode forward"
"mode up"
"mode down"
	Set the puncher's mode.

"punch"
	Action a single punch if the puncher is turned on.

When a player or entity is punched a digilines message is sent with the
puncher's channel. The message is a table with the following keys:
{
	action = "punch",
	type = "<type>", -- will be "entity" or "player"
	name = "<name>",
	label = "<label>"
}

type
	Will be "entity" or "player".

name
	For "entity" the registered entity name.
	For "player" the player's name.

label
	For "entity" the name tag text.
	For "player" the player's name.



Player Button
-------------
* This block is only available if both digilines and digistuff are loaded.

When pressed sends a digilines message with the name of the player that
pressed the button.

The first time the button is right clicked a form opens to set the
digilines channel. After that right click presses the button. The
digilines cannot be changed after its set.

When the button is pressed a digilines message is sent with the button's
channel in the form:
{
	action = "player",
	name = <player name>
}



DigiSwitch
----------
* This block is only available if both digilines and mesecons are loaded.

Digiswitches act as both a digilines message target and a digilines cable,
as well as a mesecons power source. They can be placed beside each other
to form a bank, horizontally or vertically.

Right click the digiswitch to give it a channel.

Mesecon power can be delivered at 6 sides of the digiswitch, the adjacent
4 in the (x, z), above and below. Around the connector on these sides are a
colored border indicating the side. The sides are named "red", "green",
"blue", "yellow", "white" and "black".

The digilines message sent to the digiswitch dictates the action, "on" or
"off". The action can be followed with the side to act upon, separated by
a space. eg. "on white". If a side is stated only that side is acted upon.
If the side is omitted (or is invalid) all 6 sides are acted upon. If the
side name "switch" is give the power is supplied the same as a mesecons
switch (all horizontal sides, one below, this height and one above).



MoveFloor
---------
* This block is only available if mesecons and mesecons_mvps is loaded.

The MoveFloor block responds to a mesecons power source in the 4 horizontal
directions. If the power source is one higher the MoveFloor moves up to
that height. If the power source is one lower the MoveFloor moves down to
that height. Powering an adjacent block has no effect. The power source
should be turned off before another move or the MoveFloor will oscillate.

Any horizontally adjoining MoveFloor acts as a single block (only one
needs to be powered).

The MoveFloor will move up to 3 blocks stacked on it.

If using a DigiSwitch as the power source use the side name "switch" or
the MoveFloor will not move.



Solid Color Conductors
----------------------
* These blocks are only defined if mesecons and unifieddyes are loaded.

Provides 2 blocks that can be colored the same as Solid Color Block (with
the air brush) and is both a mesecons and digilines conductor.

The Solid Color Conductor block conducts in the 'default' directions and
the Solid Color Horizontal Conductor only conducts horizontally.



The following are also defined as variants of the original mod item, if
the relevant mod is loaded.
+	lwcomponents:touchscreen - digistuff:touchscreen as full sized node.
+	lwcomponents:panel - digistuff:panel as full sized node.



------------------------------------------------------------------------
