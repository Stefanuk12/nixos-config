{ inputs, ... }:

{
  imports = [
    inputs.steam-launch-options.homeManagerModules.default
  ];

  programs.steam-launch-options = {
    enable = true;

    appLaunchOptions = {};

    userDataIds = [
      "280400742"
      "1126791433"
    ];
  };
}