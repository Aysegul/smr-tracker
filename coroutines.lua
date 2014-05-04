require 'inline'

-- SMR algorithm is in c.SMR coroutine
local c = {}

-- some defines
inline.preamble [[

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define abs(a)    (a) < 0 ? -(a) : (a)     
]]

c.SMR = inline.load [[
      // get args
      const void* torch_FloatTensor_id = luaT_checktypename2id(L, "torch.FloatTensor");
      THFloatTensor *output_ptr = luaT_checkudata(L, 1, torch_FloatTensor_id);
      THFloatTensor *input_ptr = luaT_checkudata(L, 2, torch_FloatTensor_id);
      THFloatTensor *kernel_ptr = luaT_checkudata(L, 3, torch_FloatTensor_id);
      float dynamic = lua_tonumber(L, 4);
      int begin_x = lua_tonumber(L, 5);
      int end_x   = lua_tonumber(L, 6);
      int begin_y = lua_tonumber(L, 7);
      int end_y   = lua_tonumber(L, 8);
            
      // get raw pointers
      float *output = THFloatTensor_data(output_ptr);
      float *input = THFloatTensor_data(input_ptr);
      float *kernel = THFloatTensor_data(kernel_ptr);
      
      // dims
      int iwidth  = input_ptr->size[1];
      int kheight = kernel_ptr->size[0];
      int kwidth  = kernel_ptr->size[1];
      int owidth  = output_ptr->size[1];
     
      // similarity matching ratio (SMR)
      int i, j, x, y, pos;
      float probability;
      float distance;
      for(y = begin_y; y < end_y; y++) {
         for(x = begin_x; x < end_x; x++) {
           
            pos = y*iwidth+x;
            probability = 0;
            for(j=0; j< kheight; j++) {
               for(i=0; i< kwidth; i++) {
                  distance = abs(input[pos+j*iwidth+i]-kernel[j*kwidth+i]);
                  if (distance<dynamic/2)
                     probability = probability + exp(-2*distance);
                 }
            }
            output[y*owidth+x] = probability;
         }
      }
      lua_newtable(L);           // result = {}
      int result = lua_gettop(L); 
      return 1;
]]


-- return package
return c
