# LUFFY AIM — Rainbow Edition (for your own Roblox experience)

A Roblox Studio starter project for an **owned experience**. It provides a compact rainbow UI, server-validated movement settings, a client-controlled flight mode, visual practice-target outlines, click-to-score aim training, server-spawned test coins with optional auto-collection, and a sandbox trade demo.

This is not an executor/cheat script. It does not target other players, change other experiences, enlarge gameplay hitboxes, or duplicate real inventory items. The hitbox control is a visual outline around practice targets; DUPLICATE is a non-mutating demonstration result.

## Files

- `src/ReplicatedStorage/LuffyAim/Config.lua` — shared limits and defaults.
- `src/ServerScriptService/LuffyAimServer.server.lua` — creates remotes and practice world, validates requests, owns test currency/demo inventory, and optionally saves preferences.
- `src/StarterPlayer/StarterPlayerScripts/LuffyAim.client.lua` — responsive UI, touch/mouse dragging, rainbow effects, flight controls, target visuals, settings and client requests.

## Install in Roblox Studio

1. Open **your own** experience in Studio.
2. In `ReplicatedStorage`, create a Folder named `LuffyAim`; add a ModuleScript named `Config` and paste `Config.lua`.
3. In `ServerScriptService`, add a Script named `LuffyAimServer.server.lua` and paste the server file.
4. In `StarterPlayer > StarterPlayerScripts`, add a LocalScript named `LuffyAim.client.lua` and paste the client file.
5. Press **Play**. The server creates `ReplicatedStorage/LuffyAimRemotes` and `Workspace/LuffyAimWorld` (practice targets and test pickup spawns) automatically.
6. Optional background artwork: set `Config.BackgroundImage` to an image asset you own or are permitted to use. It defaults to blank; the interface still has a cinematic gradient/lighting design. No copyrighted Luffy image is bundled.
7. Optional saved preferences: publish the experience, enable **Game Settings > Security > Enable Studio Access to API Services** for Studio tests, and set `Config.EnableDataStore = true`. DataStore failures are safely ignored.

## Controls and behavior

- **Speed:** server clamps the requested WalkSpeed to configured limits and restores the default on disable/respawn.
- **Fly:** enabled only through the server-issued state; client applies temporary movement forces to the local character. PC: WASD + Space/Ctrl; mobile: use Roblox's thumbstick and jump button. Turning it off or respawning removes flight objects and restores normal humanoid control.
- **Hitbox:** visual rainbow `SelectionBox` outlines for practice targets only. Size changes outline thickness/target visual scale locally; collision and server hit detection are unchanged.
- **Aim Training:** click a visible target. Server checks the target belongs to the practice world, distance, and request rate before increasing the score.
- **Farm:** spawn a test coin at your character. Auto-collect only works on these server-created test coins, with server distance checks and a real server-side counter.
- **Trade:** ICE/HOT are sandbox demonstrations that validate a demo item and record an outcome. DUPLICATE returns a demo-only response and never edits inventory.
- **Preferences:** UI state is retained when the panel closes and can be saved on the server when DataStore is enabled.

## Verification checklist (Studio)

Use **Test > Start** with one player. Confirm: speed changes and OFF restores default; flight moves up/down and OFF restores movement; outlines appear/disappear and change with the slider; target clicks increase the server score; spawned test coins increment the server count (auto mode can collect only nearby test coins); demo trades return validation results; close button hides the panel and the draggable floating button reopens it; dragging works with mouse and touch emulation. Test mobile controls on a device or Studio device emulator.

I cannot run Roblox Studio from this environment, so this repository is supplied with a verification checklist, not a claim that Studio runtime tests have already passed.
