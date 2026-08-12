{ config, pkgs, ... }:

{
  sops.secrets.dae-subscription = {
    mode = "0600";
    owner = "root";
    group = "root";
  };

  sops.templates."dae-config" = {
    content = ''
      global {
        wan_interface: auto
        log_level: info
        allow_insecure: false
        auto_config_kernel_parameter: true
      }

      subscription {
        flybit: '${config.sops.placeholder."dae-subscription"}'
      }

      dns {
        upstream {
          googledns: 'tcp+udp://dns.google:53'
          alidns: 'udp://dns.alidns.com:53'
        }
        routing {
          request {
            qtype(https) -> reject
            fallback: alidns
          }
          response {
            upstream(googledns) -> accept
            ip(geoip:private) && !qname(geosite:cn) -> googledns
            fallback: accept
          }
        }
      }

      group {
        proxy {
          policy: min_moving_avg
        }
      }

      routing {
        pname(NetworkManager) -> direct
        # ZeroTier control + hole-punching traffic must stay direct
        # (pname covers egress; dport covers ingress to the laptop's 9993).
        pname(zerotier-one) -> direct
        l4proto(udp) && dport(9993) -> direct
        dip(224.0.0.0/3, 'ff00::/8') -> direct
        l4proto(udp) && dport(443) -> block
        dip(geoip:private) -> direct
        dip(geoip:cn) -> direct
        domain(geosite:cn) -> direct
        fallback: proxy
      }
    '';
    owner = "root";
    group = "root";
  };

  services.dae = {
    enable = true;
    configFile = config.sops.templates."dae-config".path;
  };
}
