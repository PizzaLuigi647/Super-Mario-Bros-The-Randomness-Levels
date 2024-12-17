#version 120
uniform sampler2D iChannel0;
uniform float time;
uniform float intensity;

void main()
{	
	vec2 uv = vec2(clamp(gl_TexCoord[0].x + 0.0025 * intensity * sin(gl_TexCoord[0].y*64 + time * 0.1),0,0.999), gl_TexCoord[0].y);
	vec4 c = texture2D( iChannel0, uv);
	
	gl_FragColor = c*gl_Color;
}