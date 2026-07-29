{ ... }:

{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "nixos_small";
        padding = {
          top = 1;
          right = 3;
        };
      };

      display.separator = "  ";

      modules = [
        "break"
        {
          type = "title";
          format = "{user-name}@{host-name}";
        }
        "separator"

        { type = "os"; key = "  os"; }
        { type = "kernel"; key = "  kernel"; format = "{release}"; }
        { type = "uptime"; key = "  uptime"; }
        { type = "packages"; key = "  packages"; }
        { type = "shell"; key = "  shell"; }

        "break"

        { type = "wm"; key = "  wm"; }
        { type = "terminal"; key = "  term"; }
        { type = "display"; key = "  display"; compactType = "original-with-refresh-rate"; }

        "break"

        { type = "cpu"; key = "  cpu"; }
        { type = "gpu"; key = "  gpu"; }
        { type = "memory"; key = "  memory"; }
        { type = "disk"; key = "  disk"; folders = "/"; }

        "break"
        "colors"
        "break"
      ];
    };
  };
}
