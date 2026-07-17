{ pkgs, ... }:

import ../mkStaticSite.nix { inherit pkgs; name = "donate.petrovic.foo"; dir = ./.; }
