# setIME

Select IME by hotkeys.

![Icon](./setime/Assets.xcassets/AppIcon.appiconset/setime_256.png)

## How to use

1. Install XCode
2. Clone this repository
3. Run the project
4. Get output in the console (e.g. `[("com.apple.keylayout.ABC", nil), ("com.apple.inputmethod.SCIM.Shuangpin", nil), ("com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", nil), ("im.rime.inputmethod.Squirrel.Hans", nil)]`)
5. Open `setime/ContentView.swift`, find `orderedInputSourceIdList`, and replace the `[...]` after the `=` with the output from the console
6. Reorder the list to match the order of the input sources in the system
7. For the input sources you want to assign a hotkey, replace `nil` with the key code (e.g. `nil` -> `.h` for `com.apple.keylayout.ABC`)
8. Run the project again (Replace)
