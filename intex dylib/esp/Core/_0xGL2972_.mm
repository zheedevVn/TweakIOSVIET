#include "GameOffsets.h"
#import "GameLogic.h"
#include "AimSelection.h"
#include "GamePRI.h"
#include "WeaponFeatures.h"
#include "AvatarVisibility.h"
#include "RunSpeed.h"
#import "../drawing_view/offset.h"
#import <Foundation/Foundation.h>
#import <math.h>
#import "KabraxHide.h"

#include "KabraxHide.h"
#pragma mark - Function Game

static WeaponFeatures::Controller gWeaponFeatures;
static uint64_t gWeaponModuleBase = 0;
static RunSpeed::Controller gRunSpeed;
static_assert(kPlayerAttributes == WeaponFeatures::PlayerAttributesOffset, "PlayerAttributes layout");
static_assert(kShootNoReload == WeaponFeatures::ShootNoReloadOffset, "ShootNoReload layout");
static_assert(kFastFireOff == WeaponFeatures::FireIntervalScaleOffset, "FireIntervalScale layout");

static WeaponFeatures::Context CurrentWeaponContext() {
    if (!isVaildPtr(gWeaponModuleBase) || get_task == MACH_PORT_NULL) return {};
    const uint64_t match = getMatch(getMatchGame(gWeaponModuleBase));
    return {static_cast<uint64_t>(get_task), match, getLocalPlayer(match)};
}

static void RunWeaponFeatureUpdate(uint64_t moduleBase, bool noReload, bool fastFire, bool applyEnabled, bool ammoFree) {
    if (!gWeaponFeatures.HasChanges() && (!applyEnabled || (!noReload && !fastFire && !ammoFree))) return;
    gWeaponModuleBase = moduleBase;
    if(ammoFree) {
        // Match both single-byte accessors before activating this new field.
        uint32_t getter[2]={},setter[2]={};
        ammoFree=isVaildPtr(moduleBase)&&_read((long)(moduleBase+GameOffsets::Rva(0x6483C7C)),getter,sizeof(getter))&&
            _read((long)(moduleBase+GameOffsets::Rva(0x6483C84)),setter,sizeof(setter))&&
            getter[0]==GameOffsets::ExpectedWord(0x39465000)&&getter[1]==GameOffsets::ExpectedWord(0xD65F03C0)&&setter[0]==GameOffsets::ExpectedWord(0x39065001)&&setter[1]==GameOffsets::ExpectedWord(0xD65F03C0);
    }
    gWeaponFeatures.Update(CurrentWeaponContext(), noReload, fastFire,
        [](uint64_t address, void *buffer, size_t length) {
            return _read((long)address, buffer, static_cast<int>(length));
        },
        [](uint64_t address, const void *buffer, size_t length) {
            return _write((long)address, buffer, static_cast<int>(length));
        },
        [](uint64_t address) { return isVaildPtr(address); },
        [] { return CurrentWeaponContext(); }, applyEnabled, ammoFree);
}

void UpdateWeaponFeatures(uint64_t moduleBase, bool noReload, bool fastFire, bool ammoFree) {
    RunWeaponFeatureUpdate(moduleBase, noReload, fastFire, true, ammoFree);
}

void SyncWeaponFeatureSwitches(uint64_t moduleBase, bool noReload, bool fastFire, bool ammoFree) {
    // Apply OFF independently and immediately, even when ESP has no valid matrix.
    // Turning ON still waits for the normal validated in-match frame.
    RunWeaponFeatureUpdate(moduleBase, noReload, fastFire, false, ammoFree);
}

void ResetWeaponFeatures(void) {
    UpdateWeaponFeatures(gWeaponModuleBase, false, false);
    UpdateRunSpeed(gWeaponModuleBase,false,6);
}

void UpdateRunSpeed(uint64_t moduleBase,bool enabled,float metersPerSecond) {
    if(!enabled&&!gRunSpeed.Changed())return;
    gWeaponModuleBase=moduleBase;
    auto read=[](uint64_t a,void *p,size_t n){return _read((long)a,p,(int)n);};
    auto valid=[](uint64_t a){return isVaildPtr(a);};
    if(enabled) {
        uint32_t words[3]={};
        // GetSpeedByType: positive ForceRunAndDashSpeedValue at +0x3c8
        // overrides ordinary run/dash, without changing other movement modes.
        if(!read(moduleBase+GameOffsets::Rva(0x6482AA0),words,sizeof(words))||words[0]!=GameOffsets::ExpectedWord(0xBD43CA80)||
            words[1]!=GameOffsets::ExpectedWord(0x1E202008)||words[2]!=GameOffsets::ExpectedWord(0x5400036C))return;
    }
    gRunSpeed.Update(CurrentWeaponContext(),enabled,metersPerSecond,read,
        [](uint64_t a,const void *p,size_t n){return _write((long)a,p,(int)n);},valid,
        []{return CurrentWeaponContext();});
}

