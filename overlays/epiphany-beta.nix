final: prev:

let
  gtk4-beta = prev.gtk4.overrideAttrs (old: {
    version = "4.21.5";
    src = prev.fetchurl {
      url = "https://download.gnome.org/sources/gtk/4.21/gtk-4.21.5.tar.xz";
      hash = "sha256-ZT2g1VahGj57fTbW77ybFkfLJbjoH0DslAvQh4niSBw=";
    };
  });
in

{
  gtk4 = gtk4-beta;

  epiphany =
    (prev.epiphany.override {
      gtk4 = gtk4-beta;
    }).overrideAttrs
      (old: {
        version = "50.beta";
        src = prev.fetchFromGitLab {
          domain = "gitlab.gnome.org";
          owner = "GNOME";
          repo = "epiphany";
          rev = "50.beta";
          hash = "sha256-lG70GeAsVnBaXzpfQqkUcjQ4dZqXfh+ug0NhvZWobWY=";
        };

        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ (with prev; [
            shared-mime-info
            desktop-file-utils
            glib
          ]);
      });
}
