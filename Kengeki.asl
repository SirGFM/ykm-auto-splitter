state("Kengeki") {
	/* In Cheat Engine, use 'Kengeki.exe' as the base module.
	 * It accepts mixing module name and offsets for inspecting memory,
	 * so 'kengeki.exe + 401710' is a perfectly valid address. */

	ulong bossActive: 0x401710;
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
	/* TODO: Re-add options */
}

init {
}

split {
	if ((current.bossActive >> 32 != 0) &&
			(current.bossActive & 0xffffffff) != 0) {
		/* Usually, either the high or the low 32 bits of bossActive are set.
		 * However, on Sanae's mech cutscenes (pre and post fight) and on the
		 * final cutscene, both the 32 bits words are set.
		 *
		 * Ignore Sanae's mech cutscenes and split only on the final level. */
		if (current.level == 60) {
			return true;
		}
	}
	else if (current.bossActive == 0 && old.bossActive != 0 &&
			 old.health > 0 && current.health > 0) {
		/* Except by the final boss, as soon as a boss dies bossActive
		 * becomes 0. However, this also happens for a few (possibly only one)
		 * frames if the player dies.
		 *
		 * To account for that, check that the player is still alive as soon as
		 * that happens */
		return true;
	}
}

start {
	// XXX: This will have to be more complex for 100%...
	return (old.bInGame == 0 && current.bInGame == 1);
}

reset {
	// XXX: This will have to be more complex for 100%...
	return (current.level == 10 && current.bInGame == 1 && old.bInGame == 0);
}

isLoading {
	return current.bGameLoading == 1 || old.bInGame == 0;
}
