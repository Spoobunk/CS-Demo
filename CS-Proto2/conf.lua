function love.conf(t)
  -- required settings for sys-pixel libaray pixel scaling
  t.window.width = 640 -- Base Width that we scale up.
  t.window.height = 360 -- Base Height that we scale up.
  t.window.resizable = false -- Controled though allow_window_resize, set false in conf.
  t.window.minwidth = 640 -- Should match Width
  t.window.minheight = 360 -- Should match Height

  t.modules.physics = false
end