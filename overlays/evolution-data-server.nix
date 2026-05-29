final: prev: {
  evolution-data-server = prev.evolution-data-server.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/evolution-data-server/no-contacts-calendar-backend.patch
    ];
  });
}
