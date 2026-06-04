#!/bin/bash

set -e

echo "=================================="
echo "DownloadManager 项目生成脚本"
echo "=================================="

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

cd "$PROJECT_DIR"

echo ""
echo "1. 检查 xcodegen 是否安装..."
if ! command -v xcodegen &> /dev/null; then
    echo "   xcodegen 未安装，正在安装..."
    brew install xcodegen
    if [ $? -ne 0 ]; then
        echo "   安装失败，请手动安装 xcodegen: brew install xcodegen"
        exit 1
    fi
else
    echo "   xcodegen 已安装"
fi

echo ""
echo "2. 清理旧项目文件..."
if [ -d "DownloadManager.xcodeproj" ]; then
    echo "   删除旧的 DownloadManager.xcodeproj..."
    rm -rf DownloadManager.xcodeproj
fi

echo ""
echo "3. 执行 xcodegen generate..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo "   项目生成成功"
else
    echo "   项目生成失败"
    exit 1
fi

echo ""
echo "4. 执行 pod install..."
pod install

if [ $? -eq 0 ]; then
    echo "   Pod 安装成功"
else
    echo "   Pod 安装失败"
    exit 1
fi

echo ""
echo "=================================="
echo "项目生成完成！"
echo "项目路径: $PROJECT_DIR/DownloadManager.xcodeproj"
echo "=================================="