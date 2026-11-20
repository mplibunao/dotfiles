# Kitty

Home Manager generates Kitty's configuration from [`modules/kitty/default.nix`](../../modules/kitty/default.nix), and the app itself comes from the Homebrew cask. `~/.config/kitty/kitty.conf` is a read-only link into the Nix store, so edit the module instead.

## Applying a change

A change to the Kitty module takes effect after `darwin-rebuild switch`. Most settings then apply on a configuration reload (`cmd+control+,`). Some `cmd` bindings are also macOS menu shortcuts, and Kitty picks up a change to those only after a full quit and relaunch.

## Close and quit protection

Agent sessions run in Kitty tabs, and closing a tab ends the session in it. Kitty and Karabiner-Elements each guard against an accidental close.

Kitty maps these shortcuts to `discard_event`, which drops the keystroke before the program in the terminal sees it. `no_op` would pass the key through to that program instead.

| Shortcut | Default action it blocks |
|---|---|
| `cmd+w`, `ctrl+shift+q` | Close the tab |
| `shift+cmd+d`, `ctrl+shift+w` | Close the split |
| `shift+cmd+w` | Close the OS window and every tab in it |
| `cmd+,` | Open the generated configuration in an editor |

`confirm_os_window_close = -1` asks before closing a tab or an OS window, or quitting, only when a pane looks busy. Kitty infers "busy" from Fish shell integration, so the check is best effort, and it never covers closing one split. `close_on_child_death = no` keeps a pane open after its shell exits while other processes still write to it.

[`modules/karabiner/config/karabiner.json`](../../modules/karabiner/config/karabiner.json) adds two rules: `cmd+w` is swallowed while Kitty is the frontmost app, and `cmd+q` quits any app only on a double tap.

### Keys under Dvorak

The keyboard is ANSI QWERTY hardware with the Dvorak layout selected in macOS, and the two tools name keys at different stages. A Karabiner `key_code` is a physical QWERTY position, read before macOS applies Dvorak: physical `comma` types Dvorak `w`, and physical `x` types Dvorak `q`. A Kitty key name is the character the layout produces. So the Karabiner rules match `comma` and `x` with Command held, while Kitty maps `cmd+w` and `cmd+q`. The Karabiner rules accept either Command key.

## Deliberate ways to close

- `exit` ends the shell normally.
- `kt close` closes the current tab through remote control without asking, because remote control's tab close never consults `confirm_os_window_close`.
- A double-tapped `cmd+q` reaches Kitty's `quit`, which asks first when a pane is busy.
- The window's close button uses the same busy-pane confirmation.

Closing the last OS window quits Kitty, because `macos_quit_when_last_window_closed = yes`.

## Remote control

`allow_remote_control = socket-only` with `listen_on = unix:/tmp/kitty-<user>`, so only clients that connect through that per-user socket can control Kitty. The `kt` and `kdev` Fish functions in `modules/fish/functions/a_mp/` use it.
