#pragma once

#include "config.h"

bool InstallHooks(const ProxyConfig& config, const std::vector<uint8_t>& packet);
void RemoveHooks();
