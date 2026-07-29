{ config, lib, pkgs, ... }:

let
  firmware = pkgs.runCommand "mt7927-mt6639-bt-firmware" { } ''
    for d in mt7927 mt6639; do
      mkdir -p "$out/lib/firmware/mediatek/$d"
      cp ${./BT_RAM_CODE_MT6639_2_1_hdr.bin} \
         "$out/lib/firmware/mediatek/$d/BT_RAM_CODE_MT6639_2_1_hdr.bin"
    done
  '';
in
{
  hardware.firmware = [ firmware ];
}
