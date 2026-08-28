{ ... }:
{
  # Plasma 面板 / Task Manager 声明式配置（plasma-manager）。
  #
  # 机制：每次 Plasma 会话启动时，autostart 脚本会
  #   1. rm 掉 plasma-org.kde.plasma.desktop-appletsrc（防无限增长）
  #   2. 用 qdbus evaluateScript 按下面的声明重建面板/小组件
  # 因此该文件每次启动都重新生成，无需持久化 —— 已从
  # home/persistence-kde.nix 的 files 列表中移除。
  #
  # UI 里的改动（取消固定、拖小组件）会在下次启动时被覆盖，
  # 改 pin 请编辑此文件 + `home-manager switch --flake .#FeiHsueh`。
  programs.plasma = {
    enable = true;

    panels = [
      {
        location = "bottom";
        height = 44;
        widgets = [
          {
            kickoff = {
              icon = "nix-snowflake";
              settings.General.systemFavorites = "suspend,hibernate,reboot,shutdown";
            };
          }
          "org.kde.plasma.pager"
          {
            # 任务管理器固定应用（pin）
            iconTasks = {
              launchers = [
                "applications:org.wezfurlong.wezterm.desktop"
                "preferred://filemanager"
                "preferred://browser"
              ];
            };
          }
          "org.kde.plasma.marginsseparator"
          {
            systemTray = {
              # 图标撑满面板高度（与任务栏图标等高）
              icons.scaleToFit = true;
              # extra = 恢复原始 extraItems 行为（主栏不铺满）
              items.extra = [
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.notifications"
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.volume"
                "org.kde.plasma.keyboardlayout"
                "org.kde.plasma.keyboardindicator"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.printmanager"
                "org.kde.kscreen"
                "org.kde.plasma.brightness"
                "org.kde.plasma.battery"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.mediacontroller"
              ];
            };
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];
  };
}
