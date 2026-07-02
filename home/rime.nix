{ config, pkgs, lib, ... }:

let
  rimeIceData = "${pkgs.rime-ice}/share/rime-data";
  rimeDir = "${config.xdg.configHome}/ibus/rime";

  patchedSchema = pkgs.runCommand "rime_ice-schema-patched" {} ''
    cp ${pkgs.rime-ice}/share/rime-data/rime_ice.schema.yaml $out
    substituteInPlace $out --replace-fail "name: 雾凇拼音" "name: 拼音"
  '';

  topLevelFiles = [
    "rime_ice.dict.yaml" "rime_ice_suggestion.yaml"
    "melt_eng.schema.yaml" "melt_eng.dict.yaml"
    "radical_pinyin.schema.yaml" "radical_pinyin.dict.yaml"
    "t9.schema.yaml"
    "double_pinyin.schema.yaml" "double_pinyin_abc.schema.yaml"
    "double_pinyin_flypy.schema.yaml" "double_pinyin_jiajia.schema.yaml"
    "double_pinyin_mspy.schema.yaml" "double_pinyin_sogou.schema.yaml"
    "double_pinyin_ziguang.schema.yaml"
    "symbols_v.yaml" "symbols_caps_v.yaml"
    "squirrel.yaml" "weasel.yaml"
    "custom_phrase.txt" "recipe.yaml"
    "AGENTS.md" "LICENSE" "go.work"
  ];

  directories = [ "cn_dicts" "en_dicts" "lua" "opencc" ];
in {
  home.packages = [ pkgs.rime-ice ];

  home.file =
    (lib.listToAttrs (map (f: {
      name = "${rimeDir}/${f}";
      value = {
        source = "${rimeIceData}/${f}";
        force = true;
      };
    }) topLevelFiles))
    //
    (lib.listToAttrs (map (d: {
      name = "${rimeDir}/${d}";
      value = {
        source = "${rimeIceData}/${d}";
        recursive = true;
        force = true;
      };
    }) directories))
    //
    {
      "${rimeDir}/default.yaml" = {
        source = ./../assets/rime/default.yaml;
        force = true;
      };
      "${rimeDir}/ibus_rime.custom.yaml" = {
        source = ./../assets/rime/ibus_rime.custom.yaml;
        force = true;
      };
      "${rimeDir}/rime_ice.custom.yaml" = {
        source = ./../assets/rime/rime_ice.custom.yaml;
        force = true;
      };
      "${rimeDir}/rime_ice.schema.yaml" = {
        source = patchedSchema;
        force = true;
      };
    };
}
