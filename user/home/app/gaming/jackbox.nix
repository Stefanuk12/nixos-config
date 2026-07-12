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

    # 1-10: https://kaoskrew.org/viewtopic.php?t=12550 (used Windows VM to extract since wine wasn't working)
    # 11 + N: https://rexagames.com/topic/6278-the-jackbox-party-pack-11-free-download-build-20226422-online/
    # Survey Scramble: https://rexagames.com/topic/7965-the-jackbox-survey-scramble-free-download-build-18462662-online
    # Quiplash 2: Not found :(
    # Drawful 2: Not found
    games = {
      "2948640" = "/home/stefan/Games/The Jackbox Survey Scramble";
      "3364070" = "/home/stefan/Games/The Jackbox Party Pack 11";
      "2216830" = "/home/stefan/Games/The Jackbox Party Pack 10";
      "1850960" = "/home/stefan/Games/The Jackbox Party Pack 9";
      "1552350" = "/home/stefan/Games/The Jackbox Party Pack 8";
      "1211630" = "/home/stefan/Games/The Jackbox Party Pack 7";
      "1005300" = "/home/stefan/Games/The Jackbox Party Pack 6";
      "774461" = "/home/stefan/Games/The Jackbox Party Pack 5";
      "610180" = "/home/stefan/Games/The Jackbox Party Pack 4";
      "434170" = "/home/stefan/Games/The Jackbox Party Pack 3";
      "397460" = "/home/stefan/Games/The Jackbox Party Pack 2";
      "331670" = "/home/stefan/Games/The Jackbox Party Pack 1";
      "2652000" = "/home/stefan/Games/The Jackbox Naughty Pack";
      # "1111940" = "/home/stefan/Games/Quiplash 2 InterLASHional";
      # "442070" = "/home/stefan/Games/Drawful 2";
    };

    launchArgs = [ ];
    gameLaunchArgs = { };
  };
}
