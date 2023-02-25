local constants = {}

constants.CARGO_TYPES = {
  "scrap",
  "ore",
  "metal",
  "plastic",
  "wire",
  "pcb",
  "device",
  "powertool",
}

constants.CARGO_VALUE = {
  scrap = 10,
  ore = 20,
  metal = 30,
  plastic = 30,
  wire = 40,
  pcb = 60,
  device = 80,
  powertool = 100,
}

constants.CARGO_NAME = {
  scrap = "Scrap",
  ore = "Ore",
  metal = "Metal",
  plastic = "Plastic",
  wire = "Wire",
  pcb = "Printed Circuit Board",
  device = "Device",
  powertool = "Power Tool",
}

constants.UPGRADES = {
  "engine",
  "hull",
  "weapon",
}

constants.UPGRADE_NAME = {
  engine = "Engine",
  hull = "Durability",
  weapon = "Weapon",
}

constants.UPGRADE_DESC = {
  engine = "Increases engine power",
  hull = "Adds armor",
  weapon = "Increases weapon damage",
}

return constants
