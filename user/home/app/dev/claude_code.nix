{ pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    settings = {
      theme = "dark";
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
}