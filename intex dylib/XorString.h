#ifndef XOR_STRING_H
#define XOR_STRING_H

#include "KabraxHide.h"
#include <string>
#include <array>
#include <cstddef>

namespace Security {
    // Tạo seed ngẫu nhiên dựa trên thời gian biên dịch (__TIME__)
    constexpr unsigned int GenerateSeed(const char* str, int index) {
        return (!str[index]) ? 0x12345678 : (GenerateSeed(str, index + 1) * 33) ^ str[index];
    }

    constexpr uint8_t CompileKey = static_cast<uint8_t>(GenerateSeed(__TIME__, 0) & 0xFF);

    template <std::size_t N>
    class XorStr {
    private:
        std::array<uint8_t, N> _encrypted;

    public:
        // Constructor thực hiện XOR hóa tại thời điểm biên dịch (Compile-time)
        constexpr XorStr(const char* str) : _encrypted{} {
            for (std::size_t i = 0; i < N; ++i) {
                _encrypted[i] = static_cast<uint8_t>(str[i]) ^ CompileKey;
            }
        }

        // Hàm giải mã chạy tại Runtime khi gọi chuỗi
        std::string decrypt() const {
            std::string decrypted;
            decrypted.reserve(N);
            for (std::size_t i = 0; i < N; ++i) {
                decrypted.push_back(static_cast<char>(_encrypted[i] ^ CompileKey));
            }
            return decrypted;
        }
    };
}

// Macro tiện ích để bọc chuỗi gọn gàng
#define SECURE_STR(str) []() { \
    constexpr Security::XorStr<sizeof(str) - 1> encrypted(str); \
    return encrypted.decrypt(); \
}()

#endif // XOR_STRING_H
