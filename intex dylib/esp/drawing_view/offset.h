#include "KabraxHide.h"
#pragma once
#include "../Core/GameOffsets.h"

#define kGameFacadeTypeInfo      OFF64(GameOffsets::Rva(0xBB46A50))
#define kCurrentGame             OFF64(0x0)
#define kCurrentMatchGame        OFF64(0x8)
#define kMatch                   OFF64(0x90)
#define kMatchLocalPlayer        OFF64(0xD8)
#define kCameraControllerManager OFF64(0xD8)

#define kMainCamera              OFF64(0x20)
#define kCameraInner            OFF64(0x10)

#define kViewMatrixOff          OFF64(0x80)
#define kProjMatrixOff          OFF64(0xC0)
#define kBodyPartTransNode       OFF64(0x10)
#define kHeadNode               OFF64(MIZZE_PLAYER_6A0)//
#define kHipNode                OFF64(MIZZE_PLAYER_6A8)
#define kLeftAnkleNode           OFF64(MIZZE_PLAYER_6D8)
#define kRightAnkleNode          OFF64(MIZZE_PLAYER_6E0)
#define kRightToeNode            OFF64(MIZZE_PLAYER_6F0)
#define kLeftToeNode             OFF64(MIZZE_PLAYER_6F8)
#define kLeftShoulderNode        OFF64(MIZZE_PLAYER_6C0)
#define kRightShoulderNode       OFF64(MIZZE_PLAYER_6C8)
#define kLeftHandNode            OFF64(MIZZE_PLAYER_720)
#define kRightHandNode           OFF64(MIZZE_PLAYER_718)
#define kLeftElbowNode           OFF64(MIZZE_PLAYER_730)
#define kRightElbowNode          OFF64(MIZZE_PLAYER_728)
#define kPlayerIDStruct         OFF64(MIZZE_PLAYER_2D0)
#define kPlayerID               OFF64(MIZZE_PLAYER_408)
#define kUserID                 OFF64(MIZZE_PLAYER_408)
#define kIsClientBot            OFF64(MIZZE_PLAYER_4A0)
#define kDataPool               0x70
#define kDataPoolInner          0x10
#define kDataPoolEntriesBase    0x20
#define kDataPoolEntryStride    0x8
#define kDataPoolValue          0x18
#define kAimRotation            OFF64(MIZZE_PLAYER_614)
#define kAimRotationAux         OFF64(MIZZE_PLAYER_628)
#define kAvatarManager          OFF64(MIZZE_PLAYER_770)

#define kVisibleObj             MIZZE_PLAYER_A50
#define kVisibleObjFlags        0x10
#define kISVisibleCamera        0x1
#define kISVisibleDynamicPVS    0x100000
#define kISVisibleFPPMask       0xFFFBFFFF

#define _0x27276BC kAvatarManager

#define _0x28726BD OFF64(0x138)// internal IUmaAvatar m_Avatar; // 0x118 internal IUmaAvatar EEAGBKBMBLD; // 0x128

#define _0x2872DCF OFF64(0x101)// private bool IsVisible; // 0x101


#define kMainCameraTransform    OFF64(MIZZE_PLAYER_3E8)
#define kMyPhysXData            OFF64(MIZZE_PLAYER_1D48)
#define kPhxNpeononogeo         OFF64(0x20)
#define kGhgState               OFF64(0x10)
#define kKnocked                 OFF64(MIZZE_PLAYER_1258)
#define kMatchPlayerDict        0x148
#define kDictEntries            0x18
#define kDictCount              0x20
#define kIl2CppArrayMaxLength   0x18
#define kIl2CppArrayItems       0x20
#define kDictEntryStrideBytePlayer   24
#define kDictEntryValueOffByte       16
#define kTransformInner         0x10
#define kTransformMatrix        0x38
#define kTransformIndex         0x40
#define kMatrixList             0x18
#define kMatrixIndices          0x20
#define kNickname               MIZZE_PLAYER_490
#define kStringFirstChar        0x14


// Legacy aliases only; active weapon reads use SilentAimWeapon::OnHand.
// +0x690 is FollowCamera, and +0x7B9 has no verified ammo meaning.
#define kWeaponOnHand           MIZZE_PLAYER_690
#define kWeaponCostAmmo         0x7B9
#define kPlayerAttributes       MIZZE_PLAYER_768
#define kShootNoReload          0x111
#define kFastFireOff            0x258 // PlayerAttributes.FireIntervalScale (float)


