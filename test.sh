#!/bin/bash
# Runs `swift test` with the extra search paths needed on a machine that only
# has Command Line Tools installed (no full Xcode.app). Without these flags,
# `swift test` fails to find the swift-testing runtime framework — see
# TRD.md §8.1 for what this suite covers.
set -euo pipefail

CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

swift test \
    -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
    -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
    "$@"
