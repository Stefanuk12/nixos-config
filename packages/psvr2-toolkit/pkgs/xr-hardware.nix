{ xr-hardware, fetchFromGitLab }:

# nixpkgs is on 1.1.1, which lacks the left Sense controller (054c:0e45). Drop once it moves to 1.1.2+.
xr-hardware.overrideAttrs (_: rec {
  version = "1.1.2";
  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "monado/utilities";
    repo = "xr-hardware";
    tag = version;
    hash = "sha256-stJjjencaO7cDOyVak2BaDnPQsjsX63+9dwY0Q//7To=";
  };
})
