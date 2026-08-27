# Package mermaid-ascii: render Mermaid graph language and Markdown tables to
# ASCII/Unicode text. Replaces the ascii-align / ascii-box-aligner pair.
#
# The ASCII engine is the CJK-fixed fork of beautiful-mermaid's vendored
# pipeline (okooo5km/beautiful-mermaid-cli v0.2.4, src/ascii): it measures
# width by terminal display columns (get-east-asian-width, CJK=2 cells)
# instead of String#length, so boxes/edges stay aligned with CJK labels.
# parseMermaid still comes from upstream beautiful-mermaid@1.1.3.
final: prev: {
  mermaid-ascii = prev.stdenv.mkDerivation {
    pname = "mermaid-ascii";
    version = "2.0.0";
    # beautiful-mermaid-cli v0.2.4 carries dist/ascii, the CJK-fixed
    # vendored ASCII pipeline (the -cli parts are unused).
    src = prev.fetchurl {
      url = "https://registry.npmjs.org/beautiful-mermaid-cli/-/beautiful-mermaid-cli-0.2.4.tgz";
      sha256 = "sha256-qNGTuwvpQapWXqTGTR7q2fEiDq++3fF9J4lHxEICg68=";
    };
    # upstream beautiful-mermaid: parseMermaid (parser only).
    bm = prev.fetchurl {
      url = "https://registry.npmjs.org/beautiful-mermaid/-/beautiful-mermaid-1.1.3.tgz";
      sha256 = "sha256-TUNvJ7sBAphZQMPv4xcVP00fU/IPAp8ia2Dhq0trn/A=";
    };
    # East Asian Width maps to terminal cells (CJK/wide = 2, ambiguous = 1).
    geaw = prev.fetchurl {
      url = "https://registry.npmjs.org/get-east-asian-width/-/get-east-asian-width-1.6.0.tgz";
      sha256 = "sha256-RFH1ji9aTvJ66LS6JbZL6X06hBPchhSkMhoQ1Bju5tc=";
    };
    # dist/index.js imports elkjs + entities at runtime (see package.json deps).
    elkjs = prev.fetchurl {
      url = "https://registry.npmjs.org/elkjs/-/elkjs-0.11.1.tgz";
      sha256 = "sha256-g5c+JDtEhCNTcXQn7o6hiA1ojr55Y01AF+PMMPMhSko=";
    };
    entities = prev.fetchurl {
      url = "https://registry.npmjs.org/entities/-/entities-7.0.1.tgz";
      sha256 = "sha256-VUt+Knn6ntoEOXFAEfpC13xoKYQvqpHgIgcAFb/Ug6A=";
    };
    sourceRoot = "package"; # npm tarballs wrap files in a top-level package/
    nativeBuildInputs = [ prev.makeWrapper ];
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/mermaid-ascii/dist $out/bin
      mkdir -p $out/lib/mermaid-ascii/node_modules/beautiful-mermaid \
               $out/lib/mermaid-ascii/node_modules/get-east-asian-width \
               $out/lib/mermaid-ascii/node_modules/elkjs \
               $out/lib/mermaid-ascii/node_modules/entities
      # CJK-fixed ASCII engine (dist/ascii + parsers + shapes)
      cp -r dist/* $out/lib/mermaid-ascii/dist/
      # width model patch: Iosevka renders symbol blocks at 2 cells
      cp ${../patches/mermaid-ascii/width.js} $out/lib/mermaid-ascii/dist/ascii/width.js
      # upstream parser
      tar xzf $bm -C $out/lib/mermaid-ascii/node_modules/beautiful-mermaid --strip-components=1
      # width model
      tar xzf $geaw -C $out/lib/mermaid-ascii/node_modules/get-east-asian-width --strip-components=1
      # runtime deps of beautiful-mermaid's dist/index.js
      tar xzf $elkjs -C $out/lib/mermaid-ascii/node_modules/elkjs --strip-components=1
      tar xzf $entities -C $out/lib/mermaid-ascii/node_modules/entities --strip-components=1
      cp ${../patches/mermaid-ascii/cli.mjs} $out/lib/mermaid-ascii/cli.mjs
      makeWrapper ${prev.nodejs}/bin/node $out/bin/mermaid-ascii \
        --add-flags $out/lib/mermaid-ascii/cli.mjs
      runHook postInstall
    '';
    meta = {
      description = "Render Mermaid graph language and Markdown tables to ASCII";
      homepage = "https://github.com/okooo5km/beautiful-mermaid-cli";
      license = prev.lib.licenses.mit;
      mainProgram = "mermaid-ascii";
    };
  };
}
