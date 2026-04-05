{ pkgs, ... }:

let
  inherit (import ./utils.nix { inherit pkgs; })
    buildVscodeExtensionFromGitHub
    extFromMarketplace
    ;

  selene-vscode =
    (buildVscodeExtensionFromGitHub {
      name = "selene-vscode";
      publisher = "kampfkarren";
      version = "0-unstable";
      src = pkgs.fetchFromGitHub {
        owner = "Stefanuk12";
        repo = "selene";
        rev = "9818feb84a82bf9ea146d2f6e41c8c52a00eace9";
        sha256 = "nkz85X1+5JDZe0WHQuu18Vwvk+LwpqYXkREXKSj4Bzs=";
      };
      npmDepsHash = "sha256-gCHRAnfUgZxmeoeVCF0NaTvnjTszlr6FaWaVsFZ5ClQ=";
    }).overrideAttrs
      (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.unzip ];
      });
in
{
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

    (extFromMarketplace "icrawl" "discord-vscode" "5.9.2" "43ZAwaApQBqNzq25Uy/AmkQqprU7QlgJVVimfCaiu9k=")
    (extFromMarketplace "Spoorloos" "rbxexecute" "0.5.0" "q706Yq2jICzmeHdtIIJ6t6I6aL0vJLPaNInqZMD8dG4=")
    (extFromMarketplace "johnnymorganz" "luau-lsp" "1.64.1"
      "Go0+DDvtTO4D3yBwx0t5Zcz0qOi187RWu9oT1+1JLZ8="
    )
    (extFromMarketplace "johnnymorganz" "stylua" "1.7.1" "AbMCYYyK6Ywm/VljzAdmjk0VWm7JRH5GgJAC38T3j/c=")
    (extFromMarketplace "jbockle" "jbockle-format-files" "3.4.0"
      "BHw+T2EPdQq/wOD5kzvSln5SBFTYUXip8QDjnAGBfFY="
    )
    selene-vscode
  ];
}
