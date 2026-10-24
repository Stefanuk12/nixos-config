{ pkgs, ... }:

{
  # texliveSmall plus what the resume template needs; scheme-medium is avoided since asymptote fails to build.
  home.packages = with pkgs; [
    (texliveSmall.withPackages (
      ps: with ps; [
        latexmk
        titlesec
        marvosym
        enumitem
        fancyhdr
        preprint
        # Type 1 T1-encoded CM fonts, incl. the bold small caps used for the name.
        cm-super
      ]
    ))
  ];
}
