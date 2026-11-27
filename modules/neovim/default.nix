{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # LazyVim config is managed separately in ~/.config/nvim
    # This just ensures neovim and dependencies are installed
  };

  home.packages = with pkgs; [
    # LSP servers and tools for Neovim
    lua-language-server
    nixd # Nix LSP (eval-based; enables nix-darwin/home-manager options completion)
    typescript-language-server
    vscode-langservers-extracted # HTML/CSS/JSON/ESLint

    # Treesitter dependencies
    tree-sitter

    # Formatters
    stylua
    nixfmt
    prettier

    # Linters
    selene # Lua linter (used by nvim-lazy harness: `just lint`)
  ];

  # Environment variable
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
