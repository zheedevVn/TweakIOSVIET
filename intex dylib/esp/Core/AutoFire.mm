#include "GameOffsets.h"
#include "AutoFire.h"
#include "SilentAim.h"
#if defined(__aarch64__) || defined(__arm64__)
#include "AutoFireRemoteLayout.h"
#include "SilentAimRemoteMapping.h"
#include "SilentAimWeapon.h"
#include "SwapInventory.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <cmath>
#include <mutex>
#include <vector>
extern "C" const unsigned char AutoFireRemoteStart[], AutoFireRemoteEnd[];
namespace {
constexpr uint64_t Getter=GameOffsets::Rva(0x5616118), Start=GameOffsets::Rva(0x5C179E8), Stop=GameOffsets::Rva(0x5C222EC);
// Weapon.LDKCJEMDAMC() returns the current fire interval, including attributes
// and weapon type. POFKDNELDJL.IPFONNHEKFA compares accumulated dt against it
// before each virtual-182 shot (0x5BA4054..0x5BA40A4).
constexpr uint64_t Interval=GameOffsets::Rva(0x5BF3B0C);
// Unity's standard Raycast overload, not the game's ExtraMask extension.
constexpr uint64_t Raycast=GameOffsets::Rva(0x8DE4904), HitCollider=GameOffsets::Rva(0x8DF0730);
constexpr uint64_t ComponentTransform=GameOffsets::Rva(0x8D59C2C), IsChild=GameOffsets::Rva(0x8D6ECE0), RootTransform=GameOffsets::Rva(0x56182FC);
constexpr uint64_t FireEffect=GameOffsets::Rva(0x56AC3A8), EffectSlot=0x138+182*16;
constexpr uint64_t Tracer=GameOffsets::Rva(0x5C76890), TracerSlot=0x138+5*16;
constexpr uint64_t MetadataInit=GameOffsets::Rva(0xA11121C), TracerTypeInfo=GameOffsets::Rva(0xBB4BEC8);
constexpr uint64_t ShotPresentation=GameOffsets::Rva(0x5C22FA8), ShotHit=GameOffsets::Rva(0x5C23B54);
// Player.PostUpdate calls the current weapon's MAMFDNEJAPF(float,float)
// through virtual slot 28 at 0x569C4E8. Player.OnUpdate is also called
// directly, so replacing its virtual slot can install a callback with no ticks.
constexpr uint64_t UpdateSlot=0x138+28*16, StartSlot=0x138+182*16, StopSlot=0x138+213*16;
struct UpdateFingerprint { uint64_t offset; uint32_t hash; };
// Slot-28 implementations whose start/stop slots use the verified methods
// in the supplied 1.132.1 IPA. Each has the same two-float ABI.
constexpr UpdateFingerprint weaponUpdates[] = {
    {GameOffsets::Rva(0x5C14594),0x3D459FF7}, {GameOffsets::Rva(0x5C4552C),0x41E95E11}, {GameOffsets::Rva(0x5B633A8),0x2A0C22A4},
    {GameOffsets::Rva(0x5B70CE4),0x4365F46B}, {GameOffsets::Rva(0x5B7DD00),0xFE362A57}, {GameOffsets::Rva(0x5B8104C),0xAC5E66DE},
    {GameOffsets::Rva(0x5BA8E54),0x96FDD838}, {GameOffsets::Rva(0x5BA9650),0x37041440}, {GameOffsets::Rva(0x5BB12F0),0x6A9FF040},
    {GameOffsets::Rva(0x5BDA64C),0x27399A41}, {GameOffsets::Rva(0x5BE8438),0x740125D4}, {GameOffsets::Rva(0x5C74264),0x597102DC}
};
struct Session {
    uint64_t slot=0, allocation=0, original=0;
    uint32_t sequence=0;
    bool published=false;
    uint64_t state() const { return allocation+AUTO_PAGE; }
};
std::recursive_mutex mutex;
mach_port_t task=MACH_PORT_NULL;
int pid=-1;
uint64_t module=0, activeSlot=0;
bool codeVerified=false;
std::vector<Session> sessions;
double retryAt=0;
int retryState=9;
bool ReadBytes(uint64_t a, void *v, size_t n) {
    mach_vm_size_t actual=0;
    return task!=MACH_PORT_NULL && isVaildPtr(a) &&
        mach_vm_read_overwrite(task,a,n,(mach_vm_address_t)v,&actual)==KERN_SUCCESS && actual==n;
}
template<class T> bool Read(uint64_t a,T &v) { return ReadBytes(a,&v,sizeof(v)); }
bool WriteBytes(uint64_t a,const void *v,size_t n) {
    return task!=MACH_PORT_NULL && isVaildPtr(a) &&
        mach_vm_write(task,a,(pointer_t)v,(mach_msg_type_number_t)n)==KERN_SUCCESS;
}
template<class T> bool Write(uint64_t a,const T &v) { return WriteBytes(a,&v,sizeof(v)); }
void Disable(Session &s) {
    if (!s.published) return;
    const uint32_t odd=(s.sequence+1)|1u, off=0;
    s.sequence=odd+1;
    bool ok=Write(s.state()+AUTO_SEQUENCE,odd);
    ok=Write(s.state()+AUTO_ENABLED,off)&&ok;
    ok=Write(s.state()+AUTO_PRESENTATION,off)&&ok;
    ok=Write(s.state()+AUTO_SWAP_ENABLED,off)&&ok;
    ok=Write(s.state()+AUTO_SEQUENCE,s.sequence)&&ok;
    if(ok)s.published=false;
}
void Clear() {
    for (auto &s : sessions) Disable(s);
    activeSlot=0;
    // Leave code mapped: a game thread may have cached its address. Disabled
    // callbacks release an owned hold on the next current-weapon tick.
}
template<size_t N> bool Fingerprint(uint64_t a,uint32_t expected) {
    std::array<uint8_t,N> bytes{}; if(!Read(a,bytes))return false;
    uint32_t h=0x811C9DC5;for(uint8_t b:bytes)h=(h^b)*0x01000193u;
    return h==GameOffsets::ExpectedHash(expected);
}
bool SupportedUpdate(uint64_t original) {
    for (const auto &f : weaponUpdates)
        if (original==module+f.offset) return Fingerprint<0x100>(original,f.hash);
    return false;
}
bool Writable(uint64_t a) {
    mach_vm_address_t r=a;mach_vm_size_t n=0;natural_t depth=0;
    vm_region_submap_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_SUBMAP_INFO_COUNT_64;
    return a%8==0 && mach_vm_region_recurse(task,&r,&n,&depth,(vm_region_recurse_info_t)&info,&count)==KERN_SUCCESS &&
        !info.is_submap && r<=a && a-r<=n && n-(a-r)>=8 && (info.protection&VM_PROT_WRITE);
}
bool Attach(uint64_t base) {
#ifdef MIZZE_INJECTED
    const mach_port_t candidate=mach_task_self();
#else
    const mach_port_t candidate=get_task;
#endif
    int candidatePID=-1;
    if(candidate==MACH_PORT_NULL || pid_for_task(candidate,&candidatePID)!=KERN_SUCCESS){Clear();return false;}
    if(task==candidate && pid==candidatePID && module==base)return true;
    Clear();
    if(task!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),task);
    task=MACH_PORT_NULL;sessions.clear();retryAt=0;codeVerified=false;
    if(mach_port_mod_refs(mach_task_self(),candidate,MACH_PORT_RIGHT_SEND,1)!=KERN_SUCCESS)return false;
    task=candidate;pid=candidatePID;module=base;return true;
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
Session *Find(uint64_t slot) {
    for (auto &s : sessions) if (s.slot==slot) return &s;
    return nullptr;
}
bool Adopt(uint64_t slot,uint64_t a) {
    if(!isVaildPtr(a)||a%AUTO_PAGE||sessions.size()>=64)return false;
    std::array<uint8_t,AUTO_PAGE> code{};AutoFireRemote::State state{};
    if(!Read(a,code)||std::memcmp(code.data(),AutoFireRemoteStart,code.size())||
        !Read(a+AUTO_PAGE,state)||state.magic!=AutoFireRemote::Magic||!SupportedUpdate(state.original)||
        state.getter!=module+Getter||state.start!=module+Start||state.stop!=module+Stop||
        state.interval!=module+Interval||state.clock!=Clock()||state.effectOriginal!=module+FireEffect||
        state.tracerOriginal!=module+Tracer||state.metadataInit!=module+MetadataInit||
        state.tracerTypeInfo!=module+TracerTypeInfo||state.shotOriginal!=module+ShotPresentation||
        state.shotHit!=module+ShotHit||state.swapCooldown!=module+GameOffsets::Rva(0x5636E60)||
        state.raycast!=module+Raycast||state.hitCollider!=module+HitCollider||
        state.componentTransform!=module+ComponentTransform||state.isChild!=module+IsChild||
        state.rootTransform!=module+RootTransform)return false;
    sessions.push_back({slot,a,state.original,state.sequence&~1u,true});
    Disable(sessions.back());
    return true;
}
int Install(uint64_t slot,Session *&session) {
    uint64_t current=0;if(!Read(slot,current))return 9;
    session=Find(slot);
    if(session && current==session->allocation)return 8;
    if(!session && !SupportedUpdate(current)) {
        if(!Adopt(slot,current))return 9;
        session=Find(slot);return 8;
    }
    if(session && current!=session->original)return 9;
    if(!session){
        if(sessions.size()>=64)return 9;
        const uint64_t clock=Clock();if(!clock)return 9;
        const auto mapping=SilentAimMapping::Map(task,AutoFireRemoteStart,AutoFireRemoteEnd);
        if(!mapping.address)return 10;
        AutoFireRemote::State state;state.original=current;state.clock=clock;
        state.getter=module+Getter;state.start=module+Start;state.stop=module+Stop;
        state.interval=module+Interval;
        state.effectOriginal=module+FireEffect;
        state.tracerOriginal=module+Tracer;
        state.metadataInit=module+MetadataInit;
        state.tracerTypeInfo=module+TracerTypeInfo;
        state.shotOriginal=module+ShotPresentation;
        state.shotHit=module+ShotHit;
        state.swapCooldown=module+GameOffsets::Rva(0x5636E60);
        state.raycast=module+Raycast;state.hitCollider=module+HitCollider;
        state.componentTransform=module+ComponentTransform;
        state.isChild=module+IsChild;state.rootTransform=module+RootTransform;
        if(!Write(mapping.address+AUTO_PAGE,state)){mach_vm_deallocate(task,mapping.address,2*AUTO_PAGE);return 10;}
        sessions.push_back({slot,mapping.address,current,0});session=&sessions.back();
    }
    if(!Writable(slot))return 10;
#ifdef MIZZE_INJECTED
    uint64_t expected=session->original;
    if(!__atomic_compare_exchange_n((uint64_t *)slot,&expected,session->allocation,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST))return 9;
#else
    if(task_suspend(task)!=KERN_SUCCESS)return 10;
    const bool ok=Read(slot,current)&&current==session->original&&Write(slot,session->allocation);
    task_resume(task);if(!ok)return 10;
#endif
    return 8;
}
int InstallPresentation(Session &session,uint64_t slot,uint64_t native,uint64_t entry) {
    uint64_t current=0;
    if(!Read(slot,current))return 9;
    const uint64_t replacement=session.allocation+entry;
    if(current==replacement)return 8;
    bool supported=current==module+native;
    for(const auto &other:sessions) supported=supported||current==other.allocation+entry;
    if(!supported)return 9;
    if(!Writable(slot))return 10;
#ifdef MIZZE_INJECTED
    return __atomic_compare_exchange_n((uint64_t *)slot,&current,replacement,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST)?8:9;
#else
    if(task_suspend(task)!=KERN_SUCCESS)return 10;
    uint64_t live=0;
    const bool ok=Read(slot,live)&&live==current&&Write(slot,replacement);
    task_resume(task);return ok?8:10;
#endif
}
[[maybe_unused]] int InstallEffect(Session &session,uint64_t local) {
    uint64_t klass=0;
    if(!Read(local,klass)||!isVaildPtr(klass))return 9;
    return InstallPresentation(session,klass+EffectSlot,FireEffect,AUTO_EFFECT_ENTRY);
}
template<size_t N> bool ClassText(uint64_t address,const char (&expected)[N]) {
    uint64_t p=0;std::array<char,N> text{};
    return Read(address,p)&&Read(p,text)&&!std::memcmp(text.data(),expected,N);
}
[[maybe_unused]] int InstallTracer(Session &session,uint64_t weapon) {
    uint32_t ready=0;
    if(!Read(session.state()+AUTO_METADATA_READY,ready))return 10;
    // The signed weapon callback resolves this metadata usage on a game thread.
    // Do not publish automatic fire before its lazy visual class is available.
    if(!ready)return 7;
    uint64_t klass=0,component=0,actual=0;
    if(!Read(module+TracerTypeInfo,klass)||!isVaildPtr(klass)||
        !ClassText(klass+0x10,"NGMILJIELKA")||!ClassText(klass+0x18,"COW.GamePlay")||
        !Read(weapon+0x530,component))return 9;
    if(component&&(!Read(component,actual)||actual!=klass))return 9;
    return InstallPresentation(session,klass+TracerSlot,Tracer,AUTO_TRACER_ENTRY);
}
uint64_t Count(uint64_t offset) {
    uint64_t total=0;
    for (const auto &s : sessions) { uint64_t n=0; if(Read(s.state()+offset,n))total+=n; }
    return total;
}
}
void AutoFireClear(){std::lock_guard<std::recursive_mutex> guard(mutex);Clear();}
uint64_t AutoFireStartCount(){std::lock_guard<std::recursive_mutex> guard(mutex);return Count(AUTO_STARTS);}
uint64_t AutoFireTickCount(){std::lock_guard<std::recursive_mutex> guard(mutex);return Count(AUTO_TICKS);}
int AutoFireUpdate(uint64_t base,uint64_t match,uint64_t local,uint64_t target,
                   const Vector3 &origin,const Vector3 &head,const Vector3 &body,uint32_t headPercent,bool swap){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    if(!Attach(base)){Clear();return 10;}
    uint8_t localKnock=1, targetKnock=1;
    if(getMatch(getMatchGame(base))!=match||getLocalPlayer(match)!=local||
        get_CurHP(local)<=0||!Read(local+kKnocked,localKnock)||localKnock){Clear();return 7;}
    const auto finite=[](const Vector3 &v){return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z);};
    const bool fire=target&&finite(origin)&&finite(head)&&finite(body)&&headPercent<=100&&
        get_CurHP(target)>0&&Read(target+kKnocked,targetKnock)&&!targetKnock&&
        !isLocalTeamMate(local,target)&&getAimVisibility(target);
    const double now=CACurrentMediaTime();
    if(now<retryAt)return retryState;
    uint64_t weaponClass=0,start=0,stop=0;
    const uint64_t weapon=SilentAimWeapon::OnHand(local,[](uint64_t a,auto &v){return Read(a,v);},[](uint64_t a){return isVaildPtr(a);});
    if(!weapon||!Read(weapon,weaponClass)||!isVaildPtr(weaponClass)||
        !Read(weaponClass+StartSlot,start)||start!=base+Start||!Read(weaponClass+StopSlot,stop)||stop!=base+Stop||
        (!codeVerified && (!Fingerprint<0xCC>(base+Getter,0xC5E012EE)||!Fingerprint<0x5A8>(base+Start,0x9AD8096C)||
        !Fingerprint<0x1E4>(base+Stop,0xA2F105A1)||!Fingerprint<0xCC>(base+GameOffsets::Rva(0x569C434),0x88A4BD15)||
        !Fingerprint<0x210>(base+Interval,0x131E1130)||!Fingerprint<0x50>(base+GameOffsets::Rva(0x5BA4054),0xA165FA4A)||
        !Fingerprint<0x10>(base+GameOffsets::Rva(0x6483C7C),0x572D5404)||!Fingerprint<0x1E8>(base+FireEffect,0x1EE7E697)||
        !Fingerprint<0x26B0>(base+Tracer,0x6D340948)||!Fingerprint<0x18>(base+MetadataInit,0x2FC932FA)||
        !Fingerprint<0x30>(base+GameOffsets::Rva(0x5C1E910),0xC285FA0E)||!Fingerprint<0x30C>(base+ShotPresentation,0x76159E8D)||
        !Fingerprint<0x1B08>(base+ShotHit,0xF0BC2099)||
        !Fingerprint<0x17C>(base+Raycast,0x8B3DCDAE)||!Fingerprint<0x1F0>(base+GameOffsets::Rva(0x8DE4A80),0x8956580B)||
        !Fingerprint<0xF4>(base+HitCollider,0xF884A08C)||!Fingerprint<0x50>(base+ComponentTransform,0xE5B7D25C)||
        !Fingerprint<0x64>(base+IsChild,0xDECACF20)||!Fingerprint<0x154>(base+RootTransform,0x8E831156)))){
        Clear();retryAt=now+1;retryState=9;return 9;
    }
    codeVerified=true; // Immutable signed code; reset when task/PID/base changes.
    Session *session=nullptr;
    const int result=Install(weaponClass+UpdateSlot,session);
    if(result!=8){Clear();retryAt=now+1;retryState=result;return result;}
    // Keep fire effects and projectile presentation untouched. These native
    // methods can contain hotfix/state work beyond rendering; skipping an
    // entire method isn't a verified way to hide only a tracer.
    // Keep virtual-223 untouched: it runs shot setup and reporting before the
    // hit routine. Calling only its final hit routine drops those native steps.
    if(activeSlot!=session->slot){for(auto &s:sessions)if(s.slot!=session->slot)Disable(s);activeSlot=session->slot;}
    const uint64_t silentGate=SilentAimAutoFireGate();
    if(!Write(session->state()+AUTO_SILENT_GATE,silentGate)){Clear();return 10;}
    uint64_t swapFunction=0,swapWeapon=0,localClass=0,manager=0;
    uint32_t swapSlot=0;
    if(swap&&Fingerprint<0xC0>(base+GameOffsets::Rva(0x5636E60),0x8C40F08F)&&Read(local,localClass)&&Read(localClass+0xDC8,swapFunction)&&
        ((swapFunction==base+GameOffsets::Rva(0x56B4EB4)&&Fingerprint<0x5F8>(swapFunction,0x40924917))||
         (swapFunction==base+GameOffsets::Rva(0x5A5C9D4)&&Fingerprint<0x100>(swapFunction,0x538C5B13)))&&Read(local + MIZZE_PLAYER_740,manager)) {
        const auto next=AutoSwap::Next(manager,local,weapon,base+Start,
            [](uint64_t a,auto &v){return Read(a,v);},[](uint64_t a){return isVaildPtr(a);});
        swapWeapon=next.weapon;swapSlot=next.slot;
    }
    const uint32_t swapEnabled=swapWeapon?1:0,presentation=0;
    mach_timebase_info_data_t tb{};
    if(mach_timebase_info(&tb)!=KERN_SUCCESS||!tb.numer||!tb.denom){Clear();return 9;}
    struct Publication {uint32_t enabled;uint64_t deadline,local,match,weapon;} __attribute__((packed));
    // Match Silent's 150 ms freshness window, including 30 FPS HUD pacing.
    const Publication p{fire&&silentGate?1u:0u,mach_absolute_time()+150000000ULL*tb.denom/tb.numer,local,match,weapon};
    const uint32_t odd=(session->sequence+1)|1u;session->sequence=odd+1;
    session->published=true; // Clear also handles an interrupted publication.
    const AutoFireRemote::Aim aim{target,{origin.x,origin.y,origin.z},
        {head.x,head.y,head.z},{body.x,body.y,body.z},headPercent};
    const bool ok=Write(session->state()+AUTO_SEQUENCE,odd)&&
        WriteBytes(session->state()+AUTO_ENABLED,&p,sizeof(p))&&
        Write(session->state()+AUTO_PRESENTATION,presentation)&&Write(session->state()+AUTO_SWAP_ENABLED,swapEnabled)&&
        Write(session->state()+AUTO_SWAP_FUNCTION,swapFunction)&&Write(session->state()+AUTO_SWAP_SLOT,swapSlot)&&
        Write(session->state()+AUTO_SWAP_WEAPON,swapWeapon)&&Write(session->state()+AUTO_TARGET,aim)&&
        Write(session->state()+AUTO_SEQUENCE,session->sequence);
    if(!ok){Clear();return 10;}
    return fire?8:7;
}
#else
void AutoFireClear(){}
uint64_t AutoFireStartCount(){return 0;}
uint64_t AutoFireTickCount(){return 0;}
int AutoFireUpdate(uint64_t,uint64_t,uint64_t,uint64_t,const Vector3 &,const Vector3 &,const Vector3 &,uint32_t,bool){return 9;}
#endif
