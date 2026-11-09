#ifndef GameLogic_h
#define GameLogic_h
#include "KabraxHide.h"

#import "pid.h"
#import "UnityMath.h"

#pragma mark - Function Game

uint64_t getMatchGame(uint64_t Moudule_Base);
uint64_t getMatch(uint64_t matchgame);
uint64_t CameraMain(uint64_t matchgame);

float* GetViewMatrix(uint64_t cameraMain);
bool IsAtLobby(uint64_t Moudule_Base);
uint64_t getTransNode(uint64_t BodyPart);
bool get_IsFiring(uint64_t playerPawn);
int get_FiringByte(uint64_t playerPawn);
// Raw UInt16 PRI state, or -1 when the pointer chain/read is unavailable.
int get_FiringPRIState(uint64_t playerPawn);
bool get_IsScoping(uint64_t playerPawn);
uint64_t getHead(uint64_t player);
uint64_t getHip(uint64_t player);
uint64_t getRoot(uint64_t player);
uint64_t getLeftAnkle(uint64_t player);
uint64_t getRightAnkle(uint64_t player);
uint64_t getRightToeNode(uint64_t player);
uint64_t getLeftToeNode(uint64_t player);
uint64_t getLeftShoulder(uint64_t player);
uint64_t getRightShoulder(uint64_t player);
uint64_t getLeftElbow(uint64_t player);
uint64_t getRightElbow(uint64_t player);
uint64_t getLeftHand(uint64_t player);
uint64_t getRightHand(uint64_t player);
uint64_t getLocalPlayer(uint64_t match);
bool getIsVisible(uint64_t playerPawn);
bool getAimVisibility(uint64_t playerPawn);
int GetDataUInt16(uint64_t player, int varID);
void SetDataUInt16(uint64_t player, int varID, uint16_t value);
int get_CurHP(uint64_t Player);
int get_MaxHP(uint64_t Player);
bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player);
void UpdateWeaponFeatures(uint64_t moduleBase, bool noReload, bool fastFire, bool ammoFree=false);
void SyncWeaponFeatureSwitches(uint64_t moduleBase, bool noReload, bool fastFire, bool ammoFree=false);
void ResetWeaponFeatures(void);
void UpdateRunSpeed(uint64_t moduleBase,bool enabled,float metersPerSecond);

#endif
