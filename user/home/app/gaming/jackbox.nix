{
  inputs,
  config,
  ...
}:

let
  megapickerPath = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/The Jackbox Megapicker";
in
{
  imports = [ inputs.jackbox-megapicker-patcher.homeManagerModules.default ];

  programs.jackbox-megapicker-patcher = {
    inherit megapickerPath;

    enable = true;
    autoPatch.enable = true;

    games = {
      "3364070" = "/home/stefan/Games/The Jackbox Party Pack 11";
    };

    launchArgs = [ ];
    gameLaunchArgs = { };
  };
}
