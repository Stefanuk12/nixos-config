{ pkgs, ... }:

{
  programs.vesktop.enable = true;

  # https://github.com/Vencord/Vesktop/blob/main/src/shared/settings.d.ts
  programs.vesktop.settings = {

  };

  # https://github.com/Vendicated/Vencord/blob/main/src/api/Settings.ts
  programs.vesktop.vencord.settings = {
    plugins = {
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
      ShowHiddenChannels.enabled = true;
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
