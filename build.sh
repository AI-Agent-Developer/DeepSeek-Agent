#!/bin/bash

# 清理旧的构建文件
flutter clean

# 构建 macOS 通用二进制文件
flutter build macos --release --no-tree-shake-icons

# 输出目录
OUTPUT_DIR="build/release"
mkdir -p "$OUTPUT_DIR"

# 复制构建的应用到输出目录
cp -r "build/macos/Build/Products/Release/AI智能体.app" "$OUTPUT_DIR/"

echo "构建完成！应用程序位于: $OUTPUT_DIR/AI智能体.app"
