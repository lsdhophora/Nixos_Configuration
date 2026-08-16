# Package mermaid-ascii: render Mermaid graph language and Markdown tables to
# ASCII/Unicode text. Replaces the ascii-align / ascii-box-aligner pair.
# Uses beautiful-mermaid (the same renderer pi's pi-mermaid extension uses).
# Auto-layout means output is always aligned — no post-fix tools needed.
final: prev: {
  mermaid-ascii = prev.stdenv.mkDerivation {
    pname = "mermaid-ascii";
    version = "1.1.3";
    src = prev.fetchurl {
      url = "https://registry.npmjs.org/beautiful-mermaid/-/beautiful-mermaid-1.1.3.tgz";
      sha256 = "sha256-TUNvJ7sBAphZQMPv4xcVP00fU/IPAp8ia2Dhq0trn/A=";
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
      mkdir -p $out/lib/mermaid-ascii/node_modules/elkjs $out/lib/mermaid-ascii/node_modules/entities $out/bin
      cp -r dist package.json $out/lib/mermaid-ascii/
      cp ${../patches/mermaid-ascii/cli.mjs} $out/lib/mermaid-ascii/cli.mjs
      tar xzf $elkjs -C $out/lib/mermaid-ascii/node_modules/elkjs --strip-components=1
      tar xzf $entities -C $out/lib/mermaid-ascii/node_modules/entities --strip-components=1
      makeWrapper ${prev.nodejs}/bin/node $out/bin/mermaid-ascii \
        --add-flags $out/lib/mermaid-ascii/cli.mjs
      runHook postInstall
    '';
    meta = {
      description = "Render Mermaid graph language and Markdown tables to ASCII";
      homepage = "https://github.com/lukilabs/beautiful-mermaid";
      license = prev.lib.licenses.mit;
      mainProgram = "mermaid-ascii";
    };
  };
}
