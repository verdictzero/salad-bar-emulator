# Limited Gamepad Mode

Perfect for SNES-style controllers and retro gaming!

## What is Limited Gamepad Mode?

This mode allows you to play with the classic SNES controller layout:
- **D-Pad** (4 directions)
- **4 Face Buttons** (A, B, X, Y)
- **2 Shoulder Buttons** (L, R)
- **2 System Buttons** (Start, Select)

No analog sticks required - just like the good old days!

## Default Button Mapping

### Movement & Actions
- **D-Pad**: Character movement
  - Up: Move forward
  - Down: Move backward
  - Left: Strafe left
  - Right: Strafe right
- **A Button**: Jump
- **B Button**: Sprint
- **L/R Buttons**: Camera rotation (in Tap mode)
- **X/Y Buttons**: Camera rotation (in Tap mode)
- **Start**: Pause menu / Toggle mouse capture
- **Select**: (Reserved for future use)

### Camera Controls (3 Modes)

You can choose how to control the camera in the CONTROLS menu:

#### 1. Tap L/R or X/Y to Rotate (Default)
- **L Button or X Button**: Tap to rotate camera left by 45°
- **R Button or Y Button**: Tap to rotate camera right by 45°
- Use shoulder buttons for quick camera snaps
- Use face buttons for the same control
- Perfect for exploration and casual play

#### 2. Hold X + D-Pad
- **Hold X Button + D-Pad**: Control camera
  - Left/Right: Rotate camera
  - Up/Down: Look up/down
- Movement is blocked while controlling camera
- Best for precise camera control
- Similar to tank controls

#### 3. Auto-Follow Movement
- Camera automatically follows your movement direction
- No manual camera control needed
- Ideal for always moving forward gameplay
- Simplest option - just focus on movement!

## How to Enable

1. Go to **CONTROLS** from the main menu
2. Find **LIMITED GAMEPAD MODE** section at the top
3. Check **Enable Limited Mode**
4. Select your preferred **Camera Control** method
5. Settings save automatically!

## Compatible Controllers

Works great with:
- **SNES Controllers** (Original or USB replicas)
- **Retro USB Controllers** (NES, SNES, Genesis style)
- **8BitDo Controllers** (SN30, SF30, etc.)
- **Mobile Gamepads** (Simple Bluetooth controllers)
- **Any controller** when you want simplified controls

## Keyboard Fallback

Even in Limited Mode, keyboard controls still work:
- **Q Key** = L Button
- **E Key** = R Button
- **X Key** = X Button
- **Y Key** = Y Button
- **Enter** = Start
- **Tab** = Select

## Tips

- **Tap X/Y mode** works best for open-world exploration
- **Hold X + D-Pad** gives you the most camera control precision
- **Auto-Follow** is great for speedrunning and racing-style play
- Camera rotation speed and step angle can be adjusted in the script

## Technical Details

Settings are saved to `user://game_settings.cfg` and persist between sessions.

Camera parameters:
- Tap rotation: 45° per tap (adjustable via `camera_step_angle`)
- Hold rotation: 90° per second (adjustable via `camera_rotation_speed`)
- Auto-follow: Smoothly rotates to match movement direction

Enjoy retro-style gaming! 🎮
