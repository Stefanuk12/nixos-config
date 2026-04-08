{ ... }:

{
  programs.mise.enable = true;
  programs.mise.globalConfig = {
    settings = {
      all_compile = true;
    };
  };
}