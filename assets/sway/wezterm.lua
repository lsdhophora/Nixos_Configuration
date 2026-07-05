local wezterm = require 'wezterm'

wezterm.on('format-window-title', function(tab, pane)
  local dir = pane:get_current_working_dir()
  if dir then
    return dir
  end
  return tab.active_pane.title
end)

return {
  font = wezterm.font_with_fallback({
    { family = 'IBM Plex Mono', weight = 'Regular' },
    { family = 'Noto Sans CJK SC' },
  }),
  font_size = 14.0,
  colors = {
    background = '#242424',
    cursor_bg = '#ffffff',
    cursor_border = '#ffffff',
  },
  hide_tab_bar_if_only_one_tab = true,
  enable_tab_bar = false,
  window_close_confirmation = 'NeverPrompt',
}
