# Online judge toolchain fixes for AtCoder.
#
# 1. Patch online-judge-api-client: AtCoder problem pages now show
#    "Memory Limit: 1024 MiB".  Upstream only accepts KB/MB, so
#    `oj submit` crashes with:
#      AssertionError: assert parsed_memory_limit (atcoder.py _from_html)
#
# 2. Add online-judge-template-generator (provides `oj-prepare` /
#    `oj-template` for whole-contest preparation).  Not packaged in
#    nixpkgs, so we build it from the upstream GitHub source.
final: prev:
let
  py = prev.python3Packages;
in
{
  python3Packages = py.overrideScope (pypkgs: pypkgsPrev: {
    online-judge-api-client = pypkgsPrev.online-judge-api-client.overridePythonAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../patches/online-judge-mib.patch ];
    });

    online-judge-template-generator = pypkgs.buildPythonPackage {
      pname = "online-judge-template-generator";
      version = "4.8.1";
      src = prev.fetchFromGitHub {
        owner = "online-judge-tools";
        repo = "template-generator";
        rev = "v4.8.1";
        sha256 = "1a4n3nxli3z6aqzq1r5pi5c1q6lg0p2vg89fmc2z3ndxaq7l8bbi";
      };
      pyproject = true;
      build-system = [ pypkgs.setuptools ];
      pythonImportsCheck = [ "onlinejudge_template" "onlinejudge_prepare" ];
      nativeBuildInputs = [ pypkgs.setuptools ];
      propagatedBuildInputs = with pypkgs; [
        appdirs
        beautifulsoup4
        colorlog
        mako
        online-judge-api-client
        online-judge-tools
        ply
        pyyaml
        requests
        setuptools
        toml
      ];
      doCheck = false;
    };
  });

  # Make sure the system-level binary follows the patched python scope.
  online-judge-tools = final.python3Packages.online-judge-tools;
}
