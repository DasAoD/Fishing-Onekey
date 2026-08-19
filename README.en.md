# Fishing-OneKey

> **📌 Mirror notice:** This repository is an automatic mirror.
> Primary development happens on **[git.uliana.de/DasAoD/Fishing-Onekey](https://git.uliana.de/DasAoD/Fishing-Onekey)**.
> Please open issues and pull requests there.

*[Deutsche Version](README.md)*

<img src="art/icon.png" alt="Fishing-OneKey Icon" width="64" height="64" align="left" />

Minimal World of Warcraft addon (Midnight, Interface 120007): cast your fishing line and reel in the catch with a single key — none of the extra features bigger fishing addons like Angleur come with.

<br clear="left"/>

## How it works

1. You assign a key via chat command: `/fok bind`, then press the desired key (ESC cancels). The assignment is saved and survives `/reload` and login.
   (Blizzard's classic `Bindings.xml` mechanism for addon keybindings is no longer supported by current clients — `<Binding>` is rejected as an unknown XML element. Hence the chat-command approach instead of the Key Bindings options list.)
2. Press the key outside of a fishing channel and it "clicks" an invisible secure button that casts `Fishing` and casts your line — the same technique regular action bar buttons use to cast spells.
3. As soon as the fishing channel starts (`UNIT_SPELLCAST_CHANNEL_START`), the addon remaps that same physical key to Blizzard's built-in `INTERACTTARGET` binding action via `SetOverrideBinding` — exactly the action behind the regular interact key in the game options.
4. Once the channel ends (fish caught, cancelled, or timed out), the remap is removed. The key casts your line again on the next press.

No protected function (`InteractUnit`) is ever called directly from insecure code. Casting runs through a regular `SecureActionButton` (just like an action bar button), and the remap during the channel goes through `SetOverrideBinding` onto an existing, Blizzard-provided binding action — both officially documented techniques used by many established addons.

## Installation

0. Alternative to step 1: download the ready-made `.zip` from the [Releases page](https://git.uliana.de/DasAoD/Fishing-Onekey/releases) instead of cloning the repo.
1. Copy the `fishing-onekey` folder to `World of Warcraft/_retail_/Interface/AddOns/`.
2. In-game, type `/fok bind` and press the desired key.
3. Optional: enable **"Auto Loot"** (Options → Gameplay/Interface → Loot) so your catch goes straight into your bags without an extra click.

## Chat commands

- `/fok bind` – assign the next key you press (ESC cancels)
- `/fok unbind` – remove the assignment
- `/fok` – show the currently assigned key

## Limitations

- No camera-scan bobber detection of its own (unlike Angleur). Reliability depends on Blizzard's own line-of-sight-based "soft interact" system — if the bobber lands outside your view, the key may not respond.
- No auto-equip of fishing pole/hat, no toys, no raft handling. For anything beyond that, a full-featured fishing addon remains the better choice.

## Contributors

This project was developed together with Claude (Sonnet 5) by Anthropic and iteratively expanded.
Most of the code, architecture, and documentation was AI-generated and jointly refined.

| Role | Person / Tool |
|---|---|
| Project idea, requirements & testing | DasAoD |
| Code, architecture, documentation | Claude (Anthropic) |
