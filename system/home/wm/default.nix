{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pwvucontrol
  ];
}