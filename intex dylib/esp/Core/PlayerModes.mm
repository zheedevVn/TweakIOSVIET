#include "GameOffsets.h"
#include "PlayerModes.h"
#if defined(__aarch64__) || defined(__arm64__)
#include "PlayerModesLayout.h"
#include "PlayerModesInstallPolicy.h"
#include "PlayerModesControlPolicy.h"
#include "PlayerModesControllerPolicy.h"
#include "VisualSpinPolicy.h"
#include "SilentAimRemoteMapping.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <mutex>
#include <vector>
extern "C" const unsigned char PlayerModesRemoteStart[], PlayerModesRemoteEnd[];
namespace {
constexpr uint64_t Slot=PlayerModesInstall::Slots[0];
struct Signature { uint64_t offset; size_t size; uint32_t hash; };
constexpr Signature signatures[] = {
    {GameOffsets::Rva(0x5660700),0x844,0x4C79AF54},{GameOffsets::Rva(0x5A4BEC0),0x654,0x7C4BDB69},
    {GameOffsets::Rva(0x5A4C690),0x41C,0xE5A62294},{GameOffsets::Rva(0x6B49D04),0x10C,0x5C6FFC2C},
    {GameOffsets::Rva(0x6B49E10),0x104,0xAACE9654},{GameOffsets::Rva(0x591B898),0x1C8,0x92F2568B},
    {GameOffsets::Rva(0x56AA7C8),0x110,0x4478C55F},{GameOffsets::Rva(0x561CA30),0xB4,0xABF31A13},
    {GameOffsets::Rva(0x561C7C8),0x6C,0x7958F6CC},{GameOffsets::Rva(0x5636F20),0x60,0x6E4B75FE},
    {GameOffsets::Rva(0x6B4A924),0x8,0x64A6725A},{GameOffsets::Rva(0x569C1E4),0x2BAC,0x458F369A},
    {GameOffsets::Rva(0x646B648),0xB0,0x7C5E5F3F},{GameOffsets::Rva(0x5631D28),0x58,0xEBC9879D},
    {GameOffsets::Rva(0x56268B4),0x24,0xE7908BBE},
    {GameOffsets::Rva(0x8D6C788),0x60,0xAE8A72F8},{GameOffsets::Rva(0x8D6C860),0x78,0xD1FEABDC},
    {GameOffsets::Rva(0x8D6ECE0),0x64,0xDECACF20},{GameOffsets::Rva(0x6B49C14),0xF0,0x990FC153},
    {GameOffsets::Rva(0x56182FC),0x154,0x8E831156},{GameOffsets::Rva(0x6B4964C),0x8,0x80D43BE2},
    {GameOffsets::Rva(0x5639C90),0x154,0x3D4AF30F},
    {GameOffsets::Rva(0x8D6C38C),0x64,0xDB814CED},{GameOffsets::Rva(0x8D6C454),0x74,0x61044F36},
    {GameOffsets::Rva(0x8D6E900),0x50,0x178B2DA7},{GameOffsets::Rva(0x8D6EEB0),0x64,0x54800249},
    {GameOffsets::Rva(0x8D58C18),0x50,0x3655F88D},{GameOffsets::Rva(0x8D58C68),0x64,0x43B62F71},
    {GameOffsets::Rva(0x8CDCAF4),0x50,0xD78D78BD},{GameOffsets::Rva(0x8CDCB44),0x64,0x154D9667},
    {GameOffsets::Rva(0x8D6C5B4),0x60,0x6881CEE5},{GameOffsets::Rva(0x8D6C68C),0x74,0x54F82A6C}
};
// Metadata: MatchGame.OnLateUpdate and its supplied game-mode overrides all
// occupy BaseGame slot 18, ABI (self, MethodInfo), after the native late chain.
constexpr Signature lateSignatures[] = {
    {GameOffsets::Rva(0x5A9A654),0x78,0x01F24198},{GameOffsets::Rva(0x635594C),0x54,0xFB5E72CE},
    {GameOffsets::Rva(0x63706CC),0x54,0x3010A312},{GameOffsets::Rva(0x63733EC),0x54,0x2EFCAE4E},
    {GameOffsets::Rva(0x6374918),0x54,0x482878B5},{GameOffsets::Rva(0x66E0A24),0x54,0x19ABE41A},
    {GameOffsets::Rva(0x66F031C),0x54,0xCDA7586C}
};
constexpr uint64_t LateSlot=0x138+18*16;
struct LateSession { uint64_t slot=0,allocation=0,original=0,shared=0; };
struct Session {
    uint64_t slot=0, allocation=0, original=0, originalPost=0;
    uint32_t sequence=0;
    bool published=false;
    uint64_t state()const{return allocation+MODES_PAGE;}
};
std::recursive_mutex mutex;
mach_port_t task=MACH_PORT_NULL;
int pid=-1;
uint64_t module=0, ownerMatch=0, ownerLocal=0;
uint32_t wanted=0, epoch=0, previousFlags=0;
float height=PlayerModesControl::DefaultHeight;
PlayerModesControl::State control;
VisualSpin::Phase spinPhase;
float spinSpeed=VisualSpin::DefaultSpeed;
bool verified=false;
double retryAt=0;
int lastResult=1;
PlayerModesSnapshot snapshot{};
double lastSample=0, lastTickAt=0, lastPostAt=0;
uint64_t sampledTicks=0, sampledPostTicks=0;
std::vector<Session> sessions;
std::vector<LateSession> lateSessions;
bool ReadBytes(uint64_t address,void *value,size_t size){
    mach_vm_size_t actual=0;
    return task!=MACH_PORT_NULL&&isVaildPtr(address)&&
        mach_vm_read_overwrite(task,address,size,(mach_vm_address_t)value,&actual)==KERN_SUCCESS&&actual==size;
}
template<class T>bool Read(uint64_t address,T &value){return ReadBytes(address,&value,sizeof(value));}
bool WriteBytes(uint64_t address,const void *value,size_t size){
    return task!=MACH_PORT_NULL&&isVaildPtr(address)&&
        mach_vm_write(task,address,(pointer_t)value,(mach_msg_type_number_t)size)==KERN_SUCCESS;
}
template<class T>bool Write(uint64_t address,const T &value){return WriteBytes(address,&value,sizeof(value));}
bool Publish(Session &session,const PlayerModesRemote::Input &input){
    uint32_t odd=(session.sequence+1)|1u;session.sequence=odd+1;session.published=true;
    return Write(session.state()+MODES_SEQUENCE,odd)&&
        Write(session.state()+MODES_FLAGS,input)&&Write(session.state()+MODES_SEQUENCE,session.sequence);
}
void Clear(){
    PlayerModesRemote::Input off{};off.epoch=++epoch;
    for(auto &session:sessions)if(session.published&&Publish(session,off))session.published=false;
    ownerMatch=ownerLocal=0;previousFlags=0;
    control.Reset();
    spinPhase.Reset();
    snapshot.fly=snapshot.heldEnemies=0;snapshot.running=false;snapshot.spinStatus=0;
    // Keep executable callbacks mapped while game threads may still use them.
    // Each callback restores its own held transform before its original update.
}
bool Attach(uint64_t base){
#ifdef MIZZE_INJECTED
    const mach_port_t candidate=mach_task_self();
#else
    const mach_port_t candidate=get_task;
#endif
    int candidatePID=-1;
    if(candidate==MACH_PORT_NULL||pid_for_task(candidate,&candidatePID)!=KERN_SUCCESS){Clear();return false;}
    if(task==candidate&&pid==candidatePID&&module==base)return true;
    Clear();
    if(task!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),task);
    task=MACH_PORT_NULL;sessions.clear();lateSessions.clear();verified=false;retryAt=0;
    snapshot={};lastSample=lastTickAt=lastPostAt=0;sampledTicks=sampledPostTicks=0;
    if(mach_port_mod_refs(mach_task_self(),candidate,MACH_PORT_RIGHT_SEND,1)!=KERN_SUCCESS)return false;
    task=candidate;pid=candidatePID;module=base;return true;
}
bool Verify(){
    if(verified)return true;
    std::array<uint8_t,0x2BAC> bytes{};
    for(const auto &signature:signatures){
        if(!ReadBytes(module+signature.offset,bytes.data(),signature.size)){
            snapshot.detail="không đọc được mã game";snapshot.failedOffset=signature.offset;return false;
        }
        uint32_t hash=0x811C9DC5;
        for(size_t i=0;i<signature.size;++i)hash=(hash^bytes[i])*0x01000193u;
        if(hash!=GameOffsets::ExpectedHash(signature.hash)){snapshot.detail="mã game khác bản đã kiểm tra";snapshot.failedOffset=signature.offset;return false;}
    }
    return verified=true;
}
uint64_t Clock(){
    const void *clock=(const void *)&mach_absolute_time;Dl_info info{};
    if(!dladdr(clock,&info)||!info.dli_fname||!info.dli_fbase)return 0;
    const char *name=std::strrchr(info.dli_fname,'/');
    const uint64_t base=get_image_base_address(task,name?name+1:info.dli_fname);
    std::array<uint8_t,32> bytes{};
    const uint64_t address=base+((uintptr_t)clock-(uintptr_t)info.dli_fbase);
    return base&&Read(address,bytes)&&!std::memcmp(bytes.data(),clock,bytes.size())?address:0;
}
bool Supported(uint64_t original){return original==module+GameOffsets::Rva(0x5660700)||original==module+GameOffsets::Rva(0x5A4BEC0);}
bool Writable(uint64_t address){
    mach_vm_address_t region=address;mach_vm_size_t size=0;natural_t height=0;
    vm_region_submap_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_SUBMAP_INFO_COUNT_64;
    return address%8==0&&mach_vm_region_recurse(task,&region,&size,&height,(vm_region_recurse_info_t)&info,&count)==KERN_SUCCESS&&
        !info.is_submap&&region<=address&&address-region<=size&&size-(address-region)>=8&&(info.protection&VM_PROT_WRITE);
}
Session *Find(uint64_t slot){for(auto &session:sessions)if(session.slot==slot)return &session;return nullptr;}
bool Adopt(uint64_t slot,uint64_t address){
    if(!isVaildPtr(address)||address%MODES_PAGE||sessions.size()>=16)return false;
    std::array<uint8_t,MODES_PAGE> code{};PlayerModesRemote::State state{};
    if(!Read(address,code)||std::memcmp(code.data(),PlayerModesRemoteStart,code.size())||
        !Read(address+MODES_PAGE,state)||state.magic!=PlayerModesRemote::Magic||!Supported(state.original)||
        state.clock!=Clock()||state.currentMatch!=module+GameOffsets::Rva(0x591B898)||state.getPos!=module+GameOffsets::Rva(0x6B49D04)||
        state.setPos!=module+GameOffsets::Rva(0x6B49E10)||state.hp!=module+GameOffsets::Rva(0x56AA7C8)||state.vehicle!=module+GameOffsets::Rva(0x561CA30)||
        state.parachute!=module+GameOffsets::Rva(0x561C7C8)||state.waitSync!=module+GameOffsets::Rva(0x5636F20)||
        state.originalPost!=module+GameOffsets::Rva(0x569C1E4)||state.forcePos!=module+GameOffsets::Rva(0x646B648)||
        state.getRot!=module+GameOffsets::Rva(0x8D6C788)||state.setRot!=module+GameOffsets::Rva(0x8D6C860)||state.isChild!=module+GameOffsets::Rva(0x8D6ECE0)||
        state.model!=module+GameOffsets::Rva(0x5639C90)||state.localPos!=module+GameOffsets::Rva(0x8D6C38C)||state.setLocalPos!=module+GameOffsets::Rva(0x8D6C454)||
        state.childCount!=module+GameOffsets::Rva(0x8D6E900)||state.getChild!=module+GameOffsets::Rva(0x8D6EEB0)||
        state.getSpeed!=module+GameOffsets::Rva(0x8CDCAF4)||state.setSpeed!=module+GameOffsets::Rva(0x8CDCB44)||
        state.getEnabled!=module+GameOffsets::Rva(0x8D58C18)||state.setEnabled!=module+GameOffsets::Rva(0x8D58C68)||
        state.worldRot!=module+GameOffsets::Rva(0x8D6C5B4)||state.setWorldRot!=module+GameOffsets::Rva(0x8D6C68C))return false;
    sessions.push_back({slot,address,state.original,state.originalPost,state.sequence&~1u,true});
    epoch=state.input.epoch+1;
    PlayerModesRemote::Input off{};off.epoch=epoch;
    return Publish(sessions.back(),off);
}
int Install(uint64_t klass){
    uint64_t current=0;const uint64_t slot=klass+Slot;
    if(!Read(slot,current)){snapshot.detail="không đọc được nhịp nhân vật";return 9;}
    Session *session=Find(slot);
    if(!session&&!Supported(current)){
        if(!Adopt(slot,current)){snapshot.detail="loại nhân vật chưa hỗ trợ";return 9;}
        session=Find(slot);
    }
    if(session&&current!=session->original&&current!=session->allocation){snapshot.detail="nhịp nhân vật đã bị thay đổi";return 9;}
    uint64_t post=0;
    if(!Read(klass+PlayerModesInstall::Slots[2],post)||
        (post!=module+GameOffsets::Rva(0x569C1E4)&&(!session||post!=session->allocation+MODES_POST_ENTRY))){
        snapshot.detail="nhịp hiển thị chưa hỗ trợ";return 9;
    }
    if(!session){
        if(sessions.size()>=16)return 9;
        const uint64_t clock=Clock();if(!clock){snapshot.detail="không tìm được đồng hồ game";return 9;}
        const auto mapping=SilentAimMapping::Map(task,PlayerModesRemoteStart,PlayerModesRemoteEnd,MODES_STATE_SIZE);
        if(!mapping.address){snapshot.detail=mapping.operation;return 10;}
        PlayerModesRemote::State state{};
        state.original=current;state.clock=clock;state.currentMatch=module+GameOffsets::Rva(0x591B898);
        state.getPos=module+GameOffsets::Rva(0x6B49D04);state.setPos=module+GameOffsets::Rva(0x6B49E10);state.hp=module+GameOffsets::Rva(0x56AA7C8);
        state.vehicle=module+GameOffsets::Rva(0x561CA30);state.parachute=module+GameOffsets::Rva(0x561C7C8);state.waitSync=module+GameOffsets::Rva(0x5636F20);
        state.originalPost=post;
        state.forcePos=module+GameOffsets::Rva(0x646B648);
        state.getRot=module+GameOffsets::Rva(0x8D6C788);state.setRot=module+GameOffsets::Rva(0x8D6C860);state.isChild=module+GameOffsets::Rva(0x8D6ECE0);
        state.model=module+GameOffsets::Rva(0x5639C90);state.localPos=module+GameOffsets::Rva(0x8D6C38C);state.setLocalPos=module+GameOffsets::Rva(0x8D6C454);
        state.childCount=module+GameOffsets::Rva(0x8D6E900);state.getChild=module+GameOffsets::Rva(0x8D6EEB0);
        state.getSpeed=module+GameOffsets::Rva(0x8CDCAF4);state.setSpeed=module+GameOffsets::Rva(0x8CDCB44);
        state.getEnabled=module+GameOffsets::Rva(0x8D58C18);state.setEnabled=module+GameOffsets::Rva(0x8D58C68);
        state.worldRot=module+GameOffsets::Rva(0x8D6C5B4);state.setWorldRot=module+GameOffsets::Rva(0x8D6C68C);
        if(!Write(mapping.address+MODES_PAGE,state)){snapshot.detail="không ghi được trạng thái";mach_vm_deallocate(task,mapping.address,MODES_PAGE+MODES_STATE_SIZE);return 10;}
        sessions.push_back({slot,mapping.address,current,post,0,false});session=&sessions.back();
    }
    // All phases share restore/anchor rows; each entry calls its own original.
    // Publish virtual pointers only, never patch a method's instructions.
    const auto originals=PlayerModesInstall::Originals(session->original,session->originalPost);
    const auto callbacks=PlayerModesInstall::Callbacks(session->allocation);
    uint64_t concrete=0;
    bool bound=true;
    for(size_t i=0;i<PlayerModesInstall::Slots.size();++i){
        if(!Read(klass+PlayerModesInstall::Slots[i],concrete)||(concrete!=originals[i]&&concrete!=callbacks[i])){
            snapshot.detail="nhịp interface không khớp";return 9;
        }
        bound=bound&&concrete==callbacks[i];
    }
    if(bound)return 8;
    for(auto offset:PlayerModesInstall::Slots)
        if(!Writable(klass+offset)){snapshot.detail="vùng nhịp nhân vật chỉ đọc";return 10;}
    bool ok=false;
#ifdef MIZZE_INJECTED
    ok=PlayerModesInstall::Bind(klass,originals,callbacks,
        [](uint64_t address,uint64_t &value){return Read(address,value);},
        [](uint64_t address,uint64_t expected,uint64_t replacement){
            return __atomic_compare_exchange_n((uint64_t *)address,&expected,replacement,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST);
        });
#else
    if(task_suspend(task)!=KERN_SUCCESS){snapshot.detail="không đồng bộ được nhịp game";return 10;}
    ok=PlayerModesInstall::Bind(klass,originals,callbacks,
        [](uint64_t address,uint64_t &value){return Read(address,value);},
        [](uint64_t address,uint64_t expected,uint64_t replacement){
            uint64_t live=0;return Read(address,live)&&live==expected&&Write(address,replacement);
        });
    task_resume(task);
#endif
    if(!ok){snapshot.detail="không ghi được nhịp nhân vật";return 10;}
    return 8;
}
int InstallLate(uint64_t game,uint64_t shared){
    uint64_t klass=0,current=0;
    if(!Read(game,klass)||!isVaildPtr(klass)||!Read(klass+LateSlot,current))return 9;
    const uint64_t slot=klass+LateSlot;
    uint64_t original=current;
    for(auto it=lateSessions.rbegin();it!=lateSessions.rend();++it){
        if(it->slot!=slot||current!=it->allocation+MODES_LATE_ENTRY)continue;
        if(it->shared==shared)return 8;
        original=it->original;break;
    }
    const Signature *signature=nullptr;
    for(const auto &candidate:lateSignatures)
        if(original==module+candidate.offset){signature=&candidate;break;}
    std::array<uint8_t,0x78> bytes{};
    if(!signature||!ReadBytes(original,bytes.data(),signature->size)){
        snapshot.detail="Spin: nhịp cuối của chế độ này chưa hỗ trợ";return 9;
    }
    uint32_t hash=0x811C9DC5;
    for(size_t i=0;i<signature->size;++i)hash=(hash^bytes[i])*0x01000193u;
    if(hash!=GameOffsets::ExpectedHash(signature->hash)){snapshot.detail="Spin: nhịp cuối khác bản đã kiểm tra";snapshot.failedOffset=signature->offset;return 9;}
    if(!Writable(slot)||lateSessions.size()>=64){snapshot.detail="Spin: không cài được nhịp cuối";return 10;}
    const auto mapping=SilentAimMapping::Map(task,PlayerModesRemoteStart,PlayerModesRemoteEnd);
    if(!mapping.address){snapshot.detail=mapping.operation;return 10;}
    PlayerModesRemote::State state{};state.lateShared=shared;state.lateOriginal=original;
    if(!Write(mapping.address+MODES_PAGE,state)){
        mach_vm_deallocate(task,mapping.address,MODES_PAGE*2);return 10;
    }
    const uint64_t callback=mapping.address+MODES_LATE_ENTRY;
    bool bound=false;
#ifdef MIZZE_INJECTED
    bound=__atomic_compare_exchange_n((uint64_t *)slot,&current,callback,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST);
#else
    if(task_suspend(task)==KERN_SUCCESS){
        uint64_t live=0;bound=Read(slot,live)&&live==current&&Write(slot,callback);
        task_resume(task);
    }
#endif
    if(!bound){mach_vm_deallocate(task,mapping.address,MODES_PAGE*2);snapshot.detail="Spin: nhịp cuối đã thay đổi";return 10;}
    // Keep old mappings alive for callbacks already on a game thread's stack.
    // Each mapping keeps its own native original and immutable shared-state link.
    lateSessions.push_back({slot,mapping.address,original,shared});return 8;
}
void Sample(){
    const double now=CACurrentMediaTime();
    if(now-lastSample<0.2)return;
    lastSample=now;
    PlayerModesSnapshot next{};next.detail=snapshot.detail;next.failedOffset=snapshot.failedOffset;
    next.scoped=control.scoped;next.fakeLag=wanted&PlayerModesControl::FakeLag;
    next.height=height;next.skipped=snapshot.skipped;
    for(const auto &session:sessions){
        PlayerModesRemote::State state{};
        if(!Read(session.state(),state))continue;
        next.ticks+=state.ticks;next.applies+=state.applies;next.restores+=state.restores;
        next.postTicks+=state.postTicks;
        next.lateTicks+=state.lateTicks;next.spinApplies+=state.spinApplies;
        if(state.input.local==ownerLocal&&(state.input.flags&4u))next.spinStatus=state.spinStatus;
        for(const auto &row:state.rows){
            if(row.match!=ownerMatch||row.local!=ownerLocal||row.epoch!=epoch||!row.player)continue;
            if(row.mode==2&&(previousFlags&2u))++next.fly;
            if(row.mode==1&&(previousFlags&1u))++next.heldEnemies;
        }
    }
    if(next.ticks!=sampledTicks){sampledTicks=next.ticks;lastTickAt=now;}
    if(next.postTicks!=sampledPostTicks){sampledPostTicks=next.postTicks;lastPostAt=now;}
    next.running=lastTickAt>0&&now-lastTickAt<1.0;
    next.presenting=lastPostAt>0&&now-lastPostAt<1.0;
    if(!next.running)next.fly=0;
    if(!next.presenting)next.heldEnemies=0;
    snapshot=next;
}
uint64_t Deadline(){
    mach_timebase_info_data_t timebase{};
    return mach_timebase_info(&timebase)==KERN_SUCCESS&&timebase.numer&&timebase.denom?
        mach_absolute_time()+PlayerModesControl::LeaseNanoseconds*timebase.denom/timebase.numer:0;
}
}
void PlayerModesSetEnabled(bool fly,bool aimLag,bool fakeLag,float requestedHeight){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    const uint32_t next=(fly?PlayerModesControl::Fly:0u)|(aimLag?PlayerModesControl::AimLag:0u)|
        (fakeLag?PlayerModesControl::FakeLag:0u)|(wanted&PlayerModesControl::Spin);
    height=PlayerModesControl::Height(requestedHeight);
    if(next!=wanted){if(!next)Clear();wanted=next;retryAt=0;}
}
void PlayerModesSetSpin(bool enabled,float turnsPerSecond){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    spinSpeed=VisualSpin::Speed(turnsPerSecond);
    const uint32_t next=(wanted&~PlayerModesControl::Spin)|(enabled?PlayerModesControl::Spin:0u);
    if(next!=wanted){spinPhase.Reset();if(!next)Clear();wanted=next;retryAt=0;}
}
void PlayerModesCancel(){std::lock_guard<std::recursive_mutex> guard(mutex);Clear();}
int PlayerModesUpdate(uint64_t base){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    if(!wanted)return lastResult=1;
    if(!isVaildPtr(base)||!Attach(base)){Clear();return lastResult=10;}
    const uint64_t game=getMatchGame(base),match=getMatch(game),local=getLocalPlayer(match);
    uint8_t knocked=1;
    if(!isVaildPtr(match)||!isVaildPtr(local)||get_CurHP(local)<=0||!Read(local+kKnocked,knocked)||knocked){Clear();return lastResult=11;}
    if(CACurrentMediaTime()<retryAt)return lastResult;
    snapshot.detail="";snapshot.failedOffset=0;snapshot.skipped=0;
    if(!Verify()){Clear();retryAt=CACurrentMediaTime()+1;return lastResult=9;}
    PlayerModesRemote::Input input{};
    if(match!=ownerMatch||local!=ownerLocal){control.Reset();spinPhase.Reset();}
    input.flags=control.Flags(wanted,(wanted&PlayerModesControl::AimLag)&&get_IsScoping(local),CACurrentMediaTime());
    input.height=height;
    if(wanted&PlayerModesControl::Spin){
        spinPhase.Step(CACurrentMediaTime(),spinSpeed);
        input.spinSin=spinPhase.Sin();input.spinCos=spinPhase.Cos();
    }
    if(wanted&PlayerModesControl::Fly){
        PlayerModesController::Identity controller;
        if(PlayerModesController::Resolve(local,controller,ReadBytes,[](uint64_t a){return isVaildPtr(a);})){
            input.flyCCT=controller.object;input.flyClass=controller.klass;input.flyKind=controller.kind;
        }else snapshot.detail="Fly chưa có bộ điều khiển vị trí phù hợp";
    }
    input.match=match;input.local=local;input.deadline=Deadline();
    if(PlayerModesControl::NewEpoch(ownerMatch,ownerLocal,previousFlags,match,local,input.flags))++epoch;
    ownerMatch=match;ownerLocal=local;previousFlags=input.flags;
    input.epoch=epoch;
    std::array<uint64_t,MODES_CAPACITY+1> classes{};size_t classCount=0;
    auto addClass=[&](uint64_t player){
        uint64_t klass=0;if(!Read(player,klass)||!isVaildPtr(klass))return false;
        for(size_t i=0;i<classCount;++i)if(classes[i]==klass)return true;
        if(classCount==classes.size())return false;
        classes[classCount++]=klass;return true;
    };
    if((wanted&(PlayerModesControl::Fly|PlayerModesControl::Spin))&&!addClass(local)){Clear();return lastResult=9;}
    if(wanted&(PlayerModesControl::AimLag|PlayerModesControl::FakeLag)){
        uint64_t dictionary=0,entries=0;int count=-1,capacity=-1;
        if(!Read(match+kMatchPlayerDict,dictionary)||!Read(dictionary+kDictCount,count)||
            !Read(dictionary+kDictEntries,entries)||!Read(entries+kIl2CppArrayMaxLength,capacity)||
            capacity<=0||capacity>256||count<0||count>capacity){Clear();return lastResult=11;}
        std::array<uint8_t,256*kDictEntryStrideBytePlayer> bytes{};
        if(count&&!ReadBytes(entries+kIl2CppArrayItems,bytes.data(),count*kDictEntryStrideBytePlayer)){Clear();return lastResult=11;}
        for(int i=0;i<count&&input.count<MODES_CAPACITY;++i){
            const uint8_t *entry=bytes.data()+i*kDictEntryStrideBytePlayer;
            int32_t hash=-1;uint64_t player=0;std::memcpy(&hash,entry,4);std::memcpy(&player,entry+16,8);
            uint8_t knock=1;
            if(hash<0||!isVaildPtr(player)||player==local||get_CurHP(player)<=0||
                !Read(player+kKnocked,knock)||knock||isLocalTeamMate(local,player))continue;
            if(!addClass(player)){Clear();return lastResult=9;}
            input.players[input.count++]=player;
        }
    }
    std::array<bool,MODES_CAPACITY+1> installed{};
    uint64_t localClass=0;if(wanted&(PlayerModesControl::Fly|PlayerModesControl::Spin))Read(local,localClass);
    for(size_t i=0;i<classCount;++i){
        int result=Install(classes[i]);
        if(result==8){installed[i]=true;continue;}
        // One unsupported enemy must not disable the local Fly callback or
        // other supported enemies. Memory/permission failures still abort.
        if(result==9&&classes[i]!=localClass)continue;
        Clear();retryAt=CACurrentMediaTime()+1;return lastResult=result;
    }
    if(wanted&PlayerModesControl::Spin){
        Session *localSession=Find(localClass+Slot);
        const int result=localSession?InstallLate(game,localSession->state()):9;
        if(result!=8){Clear();retryAt=CACurrentMediaTime()+1;return lastResult=result;}
    }
    uint32_t accepted=0;
    for(uint32_t i=0;i<input.count;++i){
        uint64_t klass=0;Read(input.players[i],klass);bool supported=false;
        for(size_t j=0;j<classCount;++j)if(classes[j]==klass&&installed[j]){supported=true;break;}
        if(supported)input.players[accepted++]=input.players[i];else ++snapshot.skipped;
    }
    if(!(wanted&(PlayerModesControl::Fly|PlayerModesControl::Spin))&&input.count&&!accepted){Clear();retryAt=CACurrentMediaTime()+1;return lastResult=9;}
    input.count=accepted;
    if(!snapshot.skipped&&(!(wanted&PlayerModesControl::Fly)||input.flyCCT))snapshot.detail="";
    input.epoch=epoch; // Adoption may have advanced an existing callback's epoch.
    if(!input.deadline){Clear();return lastResult=10;}
    for(auto &session:sessions)if(!Publish(session,input)){Clear();return lastResult=10;}
    Sample();
    return lastResult=8;
}
PlayerModesSnapshot PlayerModesRead(){std::lock_guard<std::recursive_mutex> guard(mutex);return snapshot;}
#else
void PlayerModesSetEnabled(bool,bool,bool,float){}
void PlayerModesSetSpin(bool,float){}
void PlayerModesCancel(){}
int PlayerModesUpdate(uint64_t){return 9;}
PlayerModesSnapshot PlayerModesRead(){return {};}
#endif
