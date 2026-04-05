{ pkgs, ... }:

let
  # Override the looking-glass-client package to stub out checkUUID
  patchedLookingGlass = pkgs.looking-glass-client.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i '/^static void checkUUID/,/^}/ c\
      static void checkUUID(void)\
      {\
        return;\
      }' src/main.c
    '';
  });
in {
  programs.looking-glass-client = {
    enable = true;
    package = patchedLookingGlass;
    settings = {
      app = {
        shmFile = "/dev/kvmfr0";
        allowDMA = true;
      };
      win = {
        keepAspect = true;
        fullScreen = true;
        jitRender = true;
      };
      spice = {
        enable = true;
        audio = false;
      };
      input = {
        rawMouse = true;
        escapeKey = 62;
      };
      egl = {
        # scale = 1;
      };
    };
  };
}