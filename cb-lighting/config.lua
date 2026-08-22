Config = {}

Config.ItemName = 'worklight'
Config.Command = 'placelight' 
Config.Debug = false
Config.PlacementDistance = 3.0
Config.InteractionDistance = 1.5
Config.RotationSpeed = 2.0 

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
    offset = vector3(0.0, 0.0, 0.0), 
    dirOffset = vector3(0.0, -1.0, 0.0),
    brightness = 8.0,
    distance = 25.0,
    roundness = 1.0,
    width = 25.0, 
    falloff = 10.0
}

Config.Timeout = 1800
Config.EnableNightTimeCommand = true 

Config.ShopNpc = {
    model = `ig_money`,
    coords = vector4(220.13, -1516.01, 29.29, 223.56)
}

Config.RenderDistance = 80.0

Config.ShopItems = {
    ['worklight'] = { price = 500 },
    ['tubeworklight'] = { price = 750 }
}

Config.ItemModels = {
    ['worklight'] = `prop_kino_light_02`,
    ['tubeworklight'] = `xm_prop_base_tripod_lampa`
}