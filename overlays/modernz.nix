{ repoLib }: final: prev: {
  mpvScripts = prev.mpvScripts // {
    modernz = repoLib.applyPatches [
      ../patches/modernz/remove-text-bord.patch
    ] prev.mpvScripts.modernz;
  };
}
