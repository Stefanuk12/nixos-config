{ pkgs, lib, config, ... }:

let
  # Installed as a writable copy by the activation script below: Claude Code mutates settings.json
  # at runtime, which a read-only store symlink breaks with EROFS.
  defaultSettings = {
    theme = "dark";
    model = "claude-opus-4-8";
    includeCoAuthoredBy = false;
    permissions = {
      allow = [
        "Bash(git diff:*)"
        "Bash(git log:*)"
        "Bash(git status:*)"
        "Edit"
      ];
      ask = [
        "Bash(git push:*)"
        "Bash(git commit:*)"
      ];
      deny = [
        "Read(./.env)"
        "Read(./secrets/**)"
      ];
    };
  };

  settingsFile = (pkgs.formats.json { }).generate "claude-code-settings.json" (
    defaultSettings // { "$schema" = "https://json.schemastore.org/claude-code-settings.json"; }
  );
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    # `settings` is deliberately unset — it would make settings.json a read-only store symlink.
  };

  # Seeded only if absent; after that Claude Code owns the file, so delete it and rebuild to
  # re-apply changed defaults.
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _claudeSettings="${config.home.homeDirectory}/.claude/settings.json"
    if [ ! -e "$_claudeSettings" ]; then
      run mkdir -p "${config.home.homeDirectory}/.claude"
      run install -m600 ${settingsFile} "$_claudeSettings"
    fi
  '';
}
