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

        # Node health check. The default target (cp.cloudflare.com) is
        # throttled or polluted through many subscription nodes, which then
        # reads as NOT ALIVE. A 204 endpoint has no body, so it costs
        # little traffic and stays reliable. The two extra addresses pin
        # the host resolution for the IPv4 and IPv6 checks.
        tcp_check_url: 'https://www.gstatic.com/generate_204,8.8.8.8,2001:4860:4860::8888'
        tcp_check_http_method: HEAD

        # Check every 15s, and switch as soon as another alive node is
        # even slightly faster. The default 50ms tolerance kept a
        # degrading node in place.
        check_interval: 15s
        check_tolerance: 10ms
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
          # min_avg10 is steadier than min_moving_avg for a subscription
          # whose nodes flap: it averages the last ten probes, so one slow
          # probe does not move the choice.
          policy: min_avg10
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

  # Restart dae when the rendered config changes. The unit loads the file
  # through LoadCredential, and systemd tracks the path, not its content.
  #
  # Two triggers, because a change has two shapes:
  # - the template text: its store file (.file) moves.
  # - the encrypted sops file: the subscription key changed, so the template
  #   text (and its store path) stays the same, but sopsFileHash changes.
  #
  # This uses the native restartTriggers path instead of sops restartUnits,
  # which still goes through the activation script that NixOS 26.11 removes.
  systemd.services.dae.restartTriggers = [
    config.sops.templates."dae-config".file
    config.sops.secrets.dae-subscription.sopsFileHash
  ];
}
