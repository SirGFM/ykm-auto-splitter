state("Kengeki") {
	int gameLoading: 0x4067B0;
	int bossActive: 0x401710; //works on: cirno, marisa, aya, nitori, reimu
	int bossActive2: 0x401714; //works on toad, momiji
	int orbCount: 0x00407FC4, 0x2C;
	string4 mapName: 0x00401700, 0x54, 0x38, 0x14, 0x14;
}

startup {
	settings.Add("RiverSplit", false, "Split when leaving the River and entering Hakurei Shrine");
	settings.Add("OrbSplit", false, "Split when collecting a yellow orb");
	settings.Add("FullOrb", false, "Only split when 3 orbs are collected", "OrbSplit");
	settings.Add("HakureiOrb", false, "Only split when all 3 orbs are collected in Hakurei Shrine", "OrbSplit");
}

split {
	if (current.bossActive == 0 && old.bossActive != 0 && old.bossActive2 == 0) {
		return true;
	}
	
	if (current.bossActive2 == 0 && old.bossActive2 != 0 && old.bossActive == 0) {
		return true;
	}
	
	if (current.orbCount != 0 && current.orbCount != old.orbCount && settings["OrbSplit"] == true && settings["FullOrb"] == false && current.mapName != "st05") {
		return true;
	}
	
	if (settings["FullOrb"] == true && old.orbCount == 2 && current.orbCount == 3) {
		return true;
	}
	
	if (current.mapName == "st05") {
		if (settings["FullOrb"] == true || settings["HakureiOrb"] == true && old.orbCount == 2 && current.orbCount == 3) {
			return true;
		}
		
		if (settings["HakureiOrb"] == false && settings["FullOrb"] == false && current.orbCount != 0 && current.orbCount != old.orbCount) {
			return true;
		}
	}
	
	if (current.mapName == "st05" && old.mapName != "st05" && current.gameLoading != 1 && settings["RiverSplit"] == true) {
		return true;
	}
}

start {
	return (current.gameLoading == 1 && current.mapName == "st01");
}

reset {
	return (current.gameLoading != 1 && current.mapName == "st01");
}

isLoading {
	return current.gameLoading != 1;
}
