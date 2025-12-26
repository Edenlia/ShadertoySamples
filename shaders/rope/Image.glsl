#define AA 2

mat3 lookRotation(vec3 forward, vec3 top) {
    vec3 f = normalize(forward);
    vec3 r = normalize(cross(top, f));
    vec3 u = cross(f, r);
    return mat3(f, r, u); // Column major
}


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
    p.x = max(abs(p.x) - (l), 0.0);
    return length(p)-r;
}

// r: radius
// t: thickness
float sdDisk( in vec3 p, in float r, in float t)
{
    float dx = max(length(p.xy) - r, 0.0);

    return length(vec2(dx, p.z)) - t;
}

// r: radius
// t: thickness
float sdDonut( in vec3 p, in float r, in float t)
{
    float dx = abs(length(p.xy) - r);

    return length(vec2(dx, p.z)) - t;
}

// r: radius
// t: thickness
// * It's infinite height
float sdRing( in vec3 p, in float r, in float t)
{
    return abs(length(p.xy) - r) - t;
}

float smin( float a, float b, float k )
{
    k *= 2.0;
    float x = b-a;
    return 0.5*( a+b-sqrt(x*x+k*k) );
}

vec4 map( in vec3 p, float time )
{
    vec3 p1 = vec3(0.02, -0.08, 0.2);
    vec3 p2 = vec3(0.0, 0.0, 0.0);
    vec3 p3 = vec3(0.0, 0.2, -0.1);

    vec3 c1 = (p1 + p2) / 2.0;
    vec3 c2 = (p2 + p3) / 2.0;

    float l1 = length(p1-p2);
    float l2 = length(p2-p3);

    float d1 = sdCapsule( (p-c1)*lookRotation(p1-p2,vec3(0,0,1)), 0.01, l1/2 );
    float d2 = sdCapsule( (p-c2)*lookRotation(p2-p3,vec3(0,0,1)), 0.01, l2/2 );

    float d = smin(d1, d2, 0.001);
//    float d = d2;

    float s = 0.005;
    float gridSize = 0.05;

    int num = 3;

    for (int x = -num; x <= num; x++) {
        for (int y = -num; y <= num; y++) {
            vec3 offset = vec3(
            float(x) * gridSize,
            float(y) * gridSize,
            0.0
            );
            d = min(d, sdSphere(p - offset, s));
        }
    }


    //    d = sdCapsule( p, 0.01, 0.01);
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

// use UE coordinate: (forward, right, up) -> (+X, +Y, +Z)
mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
    vec3 forward = normalize(ta-ro); // forward
    vec3 top = vec3(0.0, sin(cr), cos(cr)); // calculate top
    vec3 right = normalize( cross(top,forward) );
    vec3 up =          ( cross(forward,right) );
    return mat3( forward, right, up );
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
        vec3 ta = vec3( 0.0, 0.0, 0.0 ); // target

        // use UE coordinate: (forward, right, up) -> (+X, +Y, +Z)
        vec3 ro = ta + vec3( 0.5*cos(an), 0.5*sin(an), 0.3 ); // camera root

        // camera-to-world transformation
        mat3 ca = setCamera( ro, ta, 0.0 );

        // ray direction
        float fl = 2.0;
        vec3 rd = ca * normalize( vec3(fl, p) );

        // background
        vec3 col = vec3(1.0+rd.z)*0.03;

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