static uint64_t ReadMatchGameFromGameFacadeStatics(uint64_t GameFacade_Static) {
    if (!isVaildPtr(GameFacade_Static)) return 0;
    uint64_t matchGame = ReadAddr<uint64_t>(GameFacade_Static + (uint64_t)kCurrentMatchGame);
    if (isVaildPtr(matchGame)) return matchGame;
    return ReadAddr<uint64_t>(GameFacade_Static + (uint64_t)kCurrentGame);
}

uint64_t getMatchGame(uint64_t Moudule_Base) {
    if (!isVaildPtr((uintptr_t)Moudule_Base))
        return 0;

    uint64_t typeInfoAddr = Moudule_Base + (uint64_t)kGameFacadeTypeInfo;
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(typeInfoAddr);
    if (!isVaildPtr(GameFacade_TypeInfo)) return 0;
    const uintptr_t _0xFFFFAF = 0xB8; // Il2CppClass_1 size in supplied 1.132.1 il2cpp.h
    if (_0xFFFFAF == 0) return 0;


    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + _0xFFFFAF);


    return ReadMatchGameFromGameFacadeStatics(GameFacade_Static);
}

uint64_t getMatch(uint64_t matchgame) {
    if (!isVaildPtr((uintptr_t)matchgame)) return 0;
    return ReadAddr<uint64_t>(matchgame + kMatch);
}

uint64_t getLocalPlayer(uint64_t match) {
    if (!isVaildPtr((uintptr_t)match)) return 0;
    return ReadAddr<uint64_t>(match + kMatchLocalPlayer);
}

uint64_t CameraMain(uint64_t matchgame) {
    if (!isVaildPtr((uintptr_t)matchgame)) return 0;
    uint64_t CameraControllerManager = ReadAddr<uint64_t>(matchgame + kCameraControllerManager);
    if (!isVaildPtr((uintptr_t)CameraControllerManager)) return 0;
    return ReadAddr<uint64_t>(CameraControllerManager + kMainCamera);
}

static bool TipaReadMatrix16(uint64_t addr, float *out) {
    if (!_read((long)addr, out, 16 * sizeof(float))) return false;
    for (int i = 0; i < 16; ++i) if (!std::isfinite(out[i])) return false;
    return true;
}

static void TipaMultiply4x4(const float *P, const float *V, float *out) {
    for (int col = 0; col < 4; col++) {
        for (int row = 0; row < 4; row++) {
            float s = 0;
            for (int k = 0; k < 4; k++)
                s += P[k * 4 + row] * V[col * 4 + k];
            out[col * 4 + row] = s;
        }
    }
}

float* GetViewMatrix(uint64_t cameraMain) {
    static float matrix[16];
    if (!isVaildPtr((uintptr_t)cameraMain))
        return nullptr;
    uint64_t v1 = ReadAddr<uint64_t>(cameraMain + kCameraInner);
    if (!isVaildPtr((uintptr_t)v1))
        return nullptr;

    float V[16], P[16];
    if (!TipaReadMatrix16(v1 + kViewMatrixOff, V) ||
        !TipaReadMatrix16(v1 + kProjMatrixOff, P)) return nullptr;
    TipaMultiply4x4(P, V, matrix);
    return matrix;
}

bool IsAtLobby(uint64_t Moudule_Base) {

    if (!isVaildPtr((uintptr_t)Moudule_Base)) return true;

    uint64_t typeInfoAddr = Moudule_Base + (uint64_t)kGameFacadeTypeInfo;
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(typeInfoAddr);
    if (!isVaildPtr(GameFacade_TypeInfo))
        return true;

    const uintptr_t _0xFFFFAF = 0xB8; // Il2CppClass_1 size in supplied 1.132.1 il2cpp.h
    if (_0xFFFFAF == 0) return true;


    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + _0xFFFFAF);

   
    if (!isVaildPtr(GameFacade_Static))
        return true;
    uint64_t matchGame = ReadMatchGameFromGameFacadeStatics(GameFacade_Static);
    bool inLobby = !isVaildPtr(matchGame);

    return inLobby;
}

uint64_t getTransNode(uint64_t BodyPart) {
    if (!isVaildPtr((uintptr_t)BodyPart)) return 0;
    uint64_t node = ReadAddr<uint64_t>(BodyPart + kBodyPartTransNode);
    if (!isVaildPtr((uintptr_t)node)) return 0;
    return node;
}

static uint64_t getBoneTrans(uint64_t player, uintptr_t nodeOffset) {
    if (!isVaildPtr((uintptr_t)player)) return 0;
    uint64_t BodyPart = ReadAddr<uint64_t>(player + nodeOffset);
    if (!isVaildPtr((uintptr_t)BodyPart)) return 0;
    return getTransNode(BodyPart);
}

uint64_t getHead(uint64_t player) {
    return getBoneTrans(player, kHeadNode);
}

uint64_t getHip(uint64_t player) {
    return getBoneTrans(player, kHipNode);
}

