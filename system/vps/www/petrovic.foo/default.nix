{ pkgs, ... }:

import ../mkStaticSite.nix { inherit pkgs; name = "petrovic.foo"; dir = ./.; }
