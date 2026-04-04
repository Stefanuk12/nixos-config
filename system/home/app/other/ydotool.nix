{ ... }:

{
  programs.ydotool.enable = true;
  users.users.stefan.extraGroups = [ "ydotool" ];
}