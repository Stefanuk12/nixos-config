{ pkgs, lib, config, ... }:

let
  # Declarative defaults. These are installed as a *writable* copy (see the
  # activation script below) so Claude Code can mutate settings.json at runtime
  # (e.g. `/model`). If home-manager owned the file directly it would be a
  # read-only Nix store symlink and runtime changes would fail with EROFS.
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

    # Intentionally NOT setting `settings` here: that would make
    # ~/.claude/settings.json a read-only store symlink and break runtime
    # changes like `/model`. We seed a writable copy below instead.

    # memory.text = ''
    #   # Personal coding preferences
    #   - Prefer concise answers
    #   - Use tabs not spaces in this repo
    # '';

    # mcpServers = {
    #   github = {
    #     command = "docker";
    #     args = [ "run" "-i" "--rm" "-e" "GITHUB_PERSONAL_ACCESS_TOKEN" "ghcr.io/github/github-mcp-server" ];
    #   };
    # };
  };

  # Seed a writable settings.json with our defaults, but only if one does not
  # already exist. After that, Claude Code owns the file and runtime edits
  # (model, theme, etc.) persist. To re-apply changed defaults from Nix, delete
  # ~/.claude/settings.json and rebuild.
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _claudeSettings="${config.home.homeDirectory}/.claude/settings.json"
    if [ ! -e "$_claudeSettings" ]; then
      run mkdir -p "${config.home.homeDirectory}/.claude"
      run install -m600 ${settingsFile} "$_claudeSettings"
    fi
  '';
}
