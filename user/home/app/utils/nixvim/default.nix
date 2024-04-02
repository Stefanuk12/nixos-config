{ inputs, pkgs, ... }:

{
  # Initialise nixvim
  imports = [
    inputs.nix-colors.homeManagerModules.default
	inputs.nixvim.homeManagerModules.nixvim
    ./settings.nix
    ./keymaps.nix
	./theme.nix
	./plugins/bufferline.nix
    ./plugins/lsp.nix
  ];
  programs.nixvim.enable = true;

  programs.nixvim.clipboard.providers = {
    wl-copy.enable = true;
	xclip.enable = true;
  };
  programs.nixvim.plugins = {
    telescope.enable = true;
    oil.enable = true;
    treesitter.enable = true;
    luasnip.enable = true;
	lualine.enable = true;
  };
}
