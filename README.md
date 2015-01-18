SMR Tracker
===========

First,

```lua
make install 
```

```lua
qlua run.lua 
```

It will run with camera by default, click on the object you want to track, you can click again and refresh the tracking target.

Test on TLD dataset  download from: http://info.ee.surrey.ac.uk/Personal/Z.Kalal/
```lua
qlua run.lua -d 1 -s dataset -p TLD/01_david/ 
```

Track from a video

```lua 
qlua run.lua -d 1 -s video -p your/path/to/Video
```
