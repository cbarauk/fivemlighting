Config = {}

Config.ItemName = 'worklight'
Config.Command = 'placelight' 
Config.Debug = false
Config.PlacementDistance = 3.0
Config.InteractionDistance = 1.5
Config.RotationSpeed = 2.0 
Config.LightModel = `prop_kino_light_02`

Config.Target = 'qb-target'
Config.Menu = 'qb-menu'

Config.DefaultColor = { r = 255, g = 255, b = 255 }
Config.DefaultEnabled = true
Config.MinBrightness = 0.5
Config.MaxBrightness = 10.0

Config.Controls = {
    Confirm = { key = 38, label = 'E' }, 
    Cancel = { key = 194, label = 'BACK' }, 
    MoveUp = { key = 172, label = '↑' },
    MoveDown = { key = 173, label = '↓' },
    RotateLeft = { key = 174, label = '←' },
    RotateRight = { key = 175, label = '→' }
}

Config.LightDefaults = {
    offset = vector3(0.0, 0.0, 1.8), 
    dirOffset = vector3(0.0, -1.0, 0.0),
    brightness = 8.0,
    distance = 25.0,
    roundness = 1.0,
    radius = 25.0,
    falloff = 10.0
}

Config.Timeout = 1800

-- Toggle the /cbnighttime command on or off
Config.EnableNightTimeCommand = true 