{ pkgs, ... }:

{
  extFromMarketplace =
    name: publisher: version: sha256:
    (pkgs.vscode-utils.extensionFromVscodeMarketplace {
      inherit
        name
        publisher
        version
        sha256
        ;
    });
  buildVscodeExtensionFromGitHub =
    {
      name,
      publisher,
      version,
      src,
      npmDepsHash,
      srcSubdir ? name,
      nativeBuildInputs ? [
        pkgs.nodejs
        pkgs.vsce
      ],
      vsceBuildFlags ? "--no-dependencies --allow-missing-repository",
      extraAttrs ? { },
    }:
    let
      vsix = pkgs.buildNpmPackage (
        {
          pname = name;
          inherit version;
          src = "${src}/${srcSubdir}";
          inherit npmDepsHash nativeBuildInputs;
          buildPhase = ''
            runHook preBuild
            touch LICENSE
            vsce package ${vsceBuildFlags} -o extension.vsix
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp extension.vsix $out/extension.zip
            runHook postInstall
          '';
        }
        // extraAttrs
      );
    in
    pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      mktplcRef = { inherit publisher name version; };
      vsix = "${vsix}/extension.zip";
    };
}
