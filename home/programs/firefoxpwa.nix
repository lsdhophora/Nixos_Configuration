{ lib, ... }:
let
  # PWA 站点清单：以后加网页往 pwas 追加一条即可。
  # 每个 PWA 一个独立 profile（Wayland 下同 profile 的窗口共享 app_id，
  # 会全部合并进第一个启动的 PWA 的任务栏条目，见 upstream issue #80）。
  # ULID 必须恰好 26 位，字符集 0123456789ABCDEFGHJKMNPQRSTVWXYZ（排除 I/L/O/U），
  # site ULID 全局唯一。
  pwas = [ ];
in
{
  programs.firefoxpwa = {
    enable = true;
    # 模块负责：装 firefoxpwa 包 + 生成 ~/.local/share/firefoxpwa/config.json。
    # desktopEntry.enable = false：模块自带的条目没有 StartupWMClass，
    # 由下面 xdg.desktopEntries 统一替代。
    profiles = lib.listToAttrs (map (p: lib.nameValuePair p.profile {
      sites.${p.site} = {
        inherit (p) name url manifestUrl;
        desktopEntry.enable = false;
      };
    }) pwas);
  };

  # 自建桌面条目（KDE 启动器/任务栏）：
  # - StartupWMClass = FFPWA-<siteULID>，与 firefoxpwa 启动运行时传入的
  #   --class/--name 严格一致（site.rs launch()），任务栏归组准确；
  # - env MOZ_ENABLE_WAYLAND=1 等价扩展设置里的 "Use Wayland Display Server"
  #   （site.rs 的 runtime_enable_wayland 分支就是设这个变量）。
  xdg.desktopEntries = (lib.listToAttrs (map (p: lib.nameValuePair "FFPWA-${p.site}" {
    name = p.name;
    exec = "env MOZ_ENABLE_WAYLAND=1 firefoxpwa site launch ${p.site} --protocol %u";
    terminal = false;
    icon = p.icon or null;
    categories = p.categories or null;
    settings.StartupWMClass = "FFPWA-${p.site}";
  }) pwas))
  // {
    # 隐藏包自带的 firefoxpwa.desktop（NoDisplay=true）。
    # 用户目录的同名条目优先于 /share/applications 的条目。
    "firefoxpwa" = {
      name = "firefoxpwa";
      noDisplay = true;
    };
  };

  # CLI 直接 firefoxpwa 启动时同样走 Wayland（只影响 Mozilla 系应用）。
  home.sessionVariables.MOZ_ENABLE_WAYLAND = "1";
}
