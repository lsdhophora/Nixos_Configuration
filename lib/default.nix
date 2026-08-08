# Shared helper functions.
# Import with: (import ../lib) — resolves to this file.

{
  # Add patch files to a package, preserving any existing patches.
  # Example: applyPatches [ ./fix.patch ] pkg
  applyPatches =
    patches: pkg:
    pkg.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });
}
