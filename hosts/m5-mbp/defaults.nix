# macOS System Defaults via nix-darwin
#
# Settings from NIX_MIGRATION_INVENTORY.md "macOS System Settings" section
# See: https://mynixos.com/nix-darwin/options/system.defaults
#
# NOTE: Some settings require logout/restart to take effect
_:

{
  system.defaults = {
    # Global domain settings
    NSGlobalDomain = {
      # Keyboard
      KeyRepeat = 2; # Fast key repeat (1 = fastest, default = 6)
      InitialKeyRepeat = 15; # Short delay before repeat (default = 25)
      ApplePressAndHoldEnabled = false; # Disable press-and-hold for key repeat

      # Appearance
      AppleInterfaceStyle = "Dark"; # Dark mode
      AppleShowAllExtensions = true; # Show file extensions

      # Scrolling - disable "natural" scroll direction
      # true = natural (content follows finger), false = traditional (scroll bars follow finger)
      "com.apple.swipescrolldirection" = false;

      # Trackpad/Mouse
      AppleEnableSwipeNavigateWithScrolls = true; # Two-finger swipe for back/forward

      # Typing
      NSAutomaticCapitalizationEnabled = false; # Disable auto-capitalize
      NSAutomaticDashSubstitutionEnabled = false; # Disable smart dashes
      NSAutomaticQuoteSubstitutionEnabled = false; # Disable smart quotes
      NSAutomaticSpellingCorrectionEnabled = false; # Disable auto-correct
      NSAutomaticPeriodSubstitutionEnabled = false; # Disable double-space period
    };

    # Dock settings
    dock = {
      autohide = true; # Auto-hide dock
      autohide-delay = 0.0; # No delay before showing dock
      autohide-time-modifier = 0.2; # Faster animation
      orientation = "bottom"; # Dock position
      launchanim = false; # Disable launch animation
      magnification = false; # No magnification on hover
      mineffect = "scale"; # Minimize animation
      mru-spaces = false; # Don't reorder spaces based on recent use
      show-recents = false; # Don't show recent apps
      tilesize = 48; # Icon size
      # Mission Control: Group windows by application
      # Fixes tiny preview issue with AeroSpace (which moves windows off-screen)
      expose-group-apps = true;
      # Hot corners
      wvous-tl-corner = 1; # Top-left: disabled
      wvous-tr-corner = 1; # Top-right: disabled
      wvous-bl-corner = 1; # Bottom-left: disabled
      wvous-br-corner = 1; # Bottom-right: disabled
      # Right-side Dock folder pins (declarative — replaces all manually-dragged folders)
      persistent-others = [
        {
          folder = {
            path = "/Users/mp/.agent/diagrams";
            arrangement = "name";
            displayas = "folder";
            showas = "list";
          };
        }
      ];
    };

    # Finder settings
    finder = {
      AppleShowAllExtensions = true; # Show all file extensions
      AppleShowAllFiles = false; # Don't show hidden files by default
      FXDefaultSearchScope = "SCcf"; # Search current folder by default
      FXEnableExtensionChangeWarning = false; # No warning when changing extension
      FXPreferredViewStyle = "Nlsv"; # List view by default
      QuitMenuItem = true; # Allow quitting Finder
      ShowPathbar = true; # Show path bar
      ShowStatusBar = true; # Show status bar
      _FXShowPosixPathInTitle = true; # Show full path in title
    };

    # Screenshot settings
    screencapture = {
      location = "/Users/mp/Pictures/screenshots"; # Explicit path (~ may not expand)
      disable-shadow = true; # No shadow in screenshots
      type = "png"; # Screenshot format
      show-thumbnail = false; # Disable floating thumbnail
    };

    # Trackpad settings
    trackpad = {
      Clicking = true; # Tap to click
      TrackpadRightClick = true; # Two-finger right-click
      TrackpadThreeFingerDrag = false; # Disable three-finger drag
    };

    # Login window
    loginwindow = {
      GuestEnabled = false; # Disable guest account
    };

    # Menu bar (menuExtraClock)
    menuExtraClock = {
      Show24Hour = true; # 24-hour time
      ShowDate = 1; # Show date: 0=when space, 1=always, 2=never
      ShowSeconds = false; # Don't show seconds
    };

    # Spaces
    spaces = {
      spans-displays = false; # Each display has separate spaces
    };

    # Custom settings that don't have nix-darwin options
    CustomUserPreferences = {
      # Accent color: Graphite (-1)
      # Other values: Blue=4, Purple=5, Pink=6, Red=0, Orange=1, Yellow=2, Green=3
      NSGlobalDomain = {
        AppleAccentColor = -1;
        AppleHighlightColor = "0.847059 0.847059 0.862745 Graphite";
        # Allow Computer Use to target Codex and terminal applications.
        ComputerUseAllowForbiddenTargets = true;
      };

      # Prevent .DS_Store on network/USB volumes
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      # TextEdit defaults to plain text
      "com.apple.TextEdit" = {
        RichText = 0;
      };

      # Activity Monitor: show all processes
      "com.apple.ActivityMonitor" = {
        ShowCategory = 0; # All processes
      };

      # Agent Sessions: disable Sparkle auto-updates so Nix stays the single source
      # of truth for the cask version. Without this, Sparkle silently swaps the
      # /Applications bundle out from under the homebrew.nix declaration.
      # Bundle ID confirmed from upstream README's `defaults delete com.triada.AgentSessions SULastCheckTime`.
      "com.triada.AgentSessions" = {
        SUEnableAutomaticChecks = false;
        SUAutomaticallyUpdate = false;
      };
    };
  };

  # GUI-level environment (launchctl setenv at activation). GUI apps launched
  # from Dock/Spotlight inherit only the launchd environment — neither
  # home.sessionVariables nor shell exports reach them.
  #
  # NOTE: this does NOT fix Claude Desktop's long-MCP-call timeout. Confirmed
  # by direct reproduction (process-tree trace + printenv inside a
  # Desktop-hosted session): this var is present all the way down to the
  # RepoPrompt child process, and Desktop still kills stdio MCP tool calls at
  # ~60-70s with error -32001 while the server keeps working. Desktop
  # enforces its own request deadline that MCP_TOOL_TIMEOUT/MCP_TIMEOUT/a
  # per-server timeout field don't override — a Claude Code Desktop
  # limitation, not an env-propagation gap. Long RepoPrompt calls from a
  # Desktop-hosted session must go through `rp-cli` instead, which bypasses
  # Desktop's MCP client. Keeping this var set anyway: it's correct for CLI
  # sessions launched from a GUI context (not just the fish wrappers below)
  # and for any future MCP client that does honor it.
  launchd.user.envVariables = {
    MCP_TOOL_TIMEOUT = "10800000"; # 3h, matches fish wrappers + claude settings.json
  };

  # Create screenshots directory (explicit path since activation runs as root)
  system.activationScripts.postActivation.text = ''
    mkdir -p /Users/mp/Pictures/screenshots
    chown mp:staff /Users/mp/Pictures/screenshots

    # Disable Ctrl+Space "Select the previous input source" (hotkey 60)
    # Frees Ctrl+Space for apps (e.g. Neovim autocomplete via blink.cmp)
    sudo -u mp defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add 60 \
      '<dict>
        <key>enabled</key><false/>
        <key>value</key><dict>
          <key>parameters</key><array>
            <integer>32</integer>
            <integer>49</integer>
            <integer>262144</integer>
          </array>
          <key>type</key><string>standard</string>
        </dict>
      </dict>'

    # Free Cmd+Shift+3 and Cmd+Shift+4 for Shottr without replacing other hotkeys.
    sudo -u mp defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add \
      28 '<dict>
        <key>enabled</key><false/>
        <key>value</key><dict>
          <key>parameters</key><array>
            <integer>51</integer>
            <integer>20</integer>
            <integer>1179648</integer>
          </array>
          <key>type</key><string>standard</string>
        </dict>
      </dict>' \
      30 '<dict>
        <key>enabled</key><false/>
        <key>value</key><dict>
          <key>parameters</key><array>
            <integer>52</integer>
            <integer>21</integer>
            <integer>1179648</integer>
          </array>
          <key>type</key><string>standard</string>
        </dict>
      </dict>'
  '';
}
