state("Kengeki") {
	/* In Cheat Engine, use 'Kengeki.exe' as the base module.
	 * It accepts mixing module name and offsets for inspecting memory,
	 * so 'kengeki.exe + 401710' is a perfectly valid address. */

	ulong bossActive: 0x401710;
	string4 mapName: 0x401700, 0x54, 0x38, 0x14, 0x14;
	byte bGameLoading: 0x4067B1;
}

startup {
	/* TODO: Re-add options */
}

init {
	vars.trySplit = 0;
	vars.sanaeMechCutscene = 0;
}

split {
	if ((current.bossActive >> 32 != 0) &&
			(current.bossActive & 0xffffffff) != 0) {
		/* Usually, either the high or the low 32 bits of bossActive are set.
		 * However, on Sanae's mech cutscenes (pre and post fight) and on the
		 * final cutscene, both the 32 bits words are set.
		 *
		 * Ignore Sanae's mech cutscenes (by simply counting how many times they
		 * happened) and split on the third and final time this happens (which
		 * should be on the final cutscene). */
		if (vars.trySplit == 0) {
			if (vars.sanaeMechCutscene < 2) {
				vars.sanaeMechCutscene++;
			}
			else {
				return true;
			}
			vars.trySplit = 1;
		}
	}
	else if (vars.trySplit == 5) {
		vars.trySplit = 0;
		return true;
	}
	else if (vars.trySplit > 0 && current.bossActive == 0) {
		vars.trySplit++;
	}
	else if (current.bossActive == 0 && old.bossActive != 0) {
		/* Except by the final boss, as soon as a boss dies bossActive
		 * becomes 0. However, this also happens for a few (possibly only one)
		 * frames if the player dies.
		 *
		 * To account for that, ensure that bossActive changes and stays as 0
		 * for a few (5) frames before splitting. */
		vars.trySplit = 1;
	}
	else {
		vars.trySplit = 0;
	}

	return false;
}

start {
	if (current.mapName == "st01" &&
			(current.bGameLoading == 0 && old.bGameLoading == 1)) {
		vars.sanaeMechCutscene = 0;
		return true;
	}
}

reset {
	if (current.mapName == "st01" &&
			(current.bGameLoading == 0 && old.bGameLoading == 1)) {
		vars.sanaeMechCutscene = 0;
		return true;
	}
}

isLoading {
	return current.bGameLoading == 1;
}
