#version 120
uniform sampler2D iChannel0;

void main()
{
	vec4 c = texture2D(iChannel0, mod(gl_TexCoord[0].xy, 1.0));
	gl_FragColor = c*gl_Color;
}