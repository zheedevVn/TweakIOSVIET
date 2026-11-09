#include "GameOffsets.h"
#include "GhostMode.h"
#if defined(__aarch64__) || defined(__arm64__)
#include "GhostRemoteLayout.h"
#include "SilentAimRemoteMapping.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <mutex>
extern "C" const unsigned char GhostRemoteStart[], GhostRemoteEnd[];
namespace {
constexpr uint64_t Tick=GameOffsets::Rva(0x613E2F4), Position=GameOffsets::Rva(0x276A4D4), Axis=GameOffsets::Rva(0x276B3CC), Slot=0x198;
struct Signature { uint64_t offset; size_t size; uint32_t hash; };
constexpr Signature signatures[] = {
    {Tick,0x2F4,0x0E305068},{Position,0xEC,0x7DDB7C94},{Axis,0xEC,0x4696BE26},
    {GameOffsets::Rva(0x57C0B2C),0x230,0xBBFE1A71},{GameOffsets::Rva(0x6B49E10),0x104,0xAACE9654},
    {GameOffsets::Rva(0x591B898),0x1C8,0x92F2568B},{GameOffsets::Rva(0x56AA7C8),0x110,0x4478C55F},
    {GameOffsets::Rva(0x5636F20),0x60,0x6E4B75FE},{GameOffsets::Rva(0x561CA30),0xB4,0xABF31A13},
    {GameOffsets::Rva(0x5624820),0x100,0xCA3873F8},{GameOffsets::Rva(0x5624920),0x100,0xCD88029D},
    {GameOffsets::Rva(0x562B3D4),0xB4,0x19271E41},{GameOffsets::Rva(0x562B488),0xB4,0x57B0CB1B},
    {GameOffsets::Rva(0x561C7C8),0x6C,0x7958F6CC},{GameOffsets::Rva(0x561CAE4),0xB4,0xB469C925},
    {GameOffsets::Rva(0x5624A20),0x11C,0xA3152FF4},{GameOffsets::Rva(0x562B53C),0xB4,0x6CDFBEA8},
    {GameOffsets::Rva(0x5624488),0xB4,0xBA38C9C8},
    {GameOffsets::Rva(0x613EA00),0x15C,0x20A90AAF},{GameOffsets::Rva(0x613CB84),0x1508,0x66DA289B},
    {GameOffsets::Rva(0x2570ED8),0x370,0xD89C4708},{GameOffsets::Rva(0x2572668),0x250,0x8307E566},
    {GameOffsets::Rva(0x25680BC),0x60,0x09918D15}
};
std::recursive_mutex mutex;
mach_port_t task=MACH_PORT_NULL;
int pid=-1;
uint64_t module=0, allocation=0;
bool wanted=false, verified=false, published=false, returnPending=false;
uint32_t epoch=0, sequence=0;
double retryAt=0;
int lastResult=1;
GhostRemote::State input{};
GhostModeSnapshot snapshot{};
bool ReadBytes(uint64_t a,void *v,size_t n) {
    mach_vm_size_t actual=0;
    return task!=MACH_PORT_NULL && isVaildPtr(a) &&
        mach_vm_read_overwrite(task,a,n,(mach_vm_address_t)v,&actual)==KERN_SUCCESS && actual==n;
}
template<class T> bool Read(uint64_t a,T &v){return ReadBytes(a,&v,sizeof(v));}
bool WriteBytes(uint64_t a,const void *v,size_t n) {
    return task!=MACH_PORT_NULL && isVaildPtr(a) &&
        mach_vm_write(task,a,(pointer_t)v,(mach_msg_type_number_t)n)==KERN_SUCCESS;
}
template<class T> bool Write(uint64_t a,const T &v){return WriteBytes(a,&v,sizeof(v));}
uint64_t State(){return allocation+GHOST_PAGE;}
bool Publish() {
    if(!allocation)return false;
    // Only input fields are written from the controller; the game owns output.
    constexpr size_t begin=GHOST_COMMAND, end=GHOST_EPOCH+sizeof(uint32_t);
    const uint32_t odd=(sequence+1)|1u;sequence=odd+1;
    published=true;
    return Write(State()+GHOST_SEQUENCE,odd) &&
        WriteBytes(State()+begin,(const uint8_t *)&input+begin,end-begin) &&
        Write(State()+GHOST_SEQUENCE,sequence);
}
void Cancel() {
    // If a new frame re-arms before the game observes command 0, it must
    // capture a fresh anchor instead of reviving one from the old context.
    if(input.command){input.epoch=++epoch;}
    returnPending=false;
    input.command=0;input.deadline=0;
    if(allocation && published && Publish())published=false;
    snapshot.active=false;
}
bool Attach(uint64_t base) {
#ifdef MIZZE_INJECTED
    const mach_port_t candidate=mach_task_self();
#else
    const mach_port_t candidate=get_task;
#endif
    int candidatePID=-1;
    if(candidate==MACH_PORT_NULL || pid_for_task(candidate,&candidatePID)!=KERN_SUCCESS){Cancel();return false;}
    if(task==candidate && pid==candidatePID && module==base)return true;
    Cancel(); // Installed callbacks remain mapped, with command 0.
    if(task!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),task);
    task=MACH_PORT_NULL;module=allocation=0;verified=published=false;
    sequence=0;input={};snapshot={};retryAt=0;
    if(mach_port_mod_refs(mach_task_self(),candidate,MACH_PORT_RIGHT_SEND,1)!=KERN_SUCCESS)return false;
    task=candidate;pid=candidatePID;module=base;return true;
}
bool ReadClass(uint64_t object,const char *expected,uint64_t &klass) {
    uint64_t name=0;char buffer[32]{};
    const size_t n=std::strlen(expected)+1;
    return n<=sizeof(buffer) && Read(object,klass) && isVaildPtr(klass) &&
        Read(klass+0x10,name) && ReadBytes(name,buffer,n) && !std::memcmp(buffer,expected,n);
}
bool Verify() {
    if(verified)return true;
    std::array<uint8_t,0x1508> bytes{};
    for(const auto &s:signatures){
        if(!ReadBytes(module+s.offset,bytes.data(),s.size))return false;
        uint32_t h=0x811C9DC5;
        for(size_t i=0;i<s.size;++i)h=(h^bytes[i])*0x01000193u;
        if(h!=GameOffsets::ExpectedHash(s.hash))return false;
    }
    verified=true;return true;
}
uint64_t Clock() {
    Dl_info info{};const void *clock=(const void *)&mach_absolute_time;
    if(!dladdr(clock,&info)||!info.dli_fname||!info.dli_fbase)return 0;
    const char *name=std::strrchr(info.dli_fname,'/');
    const uint64_t base=get_image_base_address(task,name?name+1:info.dli_fname);
    if(!base)return 0;
    const uint64_t a=base+((uintptr_t)clock-(uintptr_t)info.dli_fbase);
    std::array<uint8_t,32> bytes{};
    return Read(a,bytes)&&!std::memcmp(bytes.data(),clock,bytes.size())?a:0;
}
bool Writable(uint64_t a) {
    mach_vm_address_t r=a;mach_vm_size_t n=0;natural_t depth=0;
    vm_region_submap_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_SUBMAP_INFO_COUNT_64;
    return a%8==0 && mach_vm_region_recurse(task,&r,&n,&depth,(vm_region_recurse_info_t)&info,&count)==KERN_SUCCESS &&
        !info.is_submap && r<=a && a-r<=n && n-(a-r)>=8 && (info.protection&VM_PROT_WRITE);
}
bool Adopt(uint64_t a) {
    if(!isVaildPtr(a)||a%GHOST_PAGE)return false;
    std::array<uint8_t,GHOST_PAGE> code{};GhostRemote::State state{};
    if(!Read(a,code)||std::memcmp(code.data(),GhostRemoteStart,code.size())||
        !Read(a+GHOST_PAGE,state)||state.magic!=GhostRemote::Magic||
        state.tick!=module+Tick||state.position!=module+Position||state.axis!=module+Axis||
        state.clock!=Clock()||state.currentMatch!=module+GameOffsets::Rva(0x591B898)||
        state.getPos!=module+GameOffsets::Rva(0x57C0B2C)||state.setPos!=module+GameOffsets::Rva(0x6B49E10)||
        state.hp!=module+GameOffsets::Rva(0x56AA7C8)||state.waitSync!=module+GameOffsets::Rva(0x5636F20)||
        state.vehicle!=module+GameOffsets::Rva(0x561CA30)||state.catapult!=module+GameOffsets::Rva(0x5624820)||
        state.cannon!=module+GameOffsets::Rva(0x5624920)||state.chair!=module+GameOffsets::Rva(0x562B3D4)||state.chairAlt!=module+GameOffsets::Rva(0x562B488)||
        state.parachute!=module+GameOffsets::Rva(0x561C7C8)||state.strop!=module+GameOffsets::Rva(0x561CAE4)||state.rail!=module+GameOffsets::Rva(0x5624A20)||
        state.seesaw!=module+GameOffsets::Rva(0x562B53C)||state.platform!=module+GameOffsets::Rva(0x5624488))return false;
    allocation=a;sequence=state.sequence&~1u;epoch=state.epoch+1;
    input.epoch=epoch;published=true;Cancel();return true;
}
int Install(uint64_t matchClass,uint64_t packetClass,uint64_t axisClass) {
    const std::array<uint64_t,3> slots={matchClass+Slot,packetClass+Slot,axisClass+Slot};
    const std::array<uint64_t,3> original={module+Tick,module+Position,module+Axis};
    const std::array<uint64_t,3> offsets={0,GHOST_POSITION_ENTRY,GHOST_AXIS_ENTRY};
    std::array<uint64_t,3> current{};
    for(size_t i=0;i<3;++i)if(!Read(slots[i],current[i]))return 9;
    if(!allocation && current[0]!=original[0] && !Adopt(current[0]))return 9;
    if(!allocation){
        for(size_t i=0;i<3;++i)if(current[i]!=original[i])return 9;
        const uint64_t clock=Clock();if(!clock)return 9;
        const auto mapping=SilentAimMapping::Map(task,GhostRemoteStart,GhostRemoteEnd);
        if(!mapping.address)return 10;
        GhostRemote::State initial{};
        initial.tick=original[0];initial.position=original[1];initial.axis=original[2];initial.clock=clock;
        initial.currentMatch=module+GameOffsets::Rva(0x591B898);initial.getPos=module+GameOffsets::Rva(0x57C0B2C);
        initial.setPos=module+GameOffsets::Rva(0x6B49E10);initial.hp=module+GameOffsets::Rva(0x56AA7C8);initial.waitSync=module+GameOffsets::Rva(0x5636F20);
        initial.vehicle=module+GameOffsets::Rva(0x561CA30);initial.catapult=module+GameOffsets::Rva(0x5624820);
        initial.cannon=module+GameOffsets::Rva(0x5624920);initial.chair=module+GameOffsets::Rva(0x562B3D4);initial.chairAlt=module+GameOffsets::Rva(0x562B488);
        initial.parachute=module+GameOffsets::Rva(0x561C7C8);initial.strop=module+GameOffsets::Rva(0x561CAE4);initial.rail=module+GameOffsets::Rva(0x5624A20);
        initial.seesaw=module+GameOffsets::Rva(0x562B53C);initial.platform=module+GameOffsets::Rva(0x5624488);
        if(!Write(mapping.address+GHOST_PAGE,initial)){mach_vm_deallocate(task,mapping.address,2*GHOST_PAGE);return 10;}
        allocation=mapping.address;
    }
    bool allInstalled=true;
    for(size_t i=0;i<3;++i){
        if(current[i]!=original[i]&&current[i]!=allocation+offsets[i])return 9;
        if(current[i]!=allocation+offsets[i])allInstalled=false;
    }
    if(allInstalled)return 8;
    for(uint64_t slot:slots)if(!Writable(slot))return 10;
#ifndef MIZZE_INJECTED
    if(task_suspend(task)!=KERN_SUCCESS)return 10;
#endif
    bool ok=true;
    for(size_t i=0;i<3;++i){
        uint64_t value=0;
        if(!Read(slots[i],value)){ok=false;break;}
        if(value==allocation+offsets[i])continue;
        if(value!=original[i]){ok=false;break;}
#ifdef MIZZE_INJECTED
        if(!__atomic_compare_exchange_n((uint64_t *)slots[i],&value,allocation+offsets[i],false,
            __ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST)){ok=false;break;}
#else
        if(!Write(slots[i],allocation+offsets[i])){ok=false;break;}
#endif
    }
#ifndef MIZZE_INJECTED
    task_resume(task);
#endif
    // Partial installation is harmless: command remains 0 until all slots work.
    return ok?8:9;
}
uint64_t Deadline() {
    mach_timebase_info_data_t tb{};
    return mach_timebase_info(&tb)==KERN_SUCCESS&&tb.numer&&tb.denom ?
        mach_absolute_time()+300000000ULL*tb.denom/tb.numer:0;
}
GhostModeSnapshot ReadSnapshot(bool *fresh=nullptr) {
    if(fresh)*fresh=false;
    if(!allocation)return {};
    for(int attempt=0;attempt<2;++attempt){
        GhostRemote::State state{};uint32_t before=0,after=1;
        if(!Read(State()+GHOST_OUT_SEQUENCE,before)||(before&1u)||
            !Read(State(),state)||!Read(State()+GHOST_OUT_SEQUENCE,after)||before!=after)continue;
        snapshot={state.active!=0,state.status,state.anchorMatch,state.anchorLocal,
            state.ticks,state.packets,state.axes,state.returns,
            {state.anchor[0],state.anchor[1],state.anchor[2]}};
        if(wanted&&state.anchorEpoch!=input.epoch)snapshot.active=false;
        if(fresh)*fresh=true;
        break;
    }
    if(snapshot.match!=input.match||snapshot.local!=input.local||!input.command||
        (wanted&&snapshot.status==6))snapshot.active=false;
    if(input.deadline&&mach_absolute_time()>input.deadline){snapshot.active=false;snapshot.status=8;}
    return snapshot;
}
}
void GhostModeSetEnabled(bool value) {
    std::lock_guard<std::recursive_mutex> guard(mutex);
    if(wanted==value)return;
    returnPending=!value&&allocation&&input.command==1;
    wanted=value;++epoch;
    snapshot.active=false;
    if(allocation){
        input.command=wanted?1:(returnPending?2:0);input.epoch=epoch;input.deadline=Deadline();
        if(!Publish())Cancel();
    }
}
void GhostModeCancel(){std::lock_guard<std::recursive_mutex> guard(mutex);Cancel();}
GhostModeSnapshot GhostModeRead(){std::lock_guard<std::recursive_mutex> guard(mutex);return ReadSnapshot();}
int GhostModeUpdate(uint64_t base) {
    std::lock_guard<std::recursive_mutex> guard(mutex);
    if(!wanted&&!returnPending)return lastResult=1;
    if(!isVaildPtr(base)||!Attach(base)){Cancel();return lastResult=10;}
    const uint64_t match=getMatch(getMatchGame(base)),local=getLocalPlayer(match);
    // The callback checks native HP/knock before capture and return. A missing
    // HUD PRI-health snapshot must not keep an otherwise valid match unarmed.
    if(!isVaildPtr(match)||!isVaildPtr(local)){Cancel();return lastResult=11;}
    if(!wanted){
        // A changed/dead owner cancels, never teleports a replacement player.
        if(input.match!=match||input.local!=local){Cancel();return lastResult=11;}
        bool fresh=false;
        const auto out=ReadSnapshot(&fresh);
        if(fresh&&!out.match){Cancel();return lastResult=1;}
        input.command=2;input.deadline=Deadline();
        if(!input.deadline||!Publish()){Cancel();return lastResult=10;}
        return lastResult=8;
    }
    if(CACurrentMediaTime()<retryAt)return lastResult;
    uint64_t matchClass=0,packet=0,axes=0,packetClass=0,axesClass=0,body=0,pos=0,vel=0,axisBody=0;
    if(!Read(match,matchClass)||!isVaildPtr(matchClass)||!Verify()){
        Cancel();retryAt=CACurrentMediaTime()+1;return lastResult=9;
    }
    if(!Read(match+0x660,packet)||!Read(match+0x668,axes)||
        !ReadClass(packet,"DCAOPGIKAFE",packetClass)||!ReadClass(axes,"GKKODHEIJAL",axesClass)){
        Cancel();return lastResult=9;
    }
    input.bodyClass=input.posClass=input.velClass=input.axisClass=0;
    if(!Read(packet+0x18,body)||!ReadClass(body,"IFHJKHPIJPC",input.bodyClass)||
        !Read(body+0x18,pos)||!ReadClass(pos,"LDCJOLOBGGH",input.posClass)||
        !Read(body+0x30,vel)||!ReadClass(vel,"BJFGLKKKOAN",input.velClass)){
        Cancel();return lastResult=2;
    }
    if(Read(axes+0x18,axisBody)&&isVaildPtr(axisBody) &&
        !ReadClass(axisBody,"CJLFOJMIOEA",input.axisClass)){Cancel();return lastResult=9;}
    const int result=Install(matchClass,packetClass,axesClass);
    if(result!=8){Cancel();retryAt=CACurrentMediaTime()+1;return lastResult=result;}
    input.command=1;input.deadline=Deadline();input.match=match;input.local=local;
    input.packet=packet;input.axisPacket=axes;input.epoch=epoch;
    if(!input.deadline||!Publish()){Cancel();return lastResult=10;}
    return lastResult=8;
}
#else
void GhostModeSetEnabled(bool){}
void GhostModeCancel(){}
int GhostModeUpdate(uint64_t){return 9;}
GhostModeSnapshot GhostModeRead(){return {};}
#endif
