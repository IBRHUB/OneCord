#pragma once

#include <winsock2.h>
#include <string>

using ConnectFn = int (WSAAPI*)(SOCKET, const sockaddr*, int);

bool Socks5Connect(SOCKET s, const sockaddr* target, int targetLen,
                   const std::string& proxyHost, uint16_t proxyPort, ConnectFn realConnect);
