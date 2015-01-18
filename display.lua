--functions for manipulating ui
local display = {}

-- function to update display
function display.update()
   -- resize display ?
   if ui.resize then
      if options.display >= 1 then
         widget.geometry = qt.QRect{x=100,y=100,width=640+options.boxw/options.downs,height=520}
      else
         widget.geometry = qt.QRect{x=100,y=100,width=720,height=780}
      end
      ui.resize = false
   end

   -- display...
   profiler:start('display')
   painter:gbegin()
   painter:showpage()
   window_zoom = 1

   -- display input image
   image.display{image=state.input,
                 win=painter,
                 zoom=window_zoom}

   if options.source == 'dataset' then
      -- draw a box around ground truth
      local gt = source.gt
      local w = gt.rx - gt.lx
      local h = gt.by - gt.ty
      local x = gt.lx+extension
      local y = gt.ty+extension

      painter:setcolor('green')
      painter:setlinewidth(3)
      painter:rectangle(x * window_zoom, y * window_zoom, w * window_zoom, h * window_zoom)
      painter:stroke()
      painter:setfont(qt.QFont{serif=false,italic=false,size=14})
      painter:moveto(x * window_zoom, (y-2) * window_zoom)
      painter:show('Ground truth')
   end


   for _,res in ipairs(state.resultsSMR) do
      local color = 'red'
      local legend = res.class
      local w = res.w
      local h = res.h
      local x = res.lx
      local y = res.ty
      painter:setcolor('red')
      painter:setlinewidth(3)
      painter:rectangle(x * window_zoom, y * window_zoom, w * window_zoom, h * window_zoom)
      painter:stroke()
      painter:setfont(qt.QFont{serif=false,italic=false,size=14})
      painter:moveto(x * window_zoom, (y-2) * window_zoom)
      painter:show('SMR tracker')

   end

   -- draw a circle around mouse
   _mousetic_ = ((_mousetic_ or -1) + 1) % 2
   if ui.mouse and _mousetic_==1 then
      local color = 'blue'
      local legend = 'learning object'
      local x = ui.mouse.x
      local y = ui.mouse.y
      local w = options.boxw
      local h = options.boxh
      painter:setcolor(color)
      painter:setlinewidth(3)
      painter:arc(x * window_zoom, y * window_zoom, h/2 * window_zoom, 0, 360)
      painter:stroke()
      painter:setfont(qt.QFont{serif=false,italic=false,size=14})
      painter:moveto((x-options.boxw/2) * window_zoom, (y-options.boxh/2-2) * window_zoom)
      painter:show(legend)
   end

   -- display extra stuff
   if options.display >= 1 then
      local sizew = options.boxw/options.downs
      local sizeh = options.boxh/options.downs
	   --[[if state.lastPatch:dim() > 0 then
         image.display{image=state.lastPatch,
                       legend='last patch',
                       win=painter,
                       x=state.input:size(2)+32,
                       y= 10,
                       zoom=window_zoom}
      end	]]
   end
   profiler:lap('display')
end


function display.results()
   -- disp profiler results
   local x = 10
   local y = state.input:size(1)*window_zoom+20
   painter:setcolor('black')
   painter:setfont(qt.QFont{serif=false,italic=false,size=12})
   painter:moveto(x,y) painter:show('-------------- profiling ---------------')
   profiler:displayAll{painter=painter, x=x, y=y+20, zoom=0.5}

   -- display log
   display.log()

   -- save screen to disk
   if options.save then
      display.save()
   end
end

function display.log()
   x = 400
   local y = state.input:size(1)*window_zoom+20
   painter:moveto(x,y) painter:show('-------------- log ---------------')
   for i = 1,#state.log do
      local txt = state.log[#state.log-i+1].str
      local color = state.log[#state.log-i+1].color
      y = y + 16
      painter:moveto(x,y)
      painter:setcolor(color)
      painter:show(txt)
      if i == 8 then break end
   end
   painter:gend()
end

function display.save()
   display._fidx_ = (display._fidx_ or 0) + 1
   local t = painter:image():toTensor(3)
   image.save(options.save .. '/'
              .. string.format('%05d',display._fidx_) .. '.png', t)
end

-- display loop for after video/dataset has finished
local timer = qt.QTimer()
timer.interval = 10
timer.singleShot = true
function display.begin(loop)
   local function finishloop()
      if state.finished then
         state.finish()
         qt.disconnect(timer,
                       'timeout()',
                       finishloop)
         qt.connect(timer,
                    'timeout()',
                    function() 
                       display.update()
                       display.log()
                       timer:start()
                    end)
         timer:start()
      else
         loop()
         timer:start()
      end
   end
   qt.connect(timer,
              'timeout()',
              finishloop)
   timer:start()      
end


return display
