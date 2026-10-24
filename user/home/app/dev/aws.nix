{ pkgs, ... }:

{
  # `programs.awscli` is avoided on purpose: it makes ~/.aws/config a read-only store symlink,
  # which breaks `aws login` / `aws configure sso` writing profiles.
  home.packages = with pkgs; [
    awscli2
    # The aws-core Claude Code plugin launches the AWS MCP Server via `uvx mcp-proxy-for-aws-cli`.
    uv
  ];
}
