pragma Singleton

import qs.basalt

// This machine's settings for Basalt's shell. Everything not set here keeps
// HostConfig.qml's default; see that file for the full list.
HostConfig {
  // The updates pill and window, from snout (https://github.com/frdrkand/snout).
  updatesStatus: ["snout", "has-updates", "--json"]
  updatesDetails: ["snout", "report", "--json"]
}
