state("Kengeki") {
	/* In Cheat Engine, use 'Kengeki.exe' as the base module.
	 * It accepts mixing module name and offsets for inspecting memory,
	 * so 'kengeki.exe + 401710' is a perfectly valid address. */

	byte bGameLoading: 0x4067B1;

	/* 0x407fc4 - points to a game state(?) struct
	 *   - 0x0c: in game? (i.e., 0 in mainmenu)
	 *   - 0x20: cur level
	 *       - level 1: 10 (cirno/frog)
	 *       - level 2: 20 (marisa)
	 *       - level 3: 30 (aya)
	 *       - level 4: 40 (sanae/mecha - reimu's river)
	 *       - level 5: 50 (reimu)
	 *       - level 6: 60 (yuyuko)
	 *       - level 7: 70 (sanae)
	 *   - 0x28: difficulty
	 *   - 0x2c: orb count
	 *   - 0x38: death count
	 *   - 0x40: fall count
	 */
	byte bInGame: 0x407fc4, 0x0c;
	int level: 0x407fc4, 0x20;

	/* The game keeps two pointers for bosses. Those are used when a level
	 * has two bosses (e.g., the first level) and when there are NPCs in
	 * cutscenes (e.g., Sanae and the Robot in level 4).
	 * The following table describe which pointer is valid for which boss:
	 *
	 * |         |        "Boss A"        |        "Boss B"        |
	 * |         | (Kengeki.exe + 401710) | (Kengeki.exe + 401714) |
	 * |---------|------------------------|------------------------|
	 * | Level 1 | Cirno                  | Frog                   |
	 * | Level 2 | Marisa                 |                        |
	 * | Level 3 | Aya                    | Momiji                 |
	 * | Level 4 | Robot                  | Sanae (Cutscene NPC)   |
	 * | Level 5 | Reimu                  |                        |
	 * | Level 6 | Yuyuko                 | Marisa (Cutscene NPC)  |
	 *
	 * From that structure, two offsets are useful for detecting specific
	 * events:
	 *
	 *   - 0x294: AI timer (?) - Counts up from a seemingly arbitrary value
	 *                           until the boss uses a different attack
	 *   - 0x2a8: Boss health
	 */
	int bossATimer: 0x401710, 0x294;
	int bossAHealth: 0x401710, 0x2a8;
	int bossBHealth: 0x401714, 0x2a8;
	int bossBPointer: 0x401714;

	/* For the record, this means something like:
	 *
	 * struct first {
	 *     // ...
	 *     struct second *data; // offsetof(struct first, data) == 0x7c
	 * };
	 *
	 * struct second {
	 *     // ...
	 *     int health; // offset(struct second, health) == 0x2a8
	 * };
	 *
	 * struct first *health_access = 0x407ffc;
	 *
	 * health = health_access->data->health;
	 */
	int health: 0x407ffc, 0x7c, 0x2a8;
}

startup {
	settings.Add("Cirno", false, "Split after defeating Cirno");
	settings.Add("Momiji", false, "Split after defeating Momiji");
	settings.Add("River", false, "Split after the river stage (Level 4-2)");
	settings.Add("Yuyuko phase 1", false,
				 "Split after defeating Yuyuko's first phase");
	settings.Add("Extra start", false, "100% - Start on the extra stage");
	settings.Add("Remote debug", false, "Enable remote Auto Splitter debug (requires Python)");

	/* Lambda expresion that takes a boolean and has void return */
	vars.reset = (Action<bool>) ( (isExtra) => {
		vars.yuyukoPhase = 1;
		vars.cirno = false;
		vars.momiji = false;
		vars.justBeatRobot = false;
		if (isExtra) {
			vars.nextLevel = 10;
		}
		else {
			vars.nextLevel = 20;
		}
	} );

	/* XXX: Trying to use 'settings', 'current' or 'old' within a lambda
	 * causes it to explode (or, at least, to misbehave). It probably has
	 * something to do with how variables are captured into the lambda...
	 *
	 * Although using those objects directly does not work, manually
	 * accessing them from the caller and passing the value themselves
	 * into the lambda works perfectly. */
	vars.checkStart = (Func<bool, int, bool, bool, bool>) (
		(isExtra, level, isInGame, wasInGame) => {

		int firstStage;

		if (isExtra) {
			firstStage = 70;
		}
		else {
			firstStage = 10;
		}

		if (level == firstStage && isInGame && !wasInGame) {

			vars.reset(isExtra);
			return true;
		}
		return false;
	} );

	/* Lambda expression that sends a debug message to a local TCP server,
	 * using a unique and different client each time. */
	vars.remoteDebug = (Action<string>) ( (msg) => {
		try {
			System.Net.Sockets.TcpClient clt;
			System.Net.Sockets.NetworkStream conn;

			clt = new System.Net.Sockets.TcpClient("127.0.0.1", 60000);
			conn = clt.GetStream();

			byte[] data = Encoding.ASCII.GetBytes(msg);
			conn.Write(data, 0, data.Length);

			conn.Close();
			clt.Close();
		} catch (Exception e) {
		}
	} );
}