uint64_t getRoot(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + OFF64(MIZZE_PLAYER_6C8));//protected ITransformNode MPJBGDJJJMJ; // 0x668


    return getTransNode(BodyPart);
}


static bool TryDataUInt16(uint64_t player, int index, uint16_t &value) {
    return GamePRI::TryUInt16(player, index,
        [](uint64_t address, void *buffer, size_t length) {
            return _read((long)address, buffer, static_cast<int>(length));
        },
        [](uint64_t address) { return isVaildPtr(address); }, value);
}
int get_FiringPRIState(uint64_t playerPawn) {
    uint16_t value = 0;
    return TryDataUInt16(playerPawn, GamePRI::FiringIndex, value) ? value : -1;
}
int get_FiringByte(uint64_t playerPawn) {
    const int state = get_FiringPRIState(playerPawn);
    return state < 0 ? -1 : (GamePRI::Firing(state) ? 1 : 0);
}
bool get_IsFiring(uint64_t playerPawn) {
    return GamePRI::Firing(get_FiringPRIState(playerPawn));
}



//bool get_IsScoping(uint64_t playerPawn) {
    
    //return ReadAddr<bool>(playerPawn + 0x7C0); // private bool PBJJMLOOLGH; // 0x7C0
//}

uint64_t getLeftAnkle(uint64_t player) {
    return getBoneTrans(player, kLeftAnkleNode);
}

uint64_t getRightAnkle(uint64_t player) {
    return getBoneTrans(player, kRightAnkleNode);
}

uint64_t getRightToeNode(uint64_t player) {
    return getBoneTrans(player, kRightToeNode);
}
uint64_t getLeftToeNode(uint64_t player) {
    return getBoneTrans(player, kLeftToeNode);
}
uint64_t getLeftShoulder(uint64_t player) {
    return getBoneTrans(player, kLeftShoulderNode);
}

uint64_t getLeftElbow(uint64_t player) {
    return getBoneTrans(player, kLeftElbowNode);
}

uint64_t getLeftHand(uint64_t player) {
    return getBoneTrans(player, kLeftHandNode);
}



uint64_t getRightShoulder(uint64_t player) {
    return getBoneTrans(player, kRightShoulderNode);
}

uint64_t getRightElbow(uint64_t player) {
    return getBoneTrans(player, kRightElbowNode);
}

uint64_t getRightHand(uint64_t player) {
    return getBoneTrans(player, kRightHandNode);
}

bool getIsVisible(uint64_t playerPawn) {
    if (!isVaildPtr(playerPawn)) return false;
    // Player +0xA50 (TH) / +0xA58 (MAX) is LevelSwingSpider, not visibility.
    // UmaAvatarSimple.SetVisible reads/writes +0x101 in both native images.
    // This is avatar presentation visibility, not a physics line-of-sight test.
    const auto read = [](uint64_t address, void *value, size_t size) {
        return _read((long)address, value, size);
    };
    const auto valid = [](uint64_t address) { return isVaildPtr(address); };
    return AvatarVisibility::IsVisible(playerPawn,read,valid);
}

bool getAimVisibility(uint64_t playerPawn) {
    // Use the existing visibility reader, including its supported fallback.
    // DynamicPVS was not verified as a required bit and could reject every
    // camera-visible target. Neither flag substitutes for a physics raycast.
    return getIsVisible(playerPawn);
}


bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player) {
    if (!isVaildPtr(localPlayer) || !isVaildPtr(Player)) return false;
    COW_GamePlay_PlayerID_o myPlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(localPlayer + kPlayerID);
    COW_GamePlay_PlayerID_o PlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(Player + kPlayerID);
    int myTeamID = myPlayerID.m_TeamID;
    int TeamID = PlayerID.m_TeamID;
    return myTeamID == TeamID;
}

int GetDataUInt16(uint64_t player, int varID) {
    uint16_t value = 0;
    return TryDataUInt16(player, varID, value) ? value : 0;
}

void SetDataUInt16(uint64_t player, int varID, uint16_t value) {
    if (!isVaildPtr(player) || varID < 0 || varID > 32) return;
    uint64_t IPRIDataPool = ReadAddr<uint64_t>(player + kDataPool);
    if (!isVaildPtr(IPRIDataPool)) return;
    uint64_t v2 = ReadAddr<uint64_t>(IPRIDataPool + kDataPoolInner);
    if (!isVaildPtr(v2)) return;
    uint64_t v4 = ReadAddr<uint64_t>(v2 + kDataPoolEntryStride * (uint64_t)varID + kDataPoolEntriesBase);
    if (!isVaildPtr(v4)) return;
    WriteAddr<uint16_t>(v4 + kDataPoolValue, value);
}

int get_CurHP(uint64_t Player) {
    return GetDataUInt16(Player, 0);
}

int get_MaxHP(uint64_t Player) {
    return GetDataUInt16(Player, 1);
}
