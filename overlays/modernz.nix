let
  applyPatches = (import ../lib).applyPatches;
in
final: prev: {
  mpvScripts = prev.mpvScripts // {
    modernz = applyPatches [
      ../patches/modernz/remove-text-bord.patch
    ] prev.mpvScripts.modernz;
  };
}
