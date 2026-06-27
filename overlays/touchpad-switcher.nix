final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    touchpad-switcher = prev.gnomeExtensions.touchpad-switcher.overrideAttrs (old: {
      version = "14";
      src = prev.fetchurl {
        url = "https://extensions.gnome.org/extension-data/touchpadgpawru.v14.shell-extension.zip";
        hash = "sha256-V7EdsYMaw475bbRwf0bp/xZOm9muyEQpaB3Fna7qgHo=";
      };
      sourceRoot = ".";
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        prev.unzip
      ];
    });
  };
}
