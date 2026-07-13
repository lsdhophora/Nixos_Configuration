{
  pkgs,
  lib,
  ...
}:

{
  services.pipewire = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.pipewire;
    wireplumber.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  services.pipewire.wireplumber.extraConfig."99-disable-suspend" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "~alsa_input.*"; }
          { "node.name" = "~alsa_output.*"; }
        ];
        actions = {
          update-props = {
            "session.suspend-timeout-seconds" = 0;
          };
        };
      }
    ];
  };

  # RNNoise + stereo noise gate (dual mono LADSPA gate_1410)
  services.pipewire.configPackages = [
    (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/99-noise-cancel.conf" ''
      context.modules = [
        {   name = libpipewire-module-filter-chain
            args = {
                node.description = "Noise Canceling Source"
                media.name = "Noise Canceling Source"
                filter.graph = {
                    nodes = [
                        {
                            type = ladspa
                            name = rnnoise
                            plugin = "librnnoise_ladspa"
                            label = noise_suppressor_stereo
                            control = {
                                "VAD Threshold (%)" 30.0
                            }
                        }
                        {
                            type = ladspa
                            name = gateL
                            plugin = "gate_1410"
                            label = gate
                            control = {
                                "Threshold (dB)" = -50.0
                                "Attack (ms)" = 10.0
                                "Hold (ms)" = 200.0
                                "Decay (ms)" = 500.0
                                "Range (dB)" = -60.0
                            }
                        }
                        {
                            type = ladspa
                            name = gateR
                            plugin = "gate_1410"
                            label = gate
                            control = {
                                "Threshold (dB)" = -50.0
                                "Attack (ms)" = 10.0
                                "Hold (ms)" = 200.0
                                "Decay (ms)" = 500.0
                                "Range (dB)" = -60.0
                            }
                        }
                    ]
                    inputs = [ "rnnoise:Input (L)" "rnnoise:Input (R)" ]
                    outputs = [ "gateL:Output" "gateR:Output" ]
                    links = [
                        { output = "rnnoise:Output (L)" input = "gateL:Input" }
                        { output = "rnnoise:Output (R)" input = "gateR:Input" }
                    ]
                }
                audio.position = [ FL FR ]
                capture.props = {
                    node.name = "capture.noise_cancel"
                    audio.position = [ FL FR ]
                    stream.dont-remix = true
                    target.object = "alsa_input.pci-0000_03_00.6.HiFi__Mic1__source"
                    node.passive = true
                }
                playback.props = {
                    node.name = "noise_cancel_source"
                    media.class = "Audio/Source"
                    audio.position = [ FL FR ]
                }
            }
        }
      ]
    '')
  ];

  environment.systemPackages = [ pkgs.rnnoise-plugin pkgs.ladspaPlugins ];

  services.pipewire.extraLadspaPackages = [ pkgs.rnnoise-plugin pkgs.ladspaPlugins ];
}
