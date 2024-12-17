#version 120

uniform sampler2D iChannel0;
uniform vec2 center;
uniform float totalRadius;
uniform float softness;

void main()
{
    float softDistance = totalRadius - softness;
    
    vec4 c = texture2D(iChannel0, gl_TexCoord[0].xy);
    float d = length(gl_FragCoord.xy - center);
    float a = 1 - clamp((d - softDistance)/(totalRadius - softDistance),0.0,1.0);
    gl_FragColor = c * a;
}