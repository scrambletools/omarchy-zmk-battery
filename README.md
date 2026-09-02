# ZMK Battery for Omarchy

Battery level of **each half** of a ZMK split keyboard, in the Omarchy bar.
A mini split-keyboard icon sits in the bar; click it for a panel with a
battery meter per half and a button that opens ZMK Studio.

BlueZ only reports one battery per Bluetooth device, so the Omarchy Bluetooth
panel can only ever show the central half. This plugin reads both Battery
Service instances the keyboard exposes directly over GATT.

## Requirements

- ZMK firmware built with the split battery options on the **central** half:

  ```
  CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y
  CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY=y
  ```

  Without them only the central half's level exists and the panel shows one row.
- The keyboard paired over Bluetooth. Battery is not available over USB.
- `python3`, `bluetoothctl` and `busctl`, all present on a stock Omarchy install.
- Optional: [ZMK Studio](https://zmk.dev/docs/features/studio) on `PATH` as
  `zmk-studio` (AUR `zmk-studio-bin`). The launch button greys out when it is
  missing.

## Install

```sh
omarchy plugin add https://github.com/scrambletools/omarchy-zmk-battery --enable
```

`--enable` places the icon on the right of the bar. Then set your keyboard's
Bluetooth name if it is not the default:

```sh
omarchy bar set io.github.scrambletools.zmk-battery deviceName "Cradio"
```

## Using it

- **Click** the icon to open the panel. **Right-click** refreshes.
- In the panel, `r` refreshes, `s` opens ZMK Studio, `Esc` closes.
- The icon dims when the keyboard is not connected and, by default, hides
  entirely. Turn `hideWhenDisconnected` off to keep it visible.

From the command line:

```sh
omarchy-shell zmk-battery status     # "Cradio: left 95%, right 95%"
omarchy-shell zmk-battery toggle
omarchy-shell zmk-battery studio
```

## Settings

All editable from the bar widget settings or `omarchy bar set <id> <key> <value>`:

| Key | Default | Meaning |
|---|---|---|
| `deviceName` | `Cradio` | Bluetooth name the keyboard advertises |
| `pollSeconds` | `90` | Battery refresh interval while connected |
| `lowPercent` | `20` | Level at or below which a meter turns urgent |
| `hideWhenDisconnected` | `true` | Hide the icon when the keyboard is away |
| `centralSide` | `left` | Which half is the central; labels the rows |

## How it works

`Service.qml` watches the shell's Bluetooth device list for a device with the
configured name, so connect and disconnect are reflected instantly with no
polling. While connected it runs the bundled `zmk-battery` script on a timer.
The script finds the device's GATT characteristics on D-Bus, reads every
Battery Level characteristic in handle order, and prints them as JSON; the
first is the central, the second the peripheral. `zmk-battery` also works on
its own from a terminal.

## Files

| File | Purpose |
|---|---|
| `manifest.json` | Plugin metadata and settings schema |
| `Panel.qml` | Bar icon and the details panel |
| `Service.qml` | Bluetooth watch, battery polling, Studio detection |
| `SplitKeyboardIcon.qml` | The split-keyboard glyph, drawn on a canvas |
| `Model.js` | JSON parsing and formatting helpers |
| `zmk-battery` | Reads the battery levels over GATT |

## Developing

Edit the files in place under `~/.config/omarchy/plugins/io.github.scrambletools.zmk-battery/`.
Settings and the script are picked up live, but the shell does not always
re-instantiate an already-loaded bar widget after a QML edit; when a change
to `Panel.qml` or `Service.qml` does not show, run `omarchy restart shell`.
