#pragma once

#include <string>
#include <vector>

#include "lutshop/types.hpp"

namespace lutshop {

OperationResult createSession(std::vector<Session>& sessions,
                              const std::string& sessionId,
                              const std::string& name);

OperationResult renameSession(std::vector<Session>& sessions,
                              const std::string& sessionId,
                              const std::string& name);

OperationResult deleteEmptySession(std::vector<Session>& sessions,
                                   const std::vector<Photo>& photos,
                                   const std::string& sessionId);

std::size_t countPhotosInSession(const std::vector<Photo>& photos,
                                 const std::string& sessionId);

void assignPhotosToSession(std::vector<Photo>& photos,
                           const std::vector<std::string>& photoIds,
                           const std::string& sessionId,
                           const std::string& sessionName);

}  // namespace lutshop
