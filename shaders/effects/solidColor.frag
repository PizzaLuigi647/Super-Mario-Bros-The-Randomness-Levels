#version 120

const vec4 alphablack = vec4(0., 0., 0., 0.);

uniform sampler2D iChannel0;

void main()
{
    vec4 c = texture2D(iChannel0, gl_TexCoord[0].xy);
    gl_FragColor = mix(alphablack, gl_Color, clamp(c.r, 0., 1.));
}