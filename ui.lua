-- global ui object
-- holds ui state and defines listeners and functions for manipulating it
local ui = {}

-- setup gui

-- connect all buttons to actions
ui.classes = {widget.pushButton_1, widget.pushButton_2, widget.pushButton_3, 
               widget.pushButton_4, widget.pushButton_5, widget.pushButton_6}

-- colors
ui.colors = {'blue', 'green', 'orange', 'cyan', 'purple', 'brown', 'gray', 'red', 'yellow'}

-- set current class to learn
for i,button in ipairs(ui.classes) do
   button.text = state.classes[i]
   qt.connect(qt.QtLuaListener(button),
              'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
              function (...)
                 ui.currentId = i
                 ui.currentClass = state.classes[i] 
              end)
end
ui.currentId = 1
ui.currentClass = state.classes[ui.currentId]

-- reset
qt.connect(qt.QtLuaListener(widget.pushButton_forget),
           'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
           function (...)
              ui.forget = true
           end)

-- resize
options.display = 1 -- 3 levels (0=nothing, 1=protos, 2=track points)
ui.resize = true
qt.connect(qt.QtLuaListener(widget.pushButton_disp),
           'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
           function (...)
              options.display = options.display + 1
              if options.display > 2 then options.display = 0 end
              ui.resize = true
           end)

-- learn on/off
qt.connect(qt.QtLuaListener(widget.pushButton_learn),
           'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
           function (...)
              state.autolearn = not state.autolearn
              if state.autolearn then
                 state.logit('auto-learning is on !')
              else
                 state.logit('auto-learning off...')
              end
           end)

-- save session
ui.save = false
qt.connect(qt.QtLuaListener(widget.pushButton_save),
           'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
           function (...)
              ui.save = true
          end)

-- load session
ui.load = false
qt.connect(qt.QtLuaListener(widget.pushButton_load),
           'sigMousePress(int,int,QByteArray,QByteArray,QByteArray)',
           function (...)
              ui.load = true
          end)

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
                 state.learn = {x=ui.mouse.x, y=ui.mouse.y, id=ui.currentId, class=ui.currentClass}
              end
           end)

widget.windowTitle = 'SMR Tracking'
widget:show()

function ui.proc()
   ------------------------------------------------------------
   -- clear memory / save / load session
   ------------------------------------------------------------
   if ui.forget then
      state.logit('clearing memory')
      state.memory = {}
      state.results = {}
      ui.forget = false
   end
   if ui.save then
      local filen = 'scratch/' .. options.file
      state.logit('saving memory to ' .. filen)
      local file = torch.DiskFile(filen,'w')
      file:writeObject(state.memory)
      file:close()
      ui.save = false
   end
   if ui.load then
      local filen = 'scratch/' .. options.file
      state.logit('reloading memory from ' .. filen)
      local file = torch.DiskFile(filen)
      local loaded = file:readObject()
      state.memory = loaded
      file:close()
      ui.load = false
   end
end


-- return ui
return ui
