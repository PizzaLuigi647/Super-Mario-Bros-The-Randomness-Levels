//Read from the main texture using the regular texutre coordinates, and blend it with the tint colour.
//This is regular glDraw behaviour and is the same as using no shader.

#version 120
uniform sampler2D iChannel0;

const vec3 offset = vec3(-1/600, 0, 1/600);
const vec3 offset2 = vec3(-2/600, 0, 2/600);

float sampleBlur(vec2 offset)
{
	return texture2D(iChannel0, clamp(gl_TexCoord[0].xy + vec2(0.005, -0.005) + offset,0.001,0.999)).a;
}

//Do your per-pixel shader logic here.
void main()
{
	vec4 c = texture2D(iChannel0, gl_TexCoord[0].xy);
	
	float c2 = sampleBlur(offset.yy);
		
	
	gl_FragColor = (vec4(0,0,0, mix(c2*0.25, 0, c.a)) + c) * gl_Color;
}