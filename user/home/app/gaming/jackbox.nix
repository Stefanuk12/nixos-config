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

    # Sourced from kaoskrew (packs 1-10), rexagames (pack 11 + Survey Scramble), Drawful 2 amd TMP 3 from cs.rin.ru; Quiplash 2 not
    # found.
    games = {
      "2948640" = "Z:/home/stefan/Games/The Jackbox Survey Scramble";
      "3364070" = "Z:/home/stefan/Games/The Jackbox Party Pack 11";
      "2216830" = "Z:/home/stefan/Games/The Jackbox Party Pack 10";
      "1850960" = "Z:/home/stefan/Games/The Jackbox Party Pack 9";
      "1552350" = "Z:/home/stefan/Games/The Jackbox Party Pack 8";
      "1211630" = "Z:/home/stefan/Games/The Jackbox Party Pack 7";
      "1005300" = "Z:/home/stefan/Games/The Jackbox Party Pack 6";
      "774461" = "Z:/home/stefan/Games/The Jackbox Party Pack 5";
      "610180" = "Z:/home/stefan/Games/The Jackbox Party Pack 4";
      "434170" = "Z:/home/stefan/Games/The Jackbox Party Pack 3";
      "397460" = "Z:/home/stefan/Games/The Jackbox Party Pack 2";
      "331670" = "Z:/home/stefan/Games/The Jackbox Party Pack 1";
      "2652000" = "Z:/home/stefan/Games/The Jackbox Naughty Pack";
      "442070" = "Z:/home/stefan/Games/Drawful 2";
      "3048060" = "Z:/home/stefan/Games/Trivia Murder Party 3";
    };

    launchArgs = [ ];
    gameLaunchArgs = { };
  };
}
