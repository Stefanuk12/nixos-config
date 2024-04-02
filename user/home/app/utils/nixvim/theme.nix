{ config, ... }:
let
  setupBasicTheme = { name, background, theme }: {
    name = name;
    config = ''
      vim.go.background = "${background}"
      require("${name}").colorscheme()
      require("lualine").setup({
        options = { theme = "${theme}" }
      })
    '';
  };

  nvimTheme = {
    ayu-dark = setupBasicTheme {
      name = "ayu";
      background = "dark";
      theme = "ayu_dark";
    };
    ayu-mirage = {
      name = "ayu";
      config = ''
        vim.go.background = "dark"
        require("ayu").setup({ mirage = true })
        require("ayu").colorscheme()
        require("lualine").setup({
          options = { theme = "ayu_mirage" }
        })
      '';
    };
    ayu-light = setupBasicTheme {
      name = "ayu";
      background = "light";
      theme = "ayu_light";
    };
  };
in {
  programs.nixvim = {
    colorschemes.${nvimTheme.${config.colorScheme.slug}.name}.enable = true;
    extraConfigLua = nvimTheme.${config.colorScheme.slug}.config;
  };
}