split {
	int level = current.level;

	if (settings["Remote debug"]) {
		if (old.level != current.level) {
			vars.remoteDebug("!!! Old level: " + old.level);
			vars.remoteDebug("!!! New level: " + current.level);
		}
	}

	/* Corner cases */
	switch (level) {
	case 10:
		if (!vars.cirno && settings["Cirno"] && old.bossAHealth > 0
			&& current.bossAHealth <= 0) {

			if (settings["Remote debug"]) {
				vars.remoteDebug("Cirno split!");
			}

			vars.cirno = true;
			return true;
		}
		break;
	case 30:
		if (!vars.momiji && settings["Momiji"] && old.bossBHealth > 0
			&& current.bossBHealth <= 0) {

			if (settings["Remote debug"]) {
				vars.remoteDebug("Momiji split!");
			}

			vars.momiji = true;
			return true;
		}
		break;
	case 40:
		/* The game stil tracks the level after the robot (the river) as
		 * "Level 4". Therefore, this has to be split slightly
		 * differently...
		 * Cache that the boss was defeated (by tracking its health) and
		 * then split as soon as the game start loading the next scene. */
		if (old.level == 40 && old.bossAHealth > 0
			&& current.bossAHealth <= 0) {

			/* This sometimes get triggered as the cutscenes is ending.
			 * Avoid that by making sure the robot is the only actor in the scene */
			if (old.bossBPointer == 0 && current.bossBPointer == 0) {
				if (settings["Remote debug"]) {
					vars.remoteDebug("Robot defeated!");
				}
				vars.justBeatRobot = true;
			}
		}
		break;
	case 60:
		/* Yuyuko stops taking damage when her life gets to 60 and it
		 * becomes 50 as soon as phase 2 starts. */
		if (vars.yuyukoPhase == 1 && old.bossAHealth != 50 
			&& current.bossAHealth == 50) {

			if (settings["Remote debug"]) {
				vars.remoteDebug("Done with Yuyuko phase 1!");
			}

			vars.yuyukoPhase = 2;
			if (settings["Yuyuko phase 1"]) {
				if (settings["Remote debug"]) {
					vars.remoteDebug("Yuyuko split");
				}

				return true;
			}
		}
		else if (vars.yuyukoPhase == 2 && current.bossATimer >= 0x42469900) {
			/* XXX: This was only tested in Easy... The timer may take
			 * longer in other difficulties! */

			if (settings["Remote debug"]) {
				vars.remoteDebug(".done !!!");
			}

			return true;
		}
		break;
	default:
		break;
	}

	/* In regular cases, simply split after detecting that the level
	 * changed */
	if (old.level != current.level && current.level == vars.nextLevel) {
		if (settings["Remote debug"]) {
			vars.remoteDebug("Regular split from " + old.level + " to " + current.level);
		}

		switch (level) {
		case 10:
		case 20:
		case 30:
		case 50:
			vars.nextLevel += 10;
			break;
		}

		if (settings["Remote debug"]) {
			vars.remoteDebug("  Next: " + vars.nextLevel);
		}

		return true;
	}
	else if (old.level == 40 && vars.justBeatRobot
			 && old.bGameLoading == 0 && current.bGameLoading == 1) {
		/* Special corner case for the Robot split */

		vars.justBeatRobot = false;
		if (settings["Remote debug"]) {
			vars.remoteDebug("Robot split");
		}

		if (settings["River"]) {
			if (settings["Remote debug"]) {
				vars.remoteDebug("  Next: River split");
			}

			vars.nextLevel = 50;
		}
		else {

			if (settings["Remote debug"]) {
				vars.remoteDebug("  Next: Reimu split");
			}

			vars.nextLevel = 60;
		}

		if (settings["Remote debug"]) {
			vars.remoteDebug("  Next: " + vars.nextLevel);
		}
		return true;
	}
}

start {
	return vars.checkStart(settings["Extra start"], current.level,
						   current.bInGame == 1, old.bInGame == 1);
}

reset {
	return vars.checkStart(settings["Extra start"], current.level,
						   current.bInGame == 1, old.bInGame == 1);
}

isLoading {
	return current.bGameLoading == 1 || old.bInGame == 0;
}
