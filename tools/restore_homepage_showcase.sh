#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cat tools/homepage_showcase_b64_0.txt tools/homepage_showcase_b64_1.txt tools/homepage_showcase_b64_2.txt | base64 -d > lib/Homepage.dart
wc -c lib/Homepage.dart
head -5 lib/Homepage.dart
