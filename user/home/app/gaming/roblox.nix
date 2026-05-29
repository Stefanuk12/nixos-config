{ pkgs, ... }: 

{
  home.packages = with pkgs; [
    vinegar
  ];
}