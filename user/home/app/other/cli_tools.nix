{ pkgs, ... }:

# General-purpose CLI tools that used to arrive incidentally via hydenix's system packages and
# disappeared with it. Nothing in the config depends on them (derivations pin their own inputs);
# these are purely for interactive use.
{
  home.packages = with pkgs; [
    jq
    python3
    imagemagick
    psmisc # killall
    lm_sensors # sensors
    gettext # envsubst
    trash-cli
  ];
}
