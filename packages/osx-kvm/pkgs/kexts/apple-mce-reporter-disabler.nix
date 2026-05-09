# Plist-only kext (RehabMan, GPLv2). No executable — its
# IOKitPersonalities steal Apple's MCE matching to keep
# AppleIntelMCEReporter off non-ECC guest RAM. Generated inline to
# avoid depending on third-party hosts.

{ writeText, runCommand }:

let
  infoPlist = writeText "Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key><string>English</string>
      <key>CFBundleGetInfoString</key><string>AppleMCEReporterDisabler 0.5</string>
      <key>CFBundleIdentifier</key><string>org.rehabman.disabler.MCEReporter</string>
      <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
      <key>CFBundleName</key><string>AppleMCEReporterDisabler</string>
      <key>CFBundlePackageType</key><string>KEXT</string>
      <key>CFBundleVersion</key><string>0.5</string>
      <key>IOKitPersonalities</key>
      <dict>
        <key>MCEInterruptControllerDisabler</key>
        <dict>
          <key>CFBundleIdentifier</key><string>com.apple.driver.AppleIntelMCEReporter</string>
          <key>IOClass</key><string>IOService</string>
          <key>IOMatchCategory</key><string>AppleIntelMCEInterruptController</string>
          <key>IOProbeScore</key><integer>5000</integer>
          <key>IOPropertyMatch</key>
          <array>
            <dict><key>board-id</key><string>Mac-F60DEB81FF30ACF6</string></dict>
            <dict><key>board-id</key><string>Mac-7BA5B2D9E42DDD94</string></dict>
            <dict><key>board-id</key><string>Mac-27AD2F918AE68F61</string></dict>
          </array>
          <key>IOProviderClass</key><string>IOPlatformExpertDevice</string>
        </dict>
        <key>MCEReporterDisabler</key>
        <dict>
          <key>CFBundleIdentifier</key><string>com.apple.driver.AppleIntelMCEReporter</string>
          <key>IOClass</key><string>IOService</string>
          <key>IOMatchCategory</key><string>AppleIntelMCEReporter</string>
          <key>IOProbeScore</key><integer>5000</integer>
          <key>IOProviderClass</key><string>AppleIntelMCEInterruptNub</string>
        </dict>
      </dict>
    </dict>
    </plist>
  '';
in
runCommand "AppleMCEReporterDisabler-0.5" { } ''
  mkdir -p $out/Contents
  cp ${infoPlist} $out/Contents/Info.plist
''
