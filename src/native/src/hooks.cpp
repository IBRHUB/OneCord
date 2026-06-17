#include "hooks.h"

#include "socks5.h"

#include <MinHook.h>
#include <cstring>
#include <mutex>
#include <vector>

namespace {

ProxyConfig g_config;
std::vector<uint8_t> g_packet;
std::mutex g_lock;

using ConnectFn = int (WSAAPI*)(SOCKET, const sockaddr*, int);
using SendToFn = int (WSAAPI*)(SOCKET, const char*, int, int, const sockaddr*, int);

ConnectFn g_realConnect = nullptr;
SendToFn g_realSendTo = nullptr;

bool ProxyEnabled() {
    return !g_config.direct && g_config.socks5 && !g_config.host.empty() && g_config.port != 0;
}

int WSAAPI HookConnect(SOCKET s, const sockaddr* name, int namelen) {
    if (!ProxyEnabled() || !name) return g_realConnect(s, name, namelen);
    if (name->sa_family != AF_INET) return g_realConnect(s, name, namelen);
    return Socks5Connect(s, name, namelen, g_config.host, g_config.port, g_realConnect) ? 0 : SOCKET_ERROR;
}

int WSAAPI HookSendTo(SOCKET s, const char* buf, int len, int flags, const sockaddr* to, int tolen) {
    if (!g_packet.empty() && buf && len > 0) {
        std::vector<char> prefixed(g_packet.size() + static_cast<size_t>(len));
        std::memcpy(prefixed.data(), g_packet.data(), g_packet.size());
        std::memcpy(prefixed.data() + g_packet.size(), buf, len);
        return g_realSendTo(s, prefixed.data(), static_cast<int>(prefixed.size()), flags, to, tolen);
    }
    return g_realSendTo(s, buf, len, flags, to, tolen);
}

}  // namespace

bool InstallHooks(const ProxyConfig& config, const std::vector<uint8_t>& packet) {
    std::scoped_lock lock(g_lock);
    g_config = config;
    g_packet = packet;

    if (MH_Initialize() != MH_OK) return false;

    if (MH_CreateHookApi(L"ws2_32", "connect", &HookConnect, reinterpret_cast<LPVOID*>(&g_realConnect)) != MH_OK)
        return false;

    if (!g_packet.empty()) {
        if (MH_CreateHookApi(L"ws2_32", "sendto", &HookSendTo, reinterpret_cast<LPVOID*>(&g_realSendTo)) != MH_OK)
            return false;
    }

    return MH_EnableHook(MH_ALL_HOOKS) == MH_OK;
}

void RemoveHooks() {
    std::scoped_lock lock(g_lock);
    MH_DisableHook(MH_ALL_HOOKS);
    MH_Uninitialize();
}
