-- global state (excluding ui state)
local state = {}

-- tensors holding raw and processed frames
state.rawFrame = torch.Tensor()
state.input = torch.Tensor()
state.dynamic = 0.1

-- stores the position and bounds of tracked objects

state.resultsSMR = {}

-- stores an image patch and its associated dense features (prototype)

state.lastPatch = torch.Tensor()
state.totalProb = torch.Tensor()
state.SMRProb = torch.Tensor()

-- hold the postion and class of a prototype to be added
state.learn = nil

-- flag that the end of video or dataset has been reached
state.finished = false
state.finish = function()
                  state.logit('you have reached the end of the video')
                  if state.dsoutfile then
                     state.dsoutfile:close()
                  end
               end
-- options
state.classes = options.classes
state.threshold = options.recognition_lthreshold
state.autolearn = options.autolearn
state.std = options.standard_deviation

if options.nogui then
   function state.begin()
      while not state.finished do
         profiler:start('full-loop','fps')
         print('Frame:',source.current)
         process()
         print('')
         profiler:lap('full-loop')
      end
      state.finish()
   end
   function state.logit(msg)
      print(msg)
   end
else
   local function loop()
      profiler:start('full-loop','fps')
      process()
      display.update()
      profiler:lap('full-loop')
      display.results()
   end
   function state.begin()
      display.begin(loop)
   end
   -- provide log
   state.log = {}
   function state.logit(str,color)
      -- color can be a class id (number) or a color name (string)
      print(str)
      if type(color) == 'number' then
         color = 'blue'
      end
      table.insert(state.log,{str=str, color=color or 'black'})
   end
end

return state
