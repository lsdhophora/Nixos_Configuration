{ lib, pkgs, config, ... }:

let
  capslock-led = pkgs.runCommandCC "capslock-led" {} ''
    mkdir -p $out/bin
    cat > $out/capslock-led.c << 'CEOF'
    #include <stdio.h>
    #include <stdlib.h>
    #include <fcntl.h>
    #include <unistd.h>
    #include <string.h>
    #include <linux/input.h>
    #include <glob.h>
    #include <limits.h>

    int main(int argc, char *argv[]) {
      if (argc != 2) return 1;
      int value = atoi(argv[1]);

      glob_t g;
      if (glob("/sys/class/leds/input*::capslock", 0, NULL, &g) || !g.gl_pathc)
        return 1;

      char resolved[PATH_MAX] = {};
      if (!realpath(g.gl_pathv[0], resolved))
        return 1;
      globfree(&g);

      char *p = resolved, *last = NULL;
      while ((p = strstr(p, "/input")) != NULL) { last = p; p++; }
      if (!last) return 1;
      p = last + 6;

      char num[16] = {};
      int i = 0;
      while (p[i] >= '0' && p[i] <= '9') { num[i] = p[i]; i++; }

      char devpath[64];
      snprintf(devpath, sizeof(devpath), "/dev/input/event%s", num);

      int fd = open(devpath, O_RDWR);
      if (fd < 0) return 1;

      struct input_event ev;
      memset(&ev, 0, sizeof(ev));
      ev.type = EV_LED;
      ev.code = LED_CAPSL;
      ev.value = value;

      int r = write(fd, &ev, sizeof(ev));
      close(fd);
      return r < 0;
    }
    CEOF
    $CC -O2 -Wall -o $out/bin/capslock-led $out/capslock-led.c
    rm $out/capslock-led.c
  '';
in {
  services.kanata = {
    enable = true;
    package = pkgs.kanata-with-cmd;
    keyboards.mouse-mode = {
      devices = [];
      extraDefCfg = ''
        danger-enable-cmd yes
        alias-to-trigger-on-load led-off
        process-unmapped-keys yes
      '';
      config = ''
        (defalias
          led-on  (cmd ${capslock-led}/bin/capslock-led 1)
          led-off (cmd ${capslock-led}/bin/capslock-led 0)
          go-mouse (multi (layer-switch mouse) @led-on)
          go-base  (multi (layer-switch base) @led-off)
        )

        (defsrc caps)

        (deflayermap (base)
          caps @go-mouse
        )

        (deflayermap (mouse)
          caps @go-base
          lsft (tap-hold 200 200 lsft (layer-while-held mouse-fast))
          tab  _
          lctl _
          rctl _
          lalt _
          ralt _
          up    _
          down  _
          left  _
          rght  _
          h    (movemouse-left 10 1)
          j    (movemouse-down 10 1)
          k    (movemouse-up 10 1)
          l    (movemouse-right 10 1)
          n    mltp
          m    mrtp
          __   XX
        )

        (deflayermap (mouse-fast)
          lsft _
          tab  _
          lctl _
          rctl _
          lalt _
          ralt _
          up    _
          down  _
          left  _
          rght  _
          h    (movemouse-left 10 4)
          j    (movemouse-down 10 4)
          k    (movemouse-up 10 4)
          l    (movemouse-right 10 4)
        )
      '';
    };
  };

  systemd.services.kanata-mouse-mode.serviceConfig.DeviceAllow = lib.mkForce [
    "/dev/uinput rw"
    "char-input rw"
  ];
}
