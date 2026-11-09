#pragma once
#include <cstdint>
namespace AutoSwap {
struct Proposal {uint64_t weapon=0;uint32_t slot=0;};
template<class Read,class Valid>
Proposal Next(uint64_t manager,uint64_t local,uint64_t active,uint64_t start,Read read,Valid valid) {
    uint64_t owner=0,array=0,primary=active;uint32_t length=0;
    if(!valid(manager)||!read(manager+0x30,owner)||owner!=local||
       !read(manager+0x88,array)||!valid(array)||!read(array+0x18,length)||length<2||length>67)return {};
    read(manager+0xA0,primary);
    int current=-1;
    for(uint32_t i=0;i<length;++i){uint64_t w=0;if(read(array+0x20+i*8,w)&&(w==active||w==primary))current=(int)i;}
    if(current<0)return {};
    for(uint32_t d=1;d<length;++d){
        const uint32_t i=(current+d)%length;uint64_t w=0,klass=0,method=0;
        if(read(array+0x20+i*8,w)&&valid(w)&&w!=active&&w!=primary&&
           read(w+0x60,owner)&&(owner==0||owner==local)&&read(w,klass)&&valid(klass)&&
           read(klass+0xC98,method)&&method==start)return {w,i};
    }
    return {};
}
}
