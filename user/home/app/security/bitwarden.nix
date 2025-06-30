{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    bitwarden-cli
    inputs.bwm.packages.${pkgs.system}.default
  ];

  xdg.configFile."bwm/config.ini".text = ''
    [dmenu]
    dmenu_command = fuzzel -d

    [dmenu_passphrase]
    obscure = True
    obscure_color = #222222

    [vault]
    server_1 = https://vault.bitwarden.com
    email_1 = 
    twofactor_1 = -1
    editor = nvim
    terminal = kitty
    type_library = wtype
    session_timeout_min = 60
    autotype_default = {USERNAME}{TAB}{PASSWORD}
  '';
}
