{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    bitwarden-cli
    inputs.bwm.packages.${pkgs.stdenv.hostPlatform.system}.default
    pinentry-qt
  ];

  xdg.configFile."bwm/config.ini".text = ''
    [dmenu]
    dmenu_command = fuzzel --dmenu --lines=25 --width=40
    pinentry = pinentry-qt

    [dmenu_passphrase]
    obscure = True
    obscure_color = #222222

    [vault]
    server_1 = https://vault.bitwarden.com
    email_1 = stefanukpadd@gmail.com
    twofactor_1 = 1
    password_cmd_1 = sh -lc "sops -d ${../../../../secrets/home/bitwarden.yaml} | ${pkgs.yq-go}/bin/yq -r '.master_password'"
    editor = nvim
    terminal = alacritty
    type_library = ydotool
    session_timeout_min = 60
    autotype_default = {USERNAME}{TAB}{PASSWORD}
  '';
}
