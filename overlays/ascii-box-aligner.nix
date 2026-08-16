# Package ascii-box-aligner (PyPI, zero-dependency) — not in nixpkgs (checked 2026-08).
# Aligns ASCII/Unicode box-drawing diagrams inside Markdown fenced code blocks,
# handling CJK full-width characters by visual width, nested and side-by-side boxes.
# CLI: `ascii-box-aligner [FILE...]` (stdin/stdout when FILE is `-`).
final: prev: {
  ascii-box-aligner = prev.python3.pkgs.buildPythonApplication {
    pname = "ascii-box-aligner";
    version = "0.1.0";
    pyproject = true;
    src = prev.fetchurl {
      # fetchPypi's /source/ URL 404s for this package (sdist filename uses
      # underscores: ascii_box_aligner-0.1.0.tar.gz), so pin the exact URL.
      url = "https://files.pythonhosted.org/packages/74/7a/3b11582028e6a97dcdb81838e8f1494202d4b15d30e6dc42640eeb279ab9/ascii_box_aligner-0.1.0.tar.gz";
      sha256 = "sha256-MhukcfchS+ab008XHFRJYgMsCc3s3V8bnlYbLv4PU68=";
    };
    build-system = [ prev.python3.pkgs.hatchling ];
    dependencies = [ ];
    meta = {
      description = "Align ASCII box-drawing diagrams in Markdown files, with CJK and nesting support";
      homepage = "https://pypi.org/project/ascii-box-aligner/";
      mainProgram = "ascii-box-aligner";
    };
  };
}
