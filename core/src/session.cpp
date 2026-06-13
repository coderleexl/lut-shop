#include "lutshop/session.hpp"

#include <algorithm>

namespace lutshop {
namespace {

bool emptyName(const std::string& value) {
  return value.empty();
}

bool sessionExists(const std::vector<Session>& sessions,
                   const std::string& sessionId) {
  return std::any_of(sessions.begin(), sessions.end(), [&](const Session& session) {
    return session.id == sessionId;
  });
}

bool sessionNameExists(const std::vector<Session>& sessions,
                       const std::string& name,
                       const std::string& excludingId = "") {
  return std::any_of(sessions.begin(), sessions.end(), [&](const Session& session) {
    return session.name == name && session.id != excludingId;
  });
}

bool containsId(const std::vector<std::string>& ids, const std::string& id) {
  return std::find(ids.begin(), ids.end(), id) != ids.end();
}

}  // namespace

OperationResult createSession(std::vector<Session>& sessions,
                              const std::string& sessionId,
                              const std::string& name) {
  if (sessionId.empty() || emptyName(name)) {
    return {false, "session id and name are required"};
  }
  if (sessionExists(sessions, sessionId) || sessionNameExists(sessions, name)) {
    return {false, "session already exists"};
  }

  sessions.push_back({sessionId, name, ""});
  return {true, ""};
}

OperationResult renameSession(std::vector<Session>& sessions,
                              const std::string& sessionId,
                              const std::string& name) {
  if (emptyName(name)) {
    return {false, "session name is required"};
  }
  if (sessionNameExists(sessions, name, sessionId)) {
    return {false, "session name already exists"};
  }

  for (auto& session : sessions) {
    if (session.id == sessionId) {
      session.name = name;
      return {true, ""};
    }
  }
  return {false, "session not found"};
}

OperationResult deleteEmptySession(std::vector<Session>& sessions,
                                   const std::vector<Photo>& photos,
                                   const std::string& sessionId) {
  if (countPhotosInSession(photos, sessionId) > 0) {
    return {false, "session is not empty"};
  }

  const auto before = sessions.size();
  sessions.erase(std::remove_if(sessions.begin(), sessions.end(), [&](const Session& session) {
                   return session.id == sessionId;
                 }),
                 sessions.end());
  return {sessions.size() != before, sessions.size() != before ? "" : "session not found"};
}

std::size_t countPhotosInSession(const std::vector<Photo>& photos,
                                 const std::string& sessionId) {
  return static_cast<std::size_t>(
      std::count_if(photos.begin(), photos.end(), [&](const Photo& photo) {
        return photo.sessionId == sessionId;
      }));
}

void assignPhotosToSession(std::vector<Photo>& photos,
                           const std::vector<std::string>& photoIds,
                           const std::string& sessionId,
                           const std::string& sessionName) {
  for (auto& photo : photos) {
    if (containsId(photoIds, photo.id)) {
      photo.sessionId = sessionId;
      photo.sessionName = sessionName;
    }
  }
}

}  // namespace lutshop
