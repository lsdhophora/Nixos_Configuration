{
  config,
  inputs,
  pkgs,
  repoLib,
  ...
}:

let
  # dae 2.0.0 from nixpkgs-unstable. The 1.0.0 in nixpkgs 26.05 lacks the
  # sub(), node() and subnode() selectors of the DNS request routing.
  dae = (repoLib.unstablePkgs inputs pkgs).dae;
in

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
        mojie: '${config.sops.placeholder."dae-subscription"}'
      }

      dns {
        upstream {
          googledns: 'tcp+udp://dns.google:53'
          alidns: 'udp://dns.alidns.com:53'
        }
        routing {
          request {
            qtype(https) -> reject

            # Resolve the host names of the subscription and of the nodes
            # with alidns. The router of this network answers a stale
            # address for p4.cnt.linuxlh.xin. dae dials the system address
            # of a node when no rule matches, so a stale answer breaks
            # every node of that family. Keep these rules close to the
            # top: the selectors do not use the fallback.
            sub(regex: '.*') -> alidns
            subnode(regex: '.*') -> alidns
            node(name_regex: '.+') -> alidns

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
          filter: !name(keyword: '剩余流量') && !name(keyword: '套餐到期') && !name(keyword: '过滤掉')
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
    package = dae;
    configFile = config.sops.templates."dae-config".path;
  };
}
