#pragma once
#include "OverlayGeometry.h"
#include <algorithm>
#include <cmath>

namespace WorldAxes {
struct Vec3 { double x, y, z; };
struct Point { double x=0, y=0; };
struct Clip { double x, y, w; };
struct Axis { Point from, to; bool valid=false; };
struct Triad { Axis axes[3]; bool edge=false; bool valid=false; };

inline Clip Transform(Vec3 p, const float *m) {
    return {m[0]*p.x+m[4]*p.y+m[8]*p.z+m[12],
            m[1]*p.x+m[5]*p.y+m[9]*p.z+m[13],
            m[3]*p.x+m[7]*p.y+m[11]*p.z+m[15]};
}
inline bool Finite(Clip p) { return std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.w); }
inline Point Screen(Clip p, double width, double height) {
    return {width*.5*(1+p.x/p.w),height*.5*(1-p.y/p.w)};
}
inline Axis Segment(Clip a, Clip b, double width, double height) {
    constexpr double nearW=.01;
    if (!Finite(a)||!Finite(b)||(a.w<nearW&&b.w<nearW)) return {};
    if (a.w<nearW || b.w<nearW) {
        const double t=(nearW-a.w)/(b.w-a.w);
        const Clip cut={a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,nearW};
        if (a.w<nearW) a=cut; else b=cut;
    }
    Axis axis{Screen(a,width,height),Screen(b,width,height),false};
    axis.valid=OverlayGeometry::ClipSegment(axis.from.x,axis.from.y,axis.to.x,axis.to.y,width,height);
    return axis;
}
inline Triad Project(Vec3 origin, const float *m, double width, double height, double length=.65) {
    Triad result;
    if (!m || !std::isfinite(width)||!std::isfinite(height)||width<80||height<80||
        !std::isfinite(length)||length<=0) return result;
    for (int i=0;i<16;++i) if (!std::isfinite(m[i])) return result;
    const Clip center=Transform(origin,m);
    if (!Finite(center)) return result;
    const Point screen=center.w>=.01 ? Screen(center,width,height) : Point{-1,-1};
    const bool inside=center.w>=.01 && screen.x>=0 && screen.x<=width && screen.y>=0 && screen.y<=height;
    result.edge=!inside;
    for (int i=0;i<3;++i) {
        Vec3 end=origin;
        if(i==0)end.x+=length;else if(i==1)end.y+=length;else end.z+=length;
        if(inside) {
            result.axes[i]=Segment(center,Transform(end,m),width,height);
        } else {
            // Offscreen targets use a small camera-oriented triad at the edge.
            // The marker is directional; it is not a projected world position.
            const double scale=std::max(1.0,std::max(std::abs(center.x),std::abs(center.y)));
            double dx=center.x/scale*width,dy=-center.y/scale*height;
            if (std::hypot(dx,dy)<1e-9) dy=1;
            const double magnitude=std::hypot(dx,dy);dx/=magnitude;dy/=magnitude;
            const double margin=32;
            const double tx=std::abs(dx)>1e-9 ? (width*.5-margin)/std::abs(dx) : 1e30;
            const double ty=std::abs(dy)>1e-9 ? (height*.5-margin)/std::abs(dy) : 1e30;
            const double t=std::min(tx,ty);
            const Point anchor={width*.5+dx*t,height*.5+dy*t};
            // Perspective derivative preserves the orientation of each world axis.
            const double w=std::max(.01,std::abs(center.w));
            const double signedW=center.w<0 ? -w : w;
            double ax=(m[i*4]*signedW-center.x*m[i*4+3])*width;
            double ay=-(m[i*4+1]*signedW-center.y*m[i*4+3])*height;
            if (!std::isfinite(ax)||!std::isfinite(ay)) return {};
            const double norm=std::hypot(ax,ay);
            if(norm>1e-9) {ax=ax/norm*18;ay=ay/norm*18;} else {ax=ay=0;}
            result.axes[i]={anchor,{anchor.x+ax,anchor.y+ay},true};
        }
        result.valid |= result.axes[i].valid;
    }
    return result;
}
}
