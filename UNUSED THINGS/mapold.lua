local map3d = API.load("map3d");
local travl = API.load("travl");
local wandr = API.load("wandr");

map3d.Heightmap.texture = Graphics.loadImage("heightmap.png");
map3d.Heightmap.position = vector.v2(256, 480);
map3d.Heightmap.scale = 128;

map3d.Light.enabled = false
map3d.Light.direction = vector(-1,-1.75,1):normalise();
map3d.Light.style = map3d.LIGHT_LAMBERT;

map3d.BGPlane.tile = 14;

map3d.CameraSettings.fov = 67
map3d.CameraSettings.height = 370;


map3d.TileSwell = 0.2
                         
                           
map3d.Billboard.scene.rotate[8] = false;
map3d.SceneryClip[8] = false;


local img_bg = Graphics.loadImage("challengers/char_bg.png");
local img_headbg = Graphics.loadImage("challengers/head_bg.png");

local bgCapture = Graphics.CaptureBuffer(800,600,true);
local blurCapture = Graphics.CaptureBuffer(800,600,true);
local imgbackground = Graphics.CaptureBuffer(800,600,true);

local bgCol = Color.fromHexRGB(0x72c8ff);
local blur_gauss = Shader();
blur_gauss:compileFromFile(nil, "blur_gauss.frag");

local hudpriority = 4;

--travl.position = vector.v2(400,300);

local sizes = 	{
					[8] = vector.v2(128,128),
					[16] = vector.v2(32,32),
					[19] = vector.v2(64,32),
					[22] = vector.v2(72,64),
					[23] = vector.v2(64,32),
					[26] = vector.v2(64,32),
				}


wandr.speed = 4
