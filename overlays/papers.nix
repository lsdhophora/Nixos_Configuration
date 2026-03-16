final: prev: {
  papers = prev.papers.overrideAttrs (old: {
    version = "50.0";
    src = prev.fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "GNOME";
      repo = "papers";
      rev = "50.0";
      hash = "sha256-3pus4MDgg0GWI5ayHRA+zS6JxXX+W8yjG/Un21GXRGo=";
    };
  });
}
