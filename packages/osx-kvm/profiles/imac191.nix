# iMac19,1 SMBIOS profile: conservative fallback without the MP7,1 MCE/Cryptex baggage, useful for bisecting whether a problem is SMBIOS-driven.
#
# No AppleMCEReporterDisabler: iMac19,1's board-id isn't in AppleIntelMCEReporter's match list, so the disabler would be a no-op.

{ kexts }:

{
  smbios = {
    productName = "iMac19,1";
    serial = "C02YP2Z3JV3Q";
    mlb = "C02919303J9LNV91M";
    uuid = "BBA8B560-FF19-4CA6-B59B-BF1FB997CBF8";
    romMac = "87:AC:AD:CE:88:01";
  };

  bootArgs = "keepsyms=1 agdpmod=pikera";

  kexts = [
    { name = "Lilu.kext"; bundle = kexts.Lilu;
      bundlePath = "Lilu.kext"; executablePath = "Contents/MacOS/Lilu"; }
    { name = "VirtualSMC.kext"; bundle = kexts.VirtualSMC;
      bundlePath = "VirtualSMC.kext"; executablePath = "Contents/MacOS/VirtualSMC"; }
    { name = "WhateverGreen.kext"; bundle = kexts.WhateverGreen;
      bundlePath = "WhateverGreen.kext";
      executablePath = "Contents/MacOS/WhateverGreen"; minKernel = "10.0.0"; }
    { name = "AppleALC.kext"; bundle = kexts.AppleALC;
      bundlePath = "AppleALC.kext"; executablePath = "Contents/MacOS/AppleALC"; }
  ];
}
