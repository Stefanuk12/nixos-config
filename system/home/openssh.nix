{ ... }:

{
  # hydenix used to enable this. Beyond remote access, sops-nix derives its decryption key from
  # the ed25519 host key *only when this is on* — with it off, sops.age.sshKeyPaths evaluates to
  # [] and every secret fails to decrypt with "0 successful groups required, got 0".
  services.openssh.enable = true;

  # Pinned rather than inherited, so toggling sshd can never silently break secret decryption
  # again. The host key itself is unchanged, so existing secrets still decrypt.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
}
