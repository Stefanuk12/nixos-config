{ ... }:

{
  programs.git.signing = {
    format = "openpgp";
    key = "0xE02188A5893B2E42";
    signByDefault = true;
  };
}
