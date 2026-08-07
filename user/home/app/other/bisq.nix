{ pkgs, ... }:

{
  # Two separate P2P networks rather than old and new versions of one app: Bisq 1 holds the fiat
  # and altcoin liquidity, Bisq 2 has the Bisq Easy protocol.
  #
  # Both ship lib/app/desktop.jar, which collides in the profile. Their jpackage launchers find
  # their own store path rather than going through the profile, so linking only bin and share
  # drops the conflict without either app losing anything it reads at runtime.
  home.packages = [
    (pkgs.buildEnv {
      name = "bisq";
      paths = [ pkgs.bisq1 pkgs.bisq2 ];
      pathsToLink = [ "/bin" "/share" ];
    })
  ];
}
