
# CBaraUK FiveM Photography Lighting

A simplistic, highly customizable studio lighting script for FiveM. Features a live RGB color wheel, precise placement controls, and an auto-cleanup system to keep your server optimized.

## Features
- **Live RGB Color Wheel**: Custom NUI canvas color picker with brightness and B/V sliders.
- **Precise Placement**: Adjust height, rotation, and positioning seamlessly.
- **Ownership System**: Only the player who placed the light can modify, move, or pick it up.
- **Sync All Lights**: Apply your current color and brightness settings to all your active lights instantly.
- **Auto-Cleanup**: Lights automatically delete after 30 minutes of inactivity to prevent clutter.
- **Studio Nighttime**: Instantly set the server time to 22:00 and clear weather for perfect studio lighting. *(Changeable in config)*
- **Target Support**: Full compatibility with `qb-target` and `ox_target`.
- **Usable Item**: Uses a configurable item to deploy lights.

## Requirements
- [qb-core](https://github.com/qbcore-framework/qb-core)
- [qb-target](https://github.com/BerkieBb/qb-target) OR [ox_target](https://github.com/overextended/ox_target)

## Installation
1. Download the latest release.
2. Extract the `cb-lighting` folder into your server's `resources` directory.
3. Add the following to your `server.cfg`:
   ```cfg
   ensure cb-lighting
   ```
4. Add the item to your `qb-core/shared/items.lua`:
   ```
	worklight 					= { name = 'worklight', label = 'Portable Work Light', weight = 1, type = 'item', image = 'worklight.png', unique = false, useable = true, shouldClose = true, description = 'A portable work light for illuminating dark areas.' },,
   ```

## Commands & Controls

### Commands
| Command | Description |
| :--- | :--- |
| `/placelight` | Enters placement mode (if you have the item). |
| `/cbnighttime` | Toggles studio nighttime (22:00) and clear weather. |

### Placement & Rotation Controls
| Key | Action |
| :---: | :--- |
| `E` | Confirm Placement / Save Rotation |
| `BACK` | Cancel Placement / Cancel Rotation |
| `↑` | Move Light Up |
| `↓` | Move Light Down |
| `←` | Rotate Left |
| `→` | Rotate Right |

## 🔧 Configuration
All settings can be adjusted in `config.lua`.

```lua
Config.ItemName = 'worklight'
Config.Command = 'placelight' 
Config.Timeout = 1800 -- Auto-delete lights after 30 minutes (1800 seconds)
Config.Target = 'qb-target' -- 'qb-target' or 'ox_target'
```

## Preview

https://github.com/user-attachments/assets/7f37e3c5-04e2-4ad7-bc77-bc1c61775160
