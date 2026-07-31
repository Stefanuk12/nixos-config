{ pkgs, ... }:

let
  # Vencord with the vendored userplugins dropped into src/userplugins in preBuild: Atom1cByte's
  # Global-Search and the local streamer-mode override. Neither adds npm deps, so the pnpmDeps
  # cache is untouched.
  vencord-userplugins = pkgs.vencord.overrideAttrs (old: {
    preBuild = (old.preBuild or "") + ''
      mkdir -p src/userplugins/globalSearch src/userplugins/streamerModeOverride
      cp ${./global-search}/index.ts \
         ${./global-search}/MessageSearchChatBarIcon.tsx \
         ${./global-search}/MessageSearchModal.tsx \
         src/userplugins/globalSearch/
      cp ${./streamer-mode-override}/index.ts src/userplugins/streamerModeOverride/
      chmod -R u+w src/userplugins/globalSearch src/userplugins/streamerModeOverride
    '';
  });
in
{
  programs.vesktop.enable = true;

  # Vesktop's system-Vencord path, so it loads the patched build instead of self-managing Vencord.
  # Both are needed: the module re-overrides the package with
  # `withSystemVencord = cfg.vencord.useSystem`, so setting it here alone is silently undone and
  # the vencord argument below goes unused.
  programs.vesktop.vencord.useSystem = true;
  programs.vesktop.package = pkgs.vesktop.override {
    withSystemVencord = true;
    vencord = vencord-userplugins;
  };

  # https://github.com/Vencord/Vesktop/blob/main/src/shared/settings.d.ts
  programs.vesktop.settings = {
    discordBranch = "stable";
    hardwareAcceleration = true;
    arRPC = true;
    enableTaskbarFlashing = false;
    customTitleBar = true;
    spellCheckLanguages = [
      "en-GB"
      "en"
    ];
  };

  # https://github.com/Vendicated/Vencord/blob/main/src/api/Settings.ts
  programs.vesktop.vencord.settings = {
    plugins = {
      # Vendored userplugin, compiled into vencord-userplugins above.
      "Global Search".enabled = true;
      Experiments.enabled = true;
      CallTimer.enabled = true;
      ClearURLs.enabled = true;
      ExpressionCloner.enabled = true;
      FavoriteEmojiFirst.enabled = true;
      FixImagesQuality.enabled = true;
      FixSpotifyEmbeds.enabled = true;
      FixYoutubeEmbeds.enabled = true;
      ForceOwnerCrown.enabled = true;
      GifPaste.enabled = true;
      ImageLink.enabled = true;
      ImageZoom.enabled = true;
      MessageLogger = {
        enabled = true;
        ignoreSelf = true;
      };
      NoOnboardingDelay.enabled = true;
      NormalizeMessageLinks.enabled = true;
      PictureInPicture.enabled = true;
      PlatformIndicators.enabled = true;
      RelationshipNotifier.enabled = true;
      ReplaceGoogleSearch = {
        enabled = true;
        customEngineName = "DuckDuckGo";
        customEngineURL = "https://duckduckgo.com/?q=";
      };
      ReverseImageSearch.enabled = true;
      ShikiCodeblocks.enabled = true;
      ShowHiddenChannels.enabled = false;
      StreamerModeManualOverride.enabled = true;
      Translate.enabled = true;
      Unindent.enabled = true;
      ValidReply.enabled = true;
      ValidUser.enabled = true;
      VoiceChatDoubleClick.enabled = true;
      VoiceDownload.enabled = true;
      VoiceMessages.enabled = true;
      VolumeBooster.enabled = true;
      YouTubeAdblock.enabled = true;
    };
  };
}
