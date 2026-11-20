{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    # Use Homebrew cask instead of Nix package for:
    # - /Applications location (Spotlight, Developer Tools)
    # - Proper macOS app bundle behavior
    package = pkgs.emptyDirectory;

    font = {
      name = "FiraCode Nerd Font Mono";
      size = 12.0;
    };

    shellIntegration.enableFishIntegration = true;

    settings = {
      # Font tuning
      adjust_line_height = "110%";

      # Shell & editor
      shell = "${pkgs.fish}/bin/fish";
      editor = "nvim";

      # Behavior
      # socket-only: tighter than "yes" - only explicit socket connections can control
      # User-scoped socket prevents DoS from other users pre-creating the path
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty-${config.home.username}";
      copy_on_select = "yes";
      macos_option_as_alt = "yes";
      macos_quit_when_last_window_closed = "yes";

      # The negative value confirms tab close, OS-window close and app quit only when a
      # pane looks busy, leaving idle prompts to close silently. "Busy" is inferred from
      # fish's shell-integration markers rather than from process state, so this is a
      # best-effort guard: it is not a guarantee, and not a way to keep work alive.
      # Background work outliving the prompt, or a stale marker, still closes unasked.
      # Splits are outside its scope entirely, so their shortcuts are neutralized instead.
      confirm_os_window_close = -1;

      # Pinned rather than inherited, because close protection depends on it: a pane
      # whose shell exits stays open while other processes still write to its terminal.
      close_on_child_death = "no";
      enable_audio_bell = "no";
      notify_on_cmd_finish = "unfocused";
      paste_actions = "quote-urls-at-prompt,confirm,confirm-if-large";
      strip_trailing_spaces = "smart";
      clipboard_control = "write-clipboard write-primary read-clipboard-ask read-primary-ask";

      # Mouse
      mouse_hide_wait = "-3.0";
      url_style = "single";

      # Scrollback
      scrollback_lines = 5000;

      # Cursor
      cursor_trail = 3;
      cursor_trail_decay = "0.1 0.4";
      cursor_trail_start_threshold = 2;

      # Appearance
      window_padding_width = 10;
      hide_window_decorations = "titlebar-only";
      enabled_layouts = "grid,splits,tall,stack";

      # Opacity & blur (use with window manager)
      # 0.95 subtle, 0.90 moderate, 0.85 more transparent
      background_opacity = "0.95";
      background_blur = 40;
      dynamic_background_opacity = "yes"; # Allow runtime changes with shortcuts

      # Tab bar
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{index}: {title}";

      # Catppuccin Mocha theme
      foreground = "#CDD6F4";
      background = "#1E1E2E";
      selection_foreground = "#1E1E2E";
      selection_background = "#F5E0DC";
      cursor = "#F5E0DC";
      cursor_text_color = "#1E1E2E";
      url_color = "#F5E0DC";
      active_border_color = "#B4BEFE";
      inactive_border_color = "#6C7086";
      bell_border_color = "#F9E2AF";
      active_tab_foreground = "#11111B";
      active_tab_background = "#CBA6F7";
      inactive_tab_foreground = "#CDD6F4";
      inactive_tab_background = "#181825";
      tab_bar_background = "#11111B";
      mark1_foreground = "#1E1E2E";
      mark1_background = "#B4BEFE";
      mark2_foreground = "#1E1E2E";
      mark2_background = "#CBA6F7";
      mark3_foreground = "#1E1E2E";
      mark3_background = "#74C7EC";

      # Terminal colors (Catppuccin Mocha)
      color0 = "#45475A";
      color8 = "#585B70";
      color1 = "#F38BA8";
      color9 = "#F38BA8";
      color2 = "#A6E3A1";
      color10 = "#A6E3A1";
      color3 = "#F9E2AF";
      color11 = "#F9E2AF";
      color4 = "#89B4FA";
      color12 = "#89B4FA";
      color5 = "#F5C2E7";
      color13 = "#F5C2E7";
      color6 = "#94E2D5";
      color14 = "#94E2D5";
      color7 = "#BAC2DE";
      color15 = "#A6ADC8";
    };

    keybindings = {
      # Neutralize the direct shortcuts for accidental tab, pane and OS-window close.
      # discard_event drops the keystroke before the program running inside the terminal
      # can see and act on it. Tab close and pane close each ship two defaults, one under
      # cmd and one under kitty_mod (ctrl+shift on macOS), so both need covering;
      # OS-window close has only the single cmd default. Deliberate closing stays
      # available through `exit`, the window close button, `kt close` and cmd+q.
      "cmd+w" = "discard_event"; # close_tab
      "ctrl+shift+q" = "discard_event"; # close_tab
      "shift+cmd+d" = "discard_event"; # close_window, i.e. a split
      "ctrl+shift+w" = "discard_event"; # close_window, i.e. a split
      "shift+cmd+w" = "discard_event"; # close_os_window, taking every tab in it

      # Quit stays reachable, spelled out rather than inherited as a default.
      "cmd+q" = "quit";

      # Suppress kitty's default edit_config_file: the generated config is a read-only
      # nix store symlink, so edits belong in this module and reload has its own binding.
      "cmd+," = "discard_event";

      # Tabs
      "cmd+t" = "new_tab_with_cwd";
      "cmd+alt+t" = "set_tab_title";
      "ctrl+alt+1" = "goto_tab 1";
      "ctrl+alt+2" = "goto_tab 2";
      "ctrl+alt+3" = "goto_tab 3";
      "ctrl+alt+4" = "goto_tab 4";
      "ctrl+alt+5" = "goto_tab 5";
      "ctrl+alt+6" = "goto_tab 6";
      "ctrl+alt+7" = "goto_tab 7";
      "ctrl+alt+8" = "goto_tab 8";
      "ctrl+alt+9" = "goto_tab 9";

      # Splits
      "alt+minus" = "launch --location=hsplit --cwd=current";
      "alt+/" = "launch --location=vsplit --cwd=current";
      "alt+r" = "layout_action rotate";
      "alt+l" = "next_layout";

      # Config reload
      "cmd+control+," = "load_config_file";
      "cmd+left" = "neighboring_window left";
      "cmd+right" = "neighboring_window right";
      "cmd+up" = "neighboring_window up";
      "cmd+down" = "neighboring_window down";
      "shift+left" = "move_window left";
      "shift+right" = "move_window right";
      "shift+up" = "move_window up";
      "shift+down" = "move_window down";

      # Opacity controls (with dynamic_background_opacity enabled)
      "kitty_mod+a>m" = "set_background_opacity +0.1";
      "kitty_mod+a>l" = "set_background_opacity -0.1";
      "kitty_mod+a>1" = "set_background_opacity 1";
      "kitty_mod+a>d" = "set_background_opacity default";
    };
  };
}
