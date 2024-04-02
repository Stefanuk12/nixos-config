{ ... }:

{
  programs.nixvim.plugins.lsp = {
    enable = true;
    servers = {
      lua-ls.enable = true;
      rust-analyzer.enable = true;
    };
  };
}
