{ nixpkgs-unstable, system, config }:
let
  unstable = import nixpkgs-unstable { inherit system config; };
in
final: prev: {
  cosmic-applets = unstable.cosmic-applets;
  cosmic-applibrary = unstable.cosmic-applibrary;
  cosmic-bg = unstable.cosmic-bg;
  cosmic-comp = unstable.cosmic-comp;
  cosmic-files = unstable.cosmic-files;
  cosmic-greeter = unstable.cosmic-greeter;
  cosmic-idle = unstable.cosmic-idle;
  cosmic-initial-setup = unstable.cosmic-initial-setup;
  cosmic-launcher = unstable.cosmic-launcher;
  cosmic-notifications = unstable.cosmic-notifications;
  cosmic-osd = unstable.cosmic-osd;
  cosmic-panel = unstable.cosmic-panel;
  cosmic-session = unstable.cosmic-session;
  cosmic-settings = unstable.cosmic-settings;
  cosmic-settings-daemon = unstable.cosmic-settings-daemon;
  cosmic-workspaces-epoch = unstable.cosmic-workspaces-epoch;
  cosmic-edit = unstable.cosmic-edit;
  cosmic-icons = unstable.cosmic-icons;
  cosmic-player = unstable.cosmic-player;
  cosmic-randr = unstable.cosmic-randr;
  cosmic-reader = unstable.cosmic-reader;
  cosmic-screenshot = unstable.cosmic-screenshot;
  cosmic-store = unstable.cosmic-store;
  cosmic-term = unstable.cosmic-term;
  cosmic-wallpapers = unstable.cosmic-wallpapers;
  xdg-desktop-portal-cosmic = unstable.xdg-desktop-portal-cosmic;
}
