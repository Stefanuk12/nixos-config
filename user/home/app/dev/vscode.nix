{ pkgs, ... }:

let
  extFromMarketplace = name: publisher: version: sha256: (pkgs.vscode-utils.extensionFromVscodeMarketplace {
    inherit name publisher version sha256;
  });
  customSelene = pkgs.stdenv.mkDerivation {
    pname = "selene-vscode";
    version = "1.5.1";
    src = pkgs.fetchFromGitHub {
      owner = "Stefanuk12";
      repo = "selene";
      rev = "9818feb84a82bf9ea146d2f6e41c8c52a00eace9";
      sha256 = "nkz85X1+5JDZe0WHQuu18Vwvk+LwpqYXkREXKSj4Bzs=";
    };
    nativeBuildInputs = [ pkgs.nodejs pkgs.nodePackages.pnpm ];
    buildPhase = ''
      cd selene-vscode
      pnpm install
      npx @vscode/vsce package --no-dependencies
    '';
    installPhase = ''
      cd selene-vscode
      mkdir -p $out/share/vscode/extensions/kampfkarren.selene-vscode
      cp -r . $out/share/vscode/extensions/kampfkarren.selene-vscode
    '';
  };
in {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
  };

  programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
    dracula-theme.theme-dracula
    vscodevim.vim
    yzhang.markdown-all-in-one
    usernamehw.errorlens
    tamasfe.even-better-toml
    redhat.vscode-yaml

    (extFromMarketplace "rbxexecute" "Spoorloos" "0.5.0" "q706Yq2jICzmeHdtIIJ6t6I6aL0vJLPaNInqZMD8dG4=")
    (extFromMarketplace "luau-lsp" "johnnymorganz" "1.64.1" "Go0+DDvtTO4D3yBwx0t5Zcz0qOi187RWu9oT1+1JLZ8=")
    (extFromMarketplace "stylua" "johnnymorganz" "1.7.1" "AbMCYYyK6Ywm/VljzAdmjk0VWm7JRH5GgJAC38T3j/c=")
    customSelene
  ];
}
