final: prev: {
  gnome-calendar = prev.gnome-calendar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/gnome-calendar/remove-weather.patch
    ];
  });
}
