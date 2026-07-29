final: prev: {
  kdePackages = prev.kdePackages // {
    plasma-desktop = prev.kdePackages.plasma-desktop.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or []) ++ [
        ./../patches/plasma-desktop/lookandfeelbox-highlight-border.patch
        ./../patches/plasma-desktop/hide-virtual-keyboard-button.patch
        ./../patches/plasma-desktop/lockscreen-cleanup-on-unlock.patch
      ];
    });
  };
}
