local smr_dist = assert(require("libsmrdist"))


-- options comes from run.lua
local downs = options.downs
local boxh = options.boxh
local boxw = options.boxw

local dynamic_th= 0  -- the second max prob from the SMR after excluding the max prob and a small region around
local lifetime = 0   -- increases the search area 
local threshold = 0  -- constant value that depends on the tracking, if going out of the scene (disappear), lost, or being tracked. 
local lost = 0	     -- object is lost (lost=1)
local disappear = 0  -- object is going out of the scene (disappear=1)

-- Find the max value and coordinates of a tensor
function GetMax(a)
	x,xi = torch.max(a,1)
	y,yi = torch.max(x,2) -- y = value

	x_out = yi[1][1]      -- y coord
	y_out = xi[1][x_out]  -- x coord
	return y,x_out,y_out 
end

-- Search the local area, if the object is lost
-- increase the search area by 1 every frame
function SMRtracker(patch)     
   for _,res in ipairs(state.resultsSMR) do
      begin_x = math.max(0, res.lx - 60/downs - 1)
      end_x   = math.min(state.SMRProb:size(2), (res.lx+60/downs)) 
      begin_y = math.max(0, res.ty - 50/downs - 1)
      end_y   = math.min(state.SMRProb:size(1), (res.ty+50/downs) ) 
   end   
   if (lifetime > 0) then
      begin_x = math.max(0, begin_x - lifetime)
      end_x   = math.min(state.SMRProb:size(2), end_x + lifetime) 
      begin_y = math.max(0, begin_y -lifetime )
      end_y   = math.min(state.SMRProb:size(1), end_y +lifetime) 
   end
   lifetime = lifetime + 1

-- Call for the coroutines of SMR algorithm. state.SMRProb is filled with the similarity matching value 
coordinate = smr_dist.smr(state.SMRProb, state.input, patch, state.dynamic, begin_x, end_x, begin_y, end_y) 
end

-- grab camera frames, and track the object
local function process()
    ------------------------------------------------------------
    -- (0) grab frame, get Y chanel and resize
    ------------------------------------------------------------
    profiler:start('get-frame')
    source:getframe()
    profiler:lap('get-frame')
    ------------------------------------------------------------
    -- (1) SMR probability map
    ------------------------------------------------------------   
    state.SMRProb:resize(math.floor(state.input:size(1)-boxh)+1, 
           math.floor(state.input:size(2)-boxw)+1):fill(0)   
    for i,proto in pairs(state.lastPatch) do
     	
        SMRtracker(proto.patchYUV)
 
        state.resultsSMR = {}     
        value, px_nxt, py_nxt = GetMax(state.SMRProb) 

        local lx = math.min(math.max(0,(px_nxt-1)+1),state.input:size(2)-boxw+1)
        local ty = math.min(math.max(0,(py_nxt-1)+1),state.input:size(1)-boxh+1)  
        
        -- Compare the two max. prob to see if one of them is really bigger than the other
        -- if similiar the detection is not reliable.
        window =8 
        state.SMRProb:narrow(2, math.max(px_nxt-window, 1), math.min(2*window, state.SMRProb:size(2)-px_nxt+window-1)):
           narrow(1, math.max(py_nxt-window, 1), math.min(2*window,state.SMRProb:size(1)-py_nxt+window-1)):zero()
        dynamic_th = torch.max(state.SMRProb)
        
        -- Dynamic thresholding
        if (lost == 0) then 
          if(lx>=extension) and (ty>=extension) and (lx+boxw/downs)<=(state.input:size(2)-extension) and (ty+boxh/downs)<=(state.input:size(1)-extension-1) then
              if (disappear == 1) then 
                 threshold = 1.2 
              else
                 threshold = 1
              end 
          else 
              threshold = 1.02
              disappear = 1
          end    
       else 
          threshold = 1.25 
       end  

      -- Accept or reject the detection
      if (value[1][1]>(threshold*dynamic_th)) or  (value[1][1]>dynamic_th+100) then
         lifetime = 0
         if (threshold == 1.25) then 
            disappear = 0
         end  
         lost = 0 
        
         local nresult = {lx=lx, ty=ty, cx=lx+boxw/2, cy=ty+boxh/2, w=boxw, h=boxh,
                    class=state.classes[1], id=1, source=2}                    
         table.insert(state.resultsSMR, nresult) 
      else 
           lost = 1   
      end
      -- Template update
      -- Do not update the template if the object is going out of the scene
      -- A better template update mechanism is necessary to handle the occlusions.  
        for _,res in ipairs(state.resultsSMR) do
            if(res.lx>=2*extension) and (res.ty>=2*extension) and (res.lx+boxw)<state.YUVFrame:size(3)+extension-1 and (res.ty+boxh)<state.YUVFrame:size(2)+extension-1 then
               local patchYUV = state.input:narrow(2,res.lx,boxw):narrow(1,res.ty,boxh):clone()
               for i,proto in pairs(state.lastPatch) do
                  difference = torch.abs(proto.patchYUV - patchYUV)     
                  if (difference:max()/2)~=0 then
                     state.dynamic=math.max(difference:max()/2)
                  end
       	          state.lastPatch = {}
      	          table.insert(state.lastPatch, {patchYUV=patchYUV})
               end  
            end   
        end
     end
     
    ------------------------------------------------------------
    -- (2) capture new prototype, upon user request
    ------------------------------------------------------------
    if state.learn then
      profiler:start('learn-new-view')
      -- compute x,y coordinates
      if options.source == 'dataset' then
           ref_lx = math.min(math.max(state.learn.x+extension-boxw/2+1,1),state.input:size(2)-boxw)
           ref_ty = math.min(math.max(state.learn.y+extension-boxh/2+1,1),state.input:size(1)-boxh)
      else
           ref_lx = math.min(math.max(state.learn.x-boxw/2,0),state.input:size(2)-boxw)
           ref_ty = math.min(math.max(state.learn.y-boxh/2,0),state.input:size(1)-boxh)
      end
      state.logit('adding [' .. state.learn.class .. '] at ' .. ref_lx
                  .. ',' .. ref_ty, state.learn.id)
      -- and create a result !!
      local nresult = {lx=ref_lx, ty=ref_ty, w=boxw, 
                       h=boxh, class=state.classes[state.learn.id], 
                       id=state.learn.id, source=6}   
      table.insert(state.resultsSMR, nresult)            
         
      -- save a patch 
      local patchYUV = state.input:narrow(2,ref_lx,boxw):narrow(1,ref_ty,boxh):clone()
      state.lastPatch = {}
      table.insert(state.lastPatch, {patchYUV=patchYUV})
      -- done
      state.learn = nil
      profiler:lap('learn-new-view')
    end
   
    ------------------------------------------------------------
    -- (3) save results
    ------------------------------------------------------------
    if state.dsoutfile then
      local res = state.resultsSMR[1]
      if res then
         state.dsoutfile:writeString(res.lx .. ',' .. res.ty .. ',' ..
                                     res.lx+res.w .. ',' .. res.ty+res.h)
      else
         state.dsoutfile:writeString('NaN,NaN,NaN,Nan')
      end
      state.dsoutfile:writeString('\n')
   end
end
return process
