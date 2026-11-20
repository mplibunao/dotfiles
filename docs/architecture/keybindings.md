# Keybindings

Where each tool's bindings are defined, how each one names keys, and how to check a new binding for conflicts.

The keyboard is ANSI QWERTY hardware with the Dvorak layout selected in macOS. Some tools read a key's physical position before macOS applies Dvorak, and others read the character Dvorak produces, so the same physical key has different names in different files.

## Where bindings are defined

| Tool | File | Key names |
|---|---|---|
| Karabiner-Elements | [`modules/karabiner/config/karabiner.json`](../../modules/karabiner/config/karabiner.json): complex-modification rules, simple modifications, and per-device modifier swaps | Physical QWERTY positions (`key_code`) |
| AeroSpace | [`modules/aerospace/aerospace.toml`](../../modules/aerospace/aerospace.toml), the `[mode.*.binding]` tables | Dvorak characters, because of `key-mapping.preset = 'dvorak'` |
| Kitty | The `keybindings` set in [`modules/kitty/default.nix`](../../modules/kitty/default.nix) | Dvorak characters |
| Fish | [`modules/fish/default.nix`](../../modules/fish/default.nix): vi key bindings, `Ctrl+E` to edit the command line, and the `fzf.fish` plugin's bindings | Dvorak characters |
| Neovim | The LazyVim configuration in the separate `mplibunao/neovim-config` repository, cloned to `~/.config/nvim-lazy` by the bootstrap skill | Dvorak characters |
| VoiceInk | Set in the app and stored in its `com.prakashjoshipax.VoiceInk` preferences; this repository doesn't manage them | Recorded by the app |
| TinyCast | `Option+Space` opens the launcher, set in TinyCast's own settings ([TinyCast](tinycast.md)) | |
| macOS | [`hosts/m5-mbp/defaults.nix`](../../hosts/m5-mbp/defaults.nix) turns off the `Ctrl+Space` input-source shortcut, for Neovim completion, and `Cmd+Shift+3` and `Cmd+Shift+4`, for Shottr | |

Karabiner turns Caps Lock into Escape when tapped and Hyper (Shift+Command+Control+Option) when held. AeroSpace uses Option as its modifier so that it never competes with Hyper.

## Naming a key

- In AeroSpace, Kitty, Fish, and Neovim, a binding names the character I type. `alt-b` means the key labelled `b` in Dvorak, wherever it is on the hardware.
- In Karabiner, `key_code` names the physical QWERTY position, read before Dvorak. Physical `comma` types Dvorak `w`, so a Karabiner rule for Command+W matches `comma` with Command. Karabiner-EventViewer shows the `key_code` of a key press.
- Navigation uses `h`, `j`, `k`, and `l` as characters, as in Vim, even though Dvorak scatters them across the keyboard.
- Prefer mnemonic bindings, such as `alt-shift-b` for the browser, over positional ones.
- When adding a binding, say in its comment whether it's Dvorak-native or QWERTY-positional.
- Don't mix the physical and mnemonic interpretations.

## Checking a new binding for conflicts

A binding conflicts when two tools claim the same key and modifiers. Karabiner sees a key press first, then global shortcuts (AeroSpace and macOS), and only then the frontmost app, so an app's binding never fires when a global one takes the same key.

1. Work out the key in both forms: the Dvorak character, and for Karabiner the physical `key_code`.
2. Search the files above for both forms. For example, for Option+L:

   ```sh
   rg -n -e 'alt-l\b' -e 'alt\+l"' modules/aerospace/aerospace.toml modules/kitty/default.nix modules/fish/default.nix
   ```

3. List the keys Karabiner's rules trigger on, with their modifiers:

   ```sh
   jq -r '.profiles[] | select(.selected) | .complex_modifications.rules[].manipulators[].from
     | [.key_code // .pointing_button // "?", ((.modifiers.mandatory // []) | join("+"))] | @tsv' \
     modules/karabiner/config/karabiner.json | sort -u
   ```

4. For Kitty bindings that use Command, check the app's menu shortcuts too. [Kitty](kitty.md#applying-a-change) explains why those changes need a relaunch.

One overlap exists today: Kitty binds `alt+l` to `next_layout`, and AeroSpace binds `alt-l` to focus the window on the right. Both name the same Dvorak key, and AeroSpace receives it first.
