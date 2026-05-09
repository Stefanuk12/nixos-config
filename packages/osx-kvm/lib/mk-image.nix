# Builds OpenCore.qcow2 from a profile (+ optional extras).
#
# Pure derivation — mkfs.vfat → sgdisk → qemu-img convert; no
# guestfish or nested KVM.
#
# Two build-time gates run after the EFI tree is staged but before
# it's sealed into FAT:
#   1. OCSnapshot reconciles config.plist's ACPI/Drivers/Kexts/Tools
#      arrays against what's on disk (orphans dropped, missing entries
#      added, kext load order fixed via OSBundleLibraries walk).
#      Existing entry metadata (MinKernel, Comment, Strategy, Arch, …)
#      survives — the snapshot only rewrites disk-membership fields.
#   2. ocvalidate (matched to opencore.ocVersion) runs a full schema +
#      semantic check. Non-zero exit fails the build.
#
# Partition layout mirrors OSX-KVM's opencore-image-ng.sh:
#   p1 ESP      sectors 2048..300000   (~145 MB FAT32, label=EFI)
#   p2 OpenCore sectors 302048..end    (~234 MB FAT32, empty)
# p2 is unused but preserved so existing OVMF_VARS / recovery layouts
# match.

{ lib, runCommand, dosfstools, mtools, gptfdisk, qemu-utils, coreutils
, opencore, ocSnapshot, mkConfigPlist
}:

{ profile
, name             ? "OpenCore.qcow2"
, extraKexts       ? [ ]
, extraKextBlocks  ? [ ]
, extraAcpi        ? [ ]
, drivers          ? opencore.defaultDrivers
, plistOverrides   ? { }
, basePlist        ? opencore.samplePlist
}:

let
  ocBase      = opencore.mkEfi { inherit drivers; };
  kexts       = profile.kexts ++ extraKexts;
  acpi        = (profile.acpi or [ ]) ++ extraAcpi;
  configPlist = mkConfigPlist {
    inherit profile basePlist extraKexts extraKextBlocks extraAcpi
      plistOverrides drivers;
  };

  kextCopies = lib.concatMapStringsSep "\n" (k: ''
    mkdir -p efi/OC/Kexts/${k.name}
    cp -r ${k.bundle}/. efi/OC/Kexts/${k.name}/
  '') kexts;

  acpiCopies = lib.concatMapStringsSep "\n"
    (a: "cp ${a.source} efi/OC/ACPI/${a.name}") acpi;
in

runCommand name {
  outputs = [ "out" "plist" ];
  nativeBuildInputs = [ dosfstools mtools gptfdisk qemu-utils coreutils ];
} ''
  # Stage a writable EFI tree.
  mkdir -p efi
  cp -r ${ocBase}/. efi/
  chmod -R u+w efi
  ${kextCopies}
  ${acpiCopies}
  cp ${configPlist} efi/OC/config.plist
  chmod u+w efi/OC/config.plist

  ${ocSnapshot}/bin/oc-snapshot \
    -i efi/OC/config.plist -o efi/OC/config.plist \
    -s efi/OC -v latest
  ${opencore.ocvalidate}/bin/ocvalidate efi/OC/config.plist

  # Expose the post-snapshot/validate plist as a separate output so
  # callers can inspect it without cracking the qcow2.
  cp efi/OC/config.plist $plist

  # ESP FAT32 image (~145 MB).
  truncate -s 145M esp.img
  mkfs.vfat -F 32 -n EFI esp.img
  mmd -i esp.img ::/EFI ::/EFI/OC ::/EFI/BOOT \
                 ::/EFI/OC/Drivers ::/EFI/OC/Tools ::/EFI/OC/Kexts \
                 ::/EFI/OC/ACPI ::/EFI/OC/Resources
  for f in efi/BOOT/*; do mcopy -i esp.img "$f" ::/EFI/BOOT/; done
  for f in efi/OC/*.efi efi/OC/config.plist; do
    [ -e "$f" ] && mcopy -i esp.img "$f" ::/EFI/OC/
  done
  mcopy -i esp.img -s efi/OC/Drivers/.   ::/EFI/OC/Drivers/
  mcopy -i esp.img -s efi/OC/Tools/.     ::/EFI/OC/Tools/
  mcopy -i esp.img -s efi/OC/Kexts/.     ::/EFI/OC/Kexts/
  if [ -n "$(ls -A efi/OC/ACPI 2>/dev/null)" ]; then
    mcopy -i esp.img -s efi/OC/ACPI/. ::/EFI/OC/ACPI/
  fi
  mcopy -i esp.img -s efi/OC/Resources/. ::/EFI/OC/Resources/

  # Empty OpenCore data partition.
  truncate -s 234M oc.img
  mkfs.vfat -F 32 -n OpenCore oc.img

  # 384 MB GPT raw disk; splice both FAT images in.
  truncate -s 384M disk.img
  sgdisk --clear \
    --new=1:2048:300000 \
    --typecode=1:C12A7328-F81F-11D2-BA4B-00A0C93EC93B \
    --change-name=1:EFI \
    --new=2:302048:0 \
    --typecode=2:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
    --change-name=2:OpenCore \
    disk.img
  dd if=esp.img of=disk.img bs=512 seek=2048   conv=notrunc status=none
  dd if=oc.img  of=disk.img bs=512 seek=302048 conv=notrunc status=none

  qemu-img convert -f raw -O qcow2 disk.img $out
''
