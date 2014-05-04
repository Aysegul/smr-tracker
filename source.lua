local source = {}
-- camera source, rescaler, color space
if options.source == 'camera' then
   require 'camera'
   source = image.Camera{}
elseif options.source == 'video' then
   require 'ffmpeg'
   source = ffmpeg.Video{path=options.video, width=options.width,
                         height=options.height, fps=options.fps,
                         length=options.length}
elseif options.source == 'dataset' then
   require 'ffmpeg'
   source = ffmpeg.Video{path=options.dspath, encoding=options.dsencoding,
                         loaddump=true, load=false}
   options.width = source.width
   options.height = source.height

   local gtfile = torch.DiskFile(sys.concat(options.dspath,'init.txt'),'r')
   if options.dsoutput then
      state.dsoutfile = torch.DiskFile(options.dsoutput,'w')
   end
   local gt = {file=gtfile}
   function gt:next()
      local line = self.file:readString('*line')
      local _, _, lx, ty, rx, by = string.find(line, '(.*),(.*),(.*),(.*)')
      self.lx = tonumber(lx)
      self.ty = tonumber(ty)
      self.rx = tonumber(rx)
      self.by = tonumber(by)
   end
   gt:next()
   options.boxw = gt.rx - gt.lx
   options.boxh = gt.by - gt.ty
   gt.file:close()
   gt.file = torch.DiskFile(sys.concat(options.dspath,'gt.txt'),'r')
   source.gt = gt

   local oldforward = source.forward
   local function gtwrap(self)
      self.gt:next()
      return oldforward(self)
   end
   source.forward = gtwrap
end

if options.source ~= 'dataset' then
   options.boxh = options.box
   options.boxw = options.box
else 
   state.learn = {x=(source.gt.lx+source.gt.rx)/2, 
                 y=(source.gt.ty+source.gt.by)/2,
                 id=1, class=state.classes[1]}
end

if options.source == 'dataset' or options.source == 'video' then
   local oldforward = source.forward
   local function finishwrap(self)
      if self.current == self.nframes then
         state.finished = true
      end
      return oldforward(self)
   end
   source.forward = finishwrap
end

source.rgb2yuv = nn.SpatialColorTransform('rgb2yuv')
function source.setdowns(downs)
   -- originally owidth and oheight had +3, not sure why, removed for now
   source.rescaler = nn.SpatialReSampling{owidth=options.width/downs,
                                      oheight=options.height/downs}
end
source.setdowns(options.downs)

extension = 20
function source:getframe()
   -- store previous frame
   -- capture next frame
   state.rawFrame = self:forward()
   state.rawFrame = state.rawFrame:float()

   -- convert and rescale
   state.RGBFrame = source.rescaler:forward(state.rawFrame)
   state.YUVFrame = source.rgb2yuv:forward(state.RGBFrame)

   state.input = torch.Tensor(state.YUVFrame:size(2)+2*extension, state.YUVFrame:size(3)+2*extension):fill(0)
   state.input[{{extension+1, state.YUVFrame:size(2)+extension}, {extension+1, state.YUVFrame:size(3)+extension}}] = state.YUVFrame[1]

end

return source
