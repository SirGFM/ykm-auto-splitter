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
	settings.Add("Yuyuko phase 1", false,
				 "Split after defeating Yuyuko's first phase");
}

init {
	vars.yuyukoPhase = 1;
	vars.cirno = false;
	vars.momiji = false;
	vars.nextLevel = 20;
}

split {
	int level = current.level;

	/* Corner cases */
	switch (level) {
	case 10:
		if (!vars.cirno && settings["Cirno"] && old.bossAHealth > 0
			&& current.bossAHealth <= 0) {

			vars.cirno = true;
			return true;
		}
		break;
	case 30:
		if (!vars.momiji && settings["Momiji"] && old.bossBHealth > 0
			&& current.bossBHealth <= 0) {

			vars.momiji = true;
			return true;
		}
		break;
	case 40:
		/* The game stil tracks the level after the robot (the river) as
		 * "Level 4". Therefore, this has to be split slightly
		 * differently... */
		if (old.level == 40 && old.bossAHealth > 0
			&& current.bossAHealth <= 0) {

			/* This sometimes get triggered as the cutscenes is ending.
			 * Avoid that by making sure the robot is the only actor in the scene */
			if (old.bossBPointer == 0 && current.bossBPointer == 0) {
				vars.nextLevel = 60;
				return true;
			}
		}
		break;
	case 60:
		/* Yuyuko stops taking damage when her life gets to 60 and it
		 * becomes 50 as soon as phase 2 starts. */
		if (vars.yuyukoPhase == 1 && old.bossAHealth != 50 
			&& current.bossAHealth == 50) {

			vars.yuyukoPhase = 2;
			if (settings["Yuyuko phase 1"]) {
				return true;
			}
		}
		else if (vars.yuyukoPhase == 2 && current.bossATimer >= 0x42469900) {
			/* XXX: This was only tested in Easy... The timer may take
			 * longer in other difficulties! */
			return true;
		}
		break;
	default:
		break;
	}

	/* In regular cases, simply split after detecting that the level
	 * changed */
	if (old.level != current.level && current.level == vars.nextLevel) {
		switch (level) {
		case 10:
		case 20:
		case 30:
			vars.nextLevel += 10;
			break;
		case 70:
			vars.nextLevel = 10;
			break;
		}

		return true;
	}
}

start {
	// XXX: This will have to be more complex for 100%...
	return (old.bInGame == 0 && current.bInGame == 1);
}

reset {
	// XXX: This will have to be more complex for 100%...
	if (current.level == 10 && current.bInGame == 1 && old.bInGame == 0) {
		vars.yuyukoPhase = 1;
		vars.cirno = false;
		vars.momiji = false;
		vars.nextLevel = 20;
		return true;
	}
}

isLoading {
	return current.bGameLoading == 1 || old.bInGame == 0;
}
