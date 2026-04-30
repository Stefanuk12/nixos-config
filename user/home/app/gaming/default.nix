{ inputs, ... }:
{
  imports = [
    inputs.dbd-tools.homeManagerModules.default
    inputs.steam-launch-options.homeManagerModules.default
  ];

  programs.dbd = {
    enable = true;

    settings = {
      "GameUserSettings.ini" = {
        "ScalabilityGroups" = {
          "sg.ResolutionQuality" = 100;
          "sg.ViewDistanceQuality" = 4;
          "sg.AntiAliasingQuality" = 0;
          "sg.ShadowQuality" = 2;
          "sg.GlobalIlluminationQuality" = 1;
          "sg.ReflectionQuality" = 0;
          "sg.PostProcessQuality" = 0;
          "sg.TextureQuality" = 1;
          "sg.EffectsQuality" = 3;
          "sg.FoliageQuality" = 0;
          "sg.ShadingQuality" = 3;
          "sg.LandscapeQuality" = 3;
          "sg.AnimationQuality" = 1;
        };
        "/Script/DeadByDaylight.DBDGameUserSettings" = {
          FieldOfView = 95;
          TerrorRadiusVisualFeedback = true;
          UseHeadphones = false;
        };
      };

      "Engine.ini" = {
        "/Script/Engine.Engine" = {
          bUseFixedFrameRate = true;
          FixedFrameRate = 240;
        };
      };

      "Input.ini" = {
        "/script/engine.inputsettings" = {
          bEnableMouseSmoothing = false;
          bDisableMouseAcceleration = true;
        };
      };
    };

    axisMappings = [
      { name = "TurnConstantSurvivor"; scale = -1.0; key = "Q"; }
      { name = "TurnConstantSurvivor"; scale = 1.0; key = "E"; }
      { name = "TurnConstantKiller"; scale = -1.0; key = "Q"; }
      { name = "TurnConstantKiller"; scale = 1.0; key = "E"; }
    ];

    actionMappings = [
      { name = "SecondaryAction_Camper"; key = "ThumbMouseButton2"; }
      { name = "Action_Camper"; key = "ThumbMouseButton"; }
      { name = "EventAbility_Survivor"; key = "Three"; }
      { name = "EventAbility_Killer"; key = "Three"; }
    ];

    reshade = {
      enable = true;
      # Override or add ReShade.ini values here. Module defaults already
      # set up paths and sensible overlay options.
      # settings = {
      #   INPUT.KeyOverlay = "45,0,0,0";  # Insert
      # };
    };
  };

  programs.steam-launch-options = {
    enable = true;

    appLaunchOptions = {
      "381210" = ''WINEDLLOVERRIDES=\"dxgi=n,b\" DRI_PRIME=1 dbd-launch %command% -dx11'';
    };

    userDataIds = [
      "280400742"
      "1126791433"
    ];
  };
}
