## 2024-11-20 - [Test Script Overwrote Source of Truth]
**Learning:** I accidentally overwrote `pkg-files/pacman-pkgs.txt` with mock data because I didn't use a temporary directory for my test script's artifacts.
**Action:** Always use `mktemp -d` or a clearly distinct build directory for test outputs to prevent corrupting the actual codebase.
