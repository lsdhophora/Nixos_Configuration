final: prev: {
  epiphany = prev.epiphany.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/epiphany-remove-send-via-email.patch
    ];
  });
}
