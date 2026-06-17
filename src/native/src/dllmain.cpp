#include "config.h"
#include "hooks.h"

#include <windows.h>

namespace {

DWORD WINAPI InitThread(LPVOID param) {
    const auto* path = static_cast<const wchar_t*>(param);
    ProxyConfig config{};
    LoadConfig(path, config);
    const auto packet = LoadPacketFile(path);
    if (!config.direct)
        InstallHooks(config, packet);
    return 0;
}

}  // namespace

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
        wchar_t path[MAX_PATH]{};
        GetModuleFileNameW(module, path, MAX_PATH);
        auto* copy = static_cast<wchar_t*>(HeapAlloc(GetProcessHeap(), 0, sizeof(path)));
        if (copy) {
            wcscpy_s(copy, MAX_PATH, path);
            HANDLE thread = CreateThread(nullptr, 0, InitThread, copy, 0, nullptr);
            if (thread) CloseHandle(thread);
        }
    } else if (reason == DLL_PROCESS_DETACH) {
        RemoveHooks();
    }
    return TRUE;
}
