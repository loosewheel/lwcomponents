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
0.1.31


Minetest Version
================
This mod was developed on version 5.4.0


Dependencies
============
default


Optional Dependencies
=====================
mesecons
digilines
unifieddyes
intllib
hopper
digistuff
pipeworks
lwwires


Installation
============
Copy the 'lwcomponents' folder to your mods folder.


Bug Report
==========
https://forum.minetest.net/viewtopic.php?f=9&t=27425


Description
===========
Various components for mesecons and digilines.

*	Dropper, drops an item on command.
*	Dispenser, dispenses (with velocity) an item on command.
*	Collector, picks up dropped items in adjacent block, with optional filtering.
*	Detector, detects items or entities within a given radius.
*	Siren, plays a sound repeatedly while active.
*	Puncher, punches players or entities within a given reach.
*	Player button, sends digilines message with player name.
*	Breaker, digs the nodes directly in front.
*	Deployer, places the nodes directly in front.
*	Destroyer, automated trash.
*	Hologram, projects a hologram above the hologram node.
*	Fan, blows any entity, player or drop in front of the fan.
*	Conduit, connected in a circuit to move items.
*	Cannon, shoots an item on command with directional aiming (plus 3 shells).
*	Double (optionally single) reach pistons and sticky pistons.
*	Digilines Switch, digilines controlled mesecons power.
*	Movefloor, similar to vertical mesecons movestone.
*	Camera, takes a representative image.
*	Storage, indexed storage units.
*	Crafter, crafts by recipe or by item, and can pull from storage units.
*	Hoppers, that are more compatible with this mod.
*	Force Field Generator, repels players and mobs within a radius.
*	Mesecons Through Wire, transmits through 1 to 2 solid blocks.
*	Solid color conductor blocks, same as Solid Color Block but also mesecons
	and digilines conductor.

To spawn entities from dispensers and cannons include the
lwcomponents_spawners mod.

See the docs folder for details on each item.



The following are also defined as variants of the original mod item, if
the relevant mod is loaded.
*	Touchscreen, full node variant of digistuff:touchscreen.
*	Panel, full node variant of digistuff:panel.



The mod supports the following settings:

Spawn mobs
	Allow dispensers and cannons to spawn mobs instead of spawners.
	Default: true

Alert handler errors
	Issue errors when handler's of other mods fail.
	Default: true

Maximum piston nodes
	Maximum nodes a piston can push.
	Default: 15

Use player when placing
	Use the owner player of locked versions when placing nodes, otherwise
	no player is used.
	Default: false

------------------------------------------------------------------------
