final: prev: {
  localsend = prev.localsend.overrideAttrs (old: {
    preConfigure = (old.preConfigure or "") + ''
      patchFileSelectorPlugin() {
        echo "localsend-overlay: searching for file_selector_linux..."
        ROOT=$(jq -r '.packages[] | select(.name == "file_selector_linux") | .rootUri' .dart_tool/package_config.json | sed 's|^file://||')
        echo "localsend-overlay: root=$ROOT"
        if [ -n "$ROOT" ] && [ "$ROOT" != "null" ] && [ -d "$ROOT" ]; then
          echo "localsend-overlay: copying $ROOT to writable location..."
          mkdir -p .dart_tool/patched
          rm -rf .dart_tool/patched/file_selector_linux
          cp -r "$ROOT" .dart_tool/patched/file_selector_linux
          chmod -R u+w .dart_tool/patched/file_selector_linux

          PATCH="${../patches/file_selector_linux/file-selector-plugin.patch}"
          echo "localsend-overlay: applying patch..."
          (cd .dart_tool/patched/file_selector_linux && patch -p1 < "$PATCH" && echo "localsend-overlay: patch applied successfully")

          echo "localsend-overlay: patching header signature..."
          sed -i \
            's|GtkFileChooserNative\* create_dialog_of_type|GtkWidget* create_dialog_of_type|' \
            .dart_tool/patched/file_selector_linux/linux/file_selector_plugin_private.h

          echo "localsend-overlay: updating package_config.json..."
          chmod u+w .dart_tool/package_config.json
          jq "(.packages[] | select(.name == \"file_selector_linux\") | .rootUri) |= \"file://$PWD/.dart_tool/patched/file_selector_linux\"" \
            .dart_tool/package_config.json > .dart_tool/package_config.json.tmp
          mv .dart_tool/package_config.json.tmp .dart_tool/package_config.json
          chmod u-w .dart_tool/package_config.json
        else
          echo "localsend-overlay: ROOT not found or not a directory, skipping"
        fi
      }
      echo "localsend-overlay: registering patchFileSelectorPlugin hook"
      postConfigureHooks+=(patchFileSelectorPlugin)
      echo "localsend-overlay: patchFileSelectorPlugin registered as postConfigureHook"
    '';
  });
}
