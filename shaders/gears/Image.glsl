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

#define AA 4
#define PI 3.1415926535

vec2 iSphere( in vec3 ro, in vec3 rd, in vec3 cen, in float rad)
{
    // roc
    ro -= cen;

    float b = dot(rd, ro);
    float c = dot(ro, ro) - rad*rad;
    float h = b*b-c;
    if (h<0.0) return vec2(-1);

    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

float dynamic( in float t, in float minValue, in float maxValue, in float speed)
{
    t = t * speed;

    return (sin(t) + 1.0) * 0.5 * (maxValue - minValue) + minValue;
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

float sdCube( in vec2 p, in vec2 r )
{
    p = abs(p);
    p = max(p-r, vec2(0.0));

    return length(p);
}

float sdCross(in vec3 p, in vec3 r)
{
    p = abs(p);

    // https://www.youtube.com/watch?v=sl9x19EnKng 1:30:05提到 三元表达式在GPU真正运算时，大概率不会真的走branch，会通过寄存器记录flag的形式，所以跑的不慢？
    // ？ TODO: 需要后续做做验证或了解一下真实情况
    p.xy = (p.y > p.x) ? p.yx : p.xy;

    float d1 = length(max(p-r, 0.0));

    return d1;
}

// r: radius
// l: length
float sdCapsule( in vec3 p, in float r, in float l)
{
    p.z = max(abs(p.z) - (r+l), 0.0);
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

// quadratic
float smax(in float a, in float b, in float k)
{
    float h = max(k - abs(a-b), 0.0);
    return max(a, b) + 0.25 / k * h * h;
}

vec4 gear( in vec3 p, float time, float offset)
{
    // Rotate it!
    {
        float an = 2.1 * time + offset * 6.283185/24.0;
        an = an * sign(p.z);
        mat2 rotMat = mat2(cos(an), -sin(an), // first column
        sin(an), cos(an)); // second column
        p.xy = rotMat * p.xy;
    }

    p.z = abs(p.z);

    float sectorRadian = 2 * PI / 12.0;
    float sector = round(atan(p.y, p.x) / sectorRadian);

    float rotRadian = sectorRadian * sector;
    mat2 rot = mat2(cos(rotRadian), -sin(rotRadian), sin(rotRadian), cos(rotRadian)); // column major

    // 本质上是把空间中其他sector中的点，mapping到第一个sector中，实施相同的距离判断
    // 可以理解为分完sector后，把sector的空间(坐标系)旋转了
    vec3 q = p;
    q.xy = rot * q.xy;

    float d = sdCube(q.xy - vec2(0.165, 0.0), vec2(0.042, 0.017)) - 0.01;
    float d2 = sdRing(p, 0.15, 0.023);
    d = min(d, d2); // SDF想要合并形状，用min

    float d3 = sdCross(p - vec3(0.0, 0.0, 0.5), vec3(0.18, 0.005, 0.005)) - 0.002;
    d = min(d, d3);

    float r = length(p);
    d = smax(d, abs(r-0.5) - 0.028, 0.005);

    // stick
    {
        float d1 = sdCapsule(p, 0.011, 0.50);
        d = min(d, d1);
    }

    {
        float k = sdDonut(p - vec3(0.0, 0.0, 0.508), 0.15, 0.01);
        d = d - min(0.0, k);
    }

    // little sphere
    d = min(d, sdSphere(p - vec3(0.0, 0.0, 0.11), 0.025));

    return vec4( d, p );
}

vec2 rotate45( in vec2 v )
{
    return vec2(v.x + v.y, v.x - v.y) * 0.7071;
}

vec4 map( in vec3 p, float time )
{
    vec4 d = vec4((sdSphere(p, 0.12)), p);

//    return d;

    vec3 q = p;

    if      (abs(q.x) > abs(q.y) && abs(q.x) > abs(q.z)) q = q.zyx;
    else if (abs(q.y) > abs(q.z))                        q = q.xzy * vec3(1,1,1);
    else                                                 q = q.xyz * vec3(-1,1,1);

    vec4 d1 = gear(q, time, 0.0);
    d1 = d.x < d1.x ? d : d1;

    // X
    {
        vec3 qx = vec3(p.x, rotate45(p.zy));
        if (abs(qx.y) > abs(qx.z)) qx = -qx.xzy;
        vec4 d2 = gear(qx.xyz, time, 1.0);
        d1 = d2.x < d1.x ? d2 : d1;
    }

    // Y
    {
        vec3 qy = vec3(p.y, rotate45(p.xz));
        if (abs(qy.y) > abs(qy.z)) qy = -qy.xzy;
        vec4 d2 = gear(qy.xyz, time, 1.0);
        d1 = d2.x < d1.x ? d2 : d1;
    }

    // Z
    {
        vec3 qz = vec3(p.z, rotate45(p.yx));
        qz = qz.xyz  * vec3(1.0, 1.0, 1.0);
        if (abs(qz.y) > abs(qz.z)) qz = -qz.xzy;
        vec4 d2 = gear(qz.xyz, time, 1.0);
        d1 = d2.x < d1.x ? d2 : d1;
    }

    return d1;
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

    vec2 vol = iSphere( ro, rd, vec3(0.0), 0.533);

    if (vol.y > 0.0)
    {
        float tmax = min(2.0, vol.y);
        float t    = max(0.001, vol.x);
        for( int i=0; i<64; i++ )
        {
            float h = map( ro + rd*t, time ).x;
            res = min( res, k*h/t );
            t += clamp( h, 0.012, 0.2 );
            if( res<0.001 || t>tmax ) break;
        }
    }

    return clamp( res, 0.0, 1.0 );
}

vec4 intersect( in vec3 ro, in vec3 rd, in float time )
{
    vec4 res = vec4(-1.0);

    vec2 vol = iSphere( ro, rd, vec3(0.0), 0.533);
    if (vol.y > 0.0)
    {
        // raymarch
        float t = max(vol.x, 0.0);
        float tmax = 5.0;
        for( int i=0; i<128 && t<vol.y; i++ )
        {
            vec4 h = map(ro+t*rd,time);
            if( h.x<0.001 ) { res=vec4(t,h.yzw); break; }
            t += h.x;
        }
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
        float d = 0.5+0.5*sin(fragCoord.x*147.0)*sin(fragCoord.y*131.0);
        float time = iTime - 2.*(1.0/48.0)*(float(m*AA+n)+d)/float(AA*AA);
        #else
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
        float time = iTime;
        #endif

        // camera
        float an = 6.2831*time/40.0;
        vec3 ta = vec3( 0.0, 0.0, 0.0 ); // target

        ta += 0.009*sin(68.0*time/40.0+vec3(2.0,6.0,4.0));

        // use UE coordinate: (forward, right, up) -> (+X, +Y, +Z)
        vec3 ro = ta + vec3( 1.5*cos(an), 1.5*sin(an), 0.6 ); // camera root

        ro += 0.005*sin(92.0*time/40.0+vec3(0.0,3.0,1.0));

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

            float innerOcc = clamp(0.53 + 0.47 * dot(nor, normalize(pos)), 0.0, 1.0);
            innerOcc = clamp(length(pos) / 0.53, 0.0, 1.0) * innerOcc;
            float occ = calcAO(pos+nor*0.001,nor,time) * innerOcc;

            vec3 te = 0.5*texture(iChannel0,tuvw.yz).xyz+
            0.5*texture(iChannel0,tuvw.yw).xyz;
            vec3 mate = 0.22*te;
            float len = length(pos);
            vec3 f0 = mate;

            mate = mix(mate, vec3(0.7, 0.25, 0.15), 1.0-smoothstep(0.121, 0.122, len));

            float ks = 0.5+1.0*te.x;

            col = vec3(0.0);
            // top light
            {
                float diffuse = 0.5 + 0.5 * nor.z;
                diffuse *= occ;
                vec3 ref = reflect(rd, nor);
                // Inner sphere more diffuse
                vec3 spe = vec3(1.0) * smoothstep(-1.0+1.5*innerOcc, 0.6, ref.z);

                // fresnel
                float fre = clamp(1.0+dot(rd, nor),0.0, 1.0);
                spe *= f0 + (1.0-f0)*pow(fre, 5.0);
                spe *= 4.0;

                col += 0.5 * mate * vec3(0.7, 0.8, 1.1) * diffuse;
                col +=  ks * vec3(0.7, 0.8, 1.1) * spe * diffuse * occ;

//                col = vec3(fre);
            }

            // side light
            {
                vec3 ligDir = normalize(vec3(0.4, 0.7, 0.1));
                float dif = clamp( dot(nor, ligDir), 0.0, 1.0);
                float sha = calcSoftshadow( pos, ligDir, 32.0, time);

                vec3 hal = normalize(ligDir-rd);
                vec3 spe = vec3(1.0)*pow(clamp(dot(hal, nor), 0.0, 1.0), 32.0);
                spe *= f0 + (1.0-f0)*pow(1.0-clamp(dot(hal, ligDir), 0.0, 1.0), 5.0);

                col += mate * vec3(1.0, 0.55, 0.3) * dif * sha;
                col += ks * 8.0*vec3(1.0, 0.55, 0.3) * dif * sha * spe;
            }

            {
                float dif = clamp(0.5 - 0.5 * nor.z, 0.0, 1.0);
                col += 0.4*mate*dif*occ;
            }
        }

        col *= 1.0 - 0.2*dot(p,p);

        // gamma
        tot += pow(col,vec3(0.45) );
        #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // cheap dithering
//    tot += sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1)/512.0;

    // SCurve
    tot = clamp(tot, 0.0, 1.0);
    // Cubic smoothstep
    tot = tot*tot*(3.0-2.0*tot);

    // dithering
    tot += (1.0/512.0)*sin(fragCoord.x*147.0)*sin(fragCoord.y*131.0);

//    tot = floor(tot*255.0)/255.0;
//    tot = (abs(dFdy(tot))+abs(dFdx(tot)))*200.0;

//    float d = 0.5+0.5*sin(fragCoord.x*147.0)*sin(fragCoord.y*131.0);
//    tot = vec3(d);

    fragColor = vec4( tot, 1.0 );
}