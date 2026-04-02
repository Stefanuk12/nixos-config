{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
  };

  programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
    dracula-theme.theme-dracula
    vscodevim.vim
    yzhang.markdown-all-in-one
  ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "rbxexecute";
        publisher = "Spoorloos";
        version = "0.5.0";
        sha256 = "q706Yq2jICzmeHdtIIJ6t6I6aL0vJLPaNInqZMD8dG4=";
      }
    ];
}
