float sdCircle( in vec2 p, in float r )
{
    return length(p)-r;
}

float sdCircle( in vec2 p, in float r, in vec2 c)
{
    return length(p-c)-r;
}

float sdRec( in vec2 p, in vec2 b )
{
    vec2 d = abs(p) - b;

    if (d.x > 0.0 || d.y > 0.0)
    {
        return length(max(d, vec2(0.0)));
    }
    else
    {
        return max(d.x,d.y);
    }
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // p.y from -1 to 1, p.x from -something to something
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;

    // circle
    // float d = sdCircle(p,0.5);

    // rectangle
    vec2 b = vec2(0.3, 0.3);
    float d = sdRec(p, b);

    // coloring
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
    col *= 1.0 - exp(-6.0*abs(d));
    col *= 0.8 + 0.2*cos(150.0*d);
    col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );


    fragColor = vec4(col,1.0);
}