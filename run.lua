#!/usr/bin/env qlua
------------------------------------------------------------
-- SMR Tracking
-- Author = Aysegul Dundar
-- Date = 08/20/2012

require 'torch'
require 'xlua'
require 'nnx'
-- do everything in single precision
torch.setdefaulttensortype('torch.FloatTensor')

-- Options are defined in this file

-- parse args
op = xlua.OptionParser('%prog [options]')
op:option{'-s', '--source', action='store', dest='source',
          help='image source, can be one of: camera | video | dataset',
          default='camera'}

op:option{'-c', '--camera', action='store', dest='camidx',
          help='if source=camera, you can specify the camera index: /dev/videoIDX',
          default=0}

op:option{'-p', '--dspath', action='store', dest='dspath',
          help='path to dataset',
          default=''}

op:option{'-n', '--dsencoding', action='store', dest='dsencoding',
          help='dataset image format',
          default='jpg'}

op:option{'-O', '--dsoutput', action='store', dest='dsoutput',
          help='file to save tracker output to, for dataset only'}

op:option{'-N', '--nogui', action='store_true', dest='nogui',
          help='turn off the GUI display (only useful with dataset)'}

op:option{'-w', '--width', action='store', dest='width',
          help='detection window width',
          default=640}

op:option{'-h', '--height', action='store', dest='height',
          help='detection window height',
          default=480}

op:option{'-b', '--box', action='store', dest='box',
          help='box (training) size',
          default=128}

op:option{'-d', '--downsampling', action='store', dest='downs',
          help='image downsampling ratio (-1 to downsample as much as possible)',
          default=2}

op:option{'-f', '--file', action='store', dest='file',
          help='file to sync memory to',
          default='memory'}

options,args = op:parse()

-- class names
options.classes = {'Object 1','Object 2','Object 3',
                   'Object 4','Object 5','Object 6'}


print('SMR Tracker')
print('Initializing...\n')

-- profiler
profiler = xlua.Profiler()


-- load required submodules
state   = require 'state'
source  = require 'source'
process = require 'process'

-- load gui and display routine, if necessary
if not options.nogui then
   -- setup GUI (external UI file)
   require 'qt'
   require 'qtwidget'
   require 'qtuiloader'
   widget = qtuiloader.load('g.ui')
   painter = qt.QtLuaPainter(widget.frame)

   display = require 'display'
   ui = require 'ui'
end

-- end definition of global variables


-- setup necessary directories
if options.save then
   os.execute('mkdir -p ' .. options.save)
end
-- for memory files
sys.execute('mkdir -p scratch')


-- start execution
print('Initialization finished')
print('Processing...\n')
state.begin()
