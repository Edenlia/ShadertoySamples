// Created by inigo quilez - iq/2019
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Step #1 of the LIVE Shade Deconstruction tutorials for "Spere Gears"

// Part 1: https://www.youtube.com/watch?v=sl9x19EnKng
//   Step 1: https://www.shadertoy.com/view/ws3GD2
//   Step 2: https://www.shadertoy.com/view/wdcGD2
//   Step 3: https://www.shadertoy.com/view/td3GDX
//   Step 4: https://www.shadertoy.com/view/wd33DX
//   Step 5: https://www.shadertoy.com/view/tdc3DX
// Part 2: https://www.youtube.com/watch?v=bdICU2uvOdU
//   Step 6: https://www.shadertoy.com/view/td3GDf
//   Step 7: https://www.shadertoy.com/view/wssczn
//   Step 8: https://www.shadertoy.com/view/wdlyRr
//   Final : https://www.shadertoy.com/view/tt2XzG

#define AA 2

float sdSphere( in vec3 p, in float r )
{
    return length(p)-r;
}

// r: cube edge length (x,y,z)
float sdCube( in vec3 p, in vec3 r )
{
    p = abs(p);
    p = max(p-r, vec3(0.0));

    return length(p);
}

// r: radius
// l: length
float sdCapsule( in vec3 p, in float r, in float l)
{
    p.y = max(abs(p.y) - (r+l), 0.0);
    return length(p)-r;
}

// r: radius
// t: thickness
float sdDisk( in vec3 p, in float r, in float t)
{
    float dx = max(length(p.xz) - r, 0.0);

    return length(vec2(dx, p.y)) - t;
}

// r: radius
// t: thickness
float sdDonut( in vec3 p, in float r, in float t)
{
    float dx = abs(length(p.xz) - r);

    return length(vec2(dx, p.y)) - t;
}

// r: radius
// t: thickness
// * It's infinite height
float sdRing( in vec3 p, in float r, in float t)
{
    return abs(length(p.xz) - r) - t;
}

vec4 map( in vec3 p, float time )
{
    float d = sdRing( p, 0.1, 0.01 );
    float d1 = abs(p.y) - 0.02;
    d = max(d, d1);

    {
        float dc = sdCube(p - vec3(0.0, 0.0, 0.1), vec3(0.02));
        d = min(d, dc);
    }

    return vec4( d, p );
}

#define ZERO min(iFrame,0)

vec3 calcNormal( in vec3 pos, in float time )
{
    vec3 n = vec3(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*map(pos+0.0005*e,time).x;
    }
    return normalize(n);
}

float calcAO( in vec3 pos, in vec3 nor, in float time )
{
    float occ = 0.0;
    float sca = 1.0;
    for( int i=ZERO; i<5; i++ )
    {
        float h = 0.01 + 0.12*float(i)/4.0;
        float d = map( pos+h*nor, time ).x;
        occ += (h-d)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

float calcSoftshadow( in vec3 ro, in vec3 rd, in float k, in float time )
{
    float res = 1.0;

    float tmax = 2.0;
    float t    = 0.001;
    for( int i=0; i<64; i++ )
    {
        float h = map( ro + rd*t, time ).x;
        res = min( res, k*h/t );
        t += clamp( h, 0.012, 0.2 );
        if( res<0.001 || t>tmax ) break;
    }

    return clamp( res, 0.0, 1.0 );
}

vec4 intersect( in vec3 ro, in vec3 rd, in float time )
{
    vec4 res = vec4(-1.0);

    float t = 0.001;
    float tmax = 5.0;
    for( int i=0; i<128 && t<tmax; i++ )
    {
        vec4 h = map(ro+t*rd,time);
        if( h.x<0.001 ) { res=vec4(t,h.yzw); break; }
        t += h.x;
    }

    return res;
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
    vec3 cw = normalize(ta-ro);
    vec3 cp = vec3(sin(cr), cos(cr),0.0);
    vec3 cu = normalize( cross(cw,cp) );
    vec3 cv =          ( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);

    #if AA>1
    for( int m=ZERO; m<AA; m++ )
    for( int n=ZERO; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (2.0*(fragCoord+o)-iResolution.xy)/iResolution.y;
        float d = 0.5*sin(fragCoord.x*147.0)*sin(fragCoord.y*131.0);
        float time = iTime;
        #else
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
        float time = iTime;
        #endif

        // camera
        float an = 6.2831*time/40.0;
        vec3 ta = vec3( 0.0, 0.0, 0.0 );

        // TODO: use UE coordinate: (forward, right, up) -> (+X, +Y, +Z)
        vec3 ro = ta + vec3( 0.5*cos(an), 0.3, 0.5*sin(an) );

        // camera-to-world transformation
        mat3 ca = setCamera( ro, ta, 0.0 );

        // ray direction
        float fl = 2.0;
        vec3 rd = ca * normalize( vec3(p,fl) );

        // background
        vec3 col = vec3(1.0+rd.y)*0.03;

        // raymarch geometry
        vec4 tuvw = intersect( ro, rd, time );
        if( tuvw.x>0.0 )
        {
            // shading/lighting
            vec3 pos = ro + tuvw.x*rd;
            vec3 nor = calcNormal(pos, time);

            col = 0.5 + 0.5*nor;
        }


        // gamma
        tot += pow(col,vec3(0.45) );
        #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // cheap dithering
    tot += sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1)/512.0;

    fragColor = vec4( tot, 1.0 );
}