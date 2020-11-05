# RBX Cheat Engine
## How to use bypassed CE (CeleryEngine.exe)
* Download Cheat Engine 7.1
* Drag CeleryEngine.exe into the installed CE folder, where the original CheatCheat Engine.exe is.
* Run CeleryEngine.exe instead

## Recommended CE Settings
There are **3 images** uploaded (jpegs) to this github. **Make sure** the settings in your Cheat Engine resemble these images as much as possible. Why? Because those settings help to reduce your chances of being detected.

[Click Here To View Images](/preview-of-settings)

## How to use Script Executor
* Open Cheat Engine' Lua executor.
  * First:
    * Press _CTRL + ALT + L_
    * Or go to _Table --> Show Cheat Table Lua Script_ 
  * Alternatively:
    * Click _Memory View_
    * Press _CTRL + ALT + L_, or _CTRL + L_
    * Or go to: _Tools --> Lua Engine_
* Copy contents of "script_executor.lua"
* Paste contents within the text field.
* Click "Execute Script"

When the scripts loads up. A message saying "Loaded" should popup in the Developer Console within ROBLOX. If it has load up, you can now execute scripts from your chat bar, like so:

```lua
c/print("Hello World!")
c/game.Players.LocalPlayer.Character.Head:Destroy()
```