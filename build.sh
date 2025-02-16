#!/bin/bash

# 构建web
flutter build web --release --base-href "/ai/deepseek/"

# 构建macos
if [ "$(uname)" == "Darwin" ]; then
    flutter build macos --release
fi

# 构建ios
# flutter build ios --release

# 构建android
flutter build apk --release

# 构建linux
# flutter build linux --release

#如果当前是 windows 系统，则构建windows
if [ "$(uname)" == "Windows" ]; then
    flutter build windows --release
fi
