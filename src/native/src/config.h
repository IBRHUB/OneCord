#pragma once

#include <string>
#include <vector>
#include <winsock2.h>

struct ProxyConfig {
    bool direct = true;
    bool http = false;
    bool socks5 = false;
    std::string host;
    uint16_t port = 0;
    std::string login;
    std::string password;
};

bool LoadConfig(const wchar_t* dllPath, ProxyConfig& out);
std::vector<uint8_t> LoadPacketFile(const wchar_t* dllPath);
