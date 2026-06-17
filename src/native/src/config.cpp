#include "config.h"

#include <fstream>
#include <regex>
#include <sstream>

namespace {

std::wstring DirName(const wchar_t* path) {
    std::wstring p(path);
    const auto pos = p.find_last_of(L"\\/");
    return pos == std::wstring::npos ? L"" : p.substr(0, pos + 1);
}

std::wstring ReadIni(const std::wstring& dir) {
    const std::wstring paths[] = {dir + L"onecord.ini", dir + L"drover.ini"};
    for (const auto& ini : paths) {
        std::wifstream in(ini);
        if (!in) continue;
        std::wstringstream ss;
        ss << in.rdbuf();
        return ss.str();
    }
    return {};
}

}  // namespace

bool LoadConfig(const wchar_t* dllPath, ProxyConfig& out) {
    out = {};
    try {
        const auto text = ReadIni(DirName(dllPath));
        if (text.empty()) return false;

        std::wregex re(LR"((?is)\[(?:onecord|drover)\].*?^\s*proxy\s*=\s*(.+?)\s*$)");
        std::wsmatch match;
        if (!std::regex_search(text, match, re)) return false;

        const std::wstring proxy = match[1].str();
        if (proxy.empty()) {
            out.direct = true;
            return true;
        }

        std::wregex url(LR"(^(?i)([a-z\d]+)://(?:(.+):(.+)@)?([^:]+):(\d+)\s*$)");
        if (!std::regex_match(proxy, match, url)) return false;

        const std::wstring proto = match[1].str();
        out.direct = false;
        out.http = (proto == L"http" || proto == L"https");
        out.socks5 = (proto == L"socks5");

        auto narrow = [](const std::wstring& ws) {
            std::string s(ws.begin(), ws.end());
            return s;
        };

        out.login = narrow(match[2].str());
        out.password = narrow(match[3].str());
        out.host = narrow(match[4].str());
        out.port = static_cast<uint16_t>(std::stoi(match[5].str()));
        return out.http || out.socks5;
    } catch (...) {
        out = {};
        return false;
    }
}

std::vector<uint8_t> LoadPacketFile(const wchar_t* dllPath) {
    const auto dir = DirName(dllPath);
    const std::wstring names[] = {dir + L"drover-packet.bin", dir + L"onecord-packet.bin"};
    for (const auto& path : names) {
        std::ifstream in(path, std::ios::binary);
        if (!in) continue;
        return std::vector<uint8_t>((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    }
    return {};
}
