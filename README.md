The Locust

Heres the link to the game if you want to test it: https://www.roblox.com/games/126638405785520/

This is a Roblox game I made where one player becomes a killer and everyone else has to survive or escape before the timer ends.

I built this whole thing myself in the Roblox Studio. This is my first scripting project, more to come haha. I did all the map building, testing, and figured out what needed fixing myself. Learned a lot doing it.

It works like this: players vote between two maps, then one random player gets picked to be the killer. The killer (locust) is faster than survivors, looks scarier, and gets a weapon. Everyone tries to avoid the locust and run to an escape gate before the timer ends. If you die or escape you spawn in your cabin.

The code in this repo are the actual scripts from the game, if you want to see how I built it. Every file in src is one script and where it goes in Roblox Studio:

MapVoteHandler.server.lua goes in Workspace.MapVote.MapVoteHandler
DoorManager.server.lua goes in ServerScriptService.DoorManager
ForceCabinSpawn.server.lua goes in ServerScriptService.ForceCabinSpawn
KnifeDamage.server.lua goes in ServerStorage.Knife.KnifeDamage. Not actually in use right now since I switched to a laser gun, kept it anyway.

Biggest pain building this was doors. Some are just one simple part and those animate fine, but some are actually built from multiple pieces, a frame plus a separate door, and trying to swing the whole thing broke stuff, so those get skipped now. Also had old leftover scripts from earlier attempts still running and fighting the new ones, had to track those down and turn them off. Spawn points got mixed up a few times too when more than one person joined. Also the cabin system didnt work at first but I arranged spawn1, spawn2 etc.

No license picked yet, ask me if you want to use any of this.
<img width="1002" height="529" alt="Skärmavbild 2026-09-20 kl  01 34 42" src="https://github.com/user-attachments/assets/bce56f2c-0da0-4e7e-9ae0-c504660a8c9f" />
