#include "socks5.h"

#include <cstring>
#include <ws2tcpip.h>

namespace {

bool SendAll(SOCKET s, const char* data, int len) {
    int sent = 0;
    while (sent < len) {
        const int n = send(s, data + sent, len - sent, 0);
        if (n <= 0) return false;
        sent += n;
    }
    return true;
}

bool RecvAll(SOCKET s, char* data, int len) {
    int got = 0;
    while (got < len) {
        const int n = recv(s, data + got, len - got, 0);
        if (n <= 0) return false;
        got += n;
    }
    return true;
}

}  // namespace

bool Socks5Connect(SOCKET s, const sockaddr* target, int targetLen,
                   const std::string& proxyHost, uint16_t proxyPort, ConnectFn realConnect) {
    if (!realConnect) return false;

    sockaddr_in proxy{};
    proxy.sin_family = AF_INET;
    proxy.sin_port = htons(proxyPort);
    inet_pton(AF_INET, proxyHost.c_str(), &proxy.sin_addr);

    if (realConnect(s, reinterpret_cast<const sockaddr*>(&proxy), sizeof(proxy)) != 0)
        return false;

    const char greeting[] = {0x05, 0x01, 0x00};
    if (!SendAll(s, greeting, 3)) return false;

    char method[2]{};
    if (!RecvAll(s, method, 2) || method[0] != 0x05 || method[1] != 0x00) return false;

    if (target->sa_family != AF_INET || targetLen < sizeof(sockaddr_in))
        return false;

    const auto* in = reinterpret_cast<const sockaddr_in*>(target);
    char req[10]{0x05, 0x01, 0x00, 0x01};
    std::memcpy(req + 4, &in->sin_addr, 4);
    std::memcpy(req + 8, &in->sin_port, 2);
    if (!SendAll(s, req, 10)) return false;

    char resp[10]{};
    if (!RecvAll(s, resp, 10) || resp[1] != 0x00) return false;
    return true;
}
