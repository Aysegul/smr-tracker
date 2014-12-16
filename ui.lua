-- global ui object
-- holds ui state and defines listeners and functions for manipulating it
local ui = {}

-- resize
options.display = 1
ui.resize = true


-- connect mouse pos
widget.frame.mouseTracking = true
qt.connect(qt.QtLuaListener(widget.frame),
           'sigMouseMove(int,int,QByteArray,QByteArray)',
           function (x,y)
              ui.mouse = {x=x,y=y}
           end)

-- issue learning request
qt.connect(qt.QtLuaListener(widget),
           'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
           function (...)
              if ui.mouse then
                 state.learn = {x=ui.mouse.x, y=ui.mouse.y, id=1}
              end
           end)

widget.windowTitle = 'SMR Tracking'
widget:show()

-- return ui
return ui
