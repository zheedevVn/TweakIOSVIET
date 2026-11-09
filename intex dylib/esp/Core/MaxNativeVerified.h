#pragma once
#include <cstdint>
// Static native evidence from com.dts.freefiremax 2.132.1, build 2019118522.
// Generated from profiles/ffmax-native-2.132.1.json; never reuse for another OB.
// Device behavior, permissions and native Unity object storage remain untested.
namespace MaxNative {
constexpr uint64_t Rva(uint64_t th) {
    switch (th) {
        case 0xBB46A50: return 0xBE93418; // GameFacade TypeInfo
        case 0xBB4BEC8: return 0xBE988C0; // Tracer TypeInfo
        case 0xA11121C: return 0xA383BC0; // Metadata initialization helper
        case 0x569C434: return 0x57342C4; // Player.PostUpdate instruction block
        case 0x5BA4054: return 0x5C3EDEC; // Weapon firing instruction block
        case 0x5C1E910: return 0x5CA2B2C; // Shot presentation instruction block
        case 0x6482AA0: return 0x6523F98; // GetSpeedByType instruction block
        default: return 0;
    }
}
constexpr uint32_t ExpectedHash(uint32_t th) {
    switch (th) {
        case 0x3D459FF7: return 0x8CCEE244;
        case 0x41E95E11: return 0xC0E04626;
        case 0x2A0C22A4: return 0x4BEC34DB;
        case 0x4365F46B: return 0x28CF3DC9;
        case 0xFE362A57: return 0x2C0655B0;
        case 0xAC5E66DE: return 0x16B7C7FC;
        case 0x96FDD838: return 0x5EE61A;
        case 0x37041440: return 0x89131F8;
        case 0x6A9FF040: return 0x211287C;
        case 0x27399A41: return 0x2342F238;
        case 0x740125D4: return 0xC8DDDC99;
        case 0x597102DC: return 0xA2AE913B;
        case 0xC5E012EE: return 0x968DCEBA;
        case 0x9AD8096C: return 0x71BBEDF8;
        case 0xA2F105A1: return 0xFCDCF075;
        case 0x88A4BD15: return 0x6A22AC11;
        case 0x131E1130: return 0xCFD1BA6A;
        case 0xA165FA4A: return 0x2D65AEF;
        case 0x572D5404: return 0x572D5404;
        case 0x1EE7E697: return 0x1EA536FD;
        case 0x6D340948: return 0x1C5E5898;
        case 0x2FC932FA: return 0xEDC18B3A;
        case 0xC285FA0E: return 0xC83AA2EF;
        case 0x76159E8D: return 0x79A799D4;
        case 0xF0BC2099: return 0x651BCBD5;
        case 0x8B3DCDAE: return 0xDE3CC186;
        case 0x8956580B: return 0xBBC77180;
        case 0xF884A08C: return 0xA951F77;
        case 0xE5B7D25C: return 0xA56FB7B2;
        case 0xDECACF20: return 0xAF81CB1A;
        case 0x8E831156: return 0xDBC230B1;
        case 0x8C40F08F: return 0x2D0B602;
        case 0xE305068: return 0xE332ADF8;
        case 0x7DDB7C94: return 0xEB690E84;
        case 0x4696BE26: return 0x4BD9A4AF;
        case 0xBBFE1A71: return 0x9E092CAA;
        case 0xAACE9654: return 0xED1B1464;
        case 0x92F2568B: return 0x80A17C6C;
        case 0x4478C55F: return 0xEADDA386;
        case 0x6E4B75FE: return 0x5B0ADC87;
        case 0xABF31A13: return 0x771AE92D;
        case 0xCA3873F8: return 0x9080E6F1;
        case 0xCD88029D: return 0x274D285D;
        case 0x19271E41: return 0x545F8E5D;
        case 0x57B0CB1B: return 0xCDB2E5C3;
        case 0x7958F6CC: return 0xC7C9759F;
        case 0xB469C925: return 0x6574B232;
        case 0xA3152FF4: return 0xFE93C4A4;
        case 0x6CDFBEA8: return 0x6F7812BC;
        case 0xBA38C9C8: return 0x483AC837;
        case 0x20A90AAF: return 0xA4D1B649;
        case 0x66DA289B: return 0x7542C513;
        case 0xD89C4708: return 0x4CD686E8;
        case 0x8307E566: return 0xF9416A0F;
        case 0x9918D15: return 0xFC908D7A;
        case 0x4C79AF54: return 0xB4EE03F5;
        case 0x7C4BDB69: return 0x91DF7A16;
        case 0xE5A62294: return 0x314054BA;
        case 0x5C6FFC2C: return 0x4FDD07DE;
        case 0x64A6725A: return 0x64A6725A;
        case 0x458F369A: return 0x96BA1D71;
        case 0x7C5E5F3F: return 0xF9B4A157;
        case 0xEBC9879D: return 0x94FB7ADA;
        case 0xE7908BBE: return 0x9E12B68;
        case 0xAE8A72F8: return 0x312CA02F;
        case 0xD1FEABDC: return 0x3D641842;
        case 0x990FC153: return 0x4612AD9F;
        case 0x80D43BE2: return 0x80D43BE2;
        case 0x3D4AF30F: return 0x97F47664;
        case 0xDB814CED: return 0x6B46E593;
        case 0x61044F36: return 0xCE293820;
        case 0x178B2DA7: return 0xA0AEDAED;
        case 0x54800249: return 0x45058237;
        case 0x3655F88D: return 0xB6F04E37;
        case 0x43B62F71: return 0xC8E226CE;
        case 0xD78D78BD: return 0x9ED75DD6;
        case 0x154D9667: return 0x3F3160BA;
        case 0x6881CEE5: return 0x89D6F767;
        case 0x54F82A6C: return 0xD93A9D22;
        case 0x1F24198: return 0x65BF6D3F;
        case 0xFB5E72CE: return 0x141B9A5E;
        case 0x3010A312: return 0x86DED2EC;
        case 0x2EFCAE4E: return 0x99E757E1;
        case 0x482878B5: return 0xE61E0885;
        case 0x19ABE41A: return 0x49612762;
        case 0xCDA7586C: return 0x826AB838;
        case 0xDFE8FAC6: return 0xB2F4EBFB;
        case 0x93FD3984: return 0xC2892A33;
        case 0x40924917: return 0xD087CDD9;
        case 0x538C5B13: return 0xA9A1A3E0;
        default: return 0;
    }
}
constexpr uint32_t ExpectedWord(uint32_t th) {
    switch (th) {
        case 0x39465000: return 0x39465000;
        case 0xD65F03C0: return 0xD65F03C0;
        case 0x39065001: return 0x39065001;
        case 0xBD43CA80: return 0xBD43CA80;
        case 0x1E202008: return 0x1E202008;
        case 0x5400036C: return 0x5400036C;
        default: return 0;
    }
}
}
