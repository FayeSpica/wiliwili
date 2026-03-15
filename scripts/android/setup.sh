#!/bin/bash
# Setup script for wiliwili Android TV build
# This script creates necessary symlinks and prepares the build environment.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BOREALIS_DIR="$PROJECT_ROOT/library/borealis"
ANDROID_DIR="$SCRIPT_DIR"
JNI_DIR="$ANDROID_DIR/app/jni"

echo "=== wiliwili Android TV Build Setup ==="
echo "Project root: $PROJECT_ROOT"
echo "Borealis dir: $BOREALIS_DIR"

# Check submodules
if [ ! -f "$BOREALIS_DIR/CMakeLists.txt" ]; then
    echo "Initializing submodules..."
    git -C "$PROJECT_ROOT" submodule update --init --recursive
fi

# Create symlinks in jni directory
echo "Creating symlinks..."

# SDL (from borealis)
if [ ! -e "$JNI_DIR/SDL" ]; then
    ln -sf "$BOREALIS_DIR/library/lib/extern/SDL" "$JNI_DIR/SDL"
    echo "  Linked SDL"
fi

# borealis library
if [ ! -e "$JNI_DIR/borealis" ]; then
    ln -sf "$BOREALIS_DIR/library" "$JNI_DIR/borealis"
    echo "  Linked borealis"
fi

# Copy Java source files from borealis android-project
BOREALIS_JAVA_SRC="$BOREALIS_DIR/android-project/app/src/main/java/org"
TARGET_JAVA_SRC="$ANDROID_DIR/app/src/main/java/org"

if [ ! -d "$TARGET_JAVA_SRC" ]; then
    echo "Copying SDL/borealis Java sources..."
    cp -r "$BOREALIS_JAVA_SRC" "$TARGET_JAVA_SRC"
    echo "  Copied Java sources"
fi

# Build libromfs-generator
if [ ! -f "$JNI_DIR/borealis/libromfs-generator" ]; then
    echo ""
    echo "Building libromfs-generator..."
    LIBROMFS_PATH="$BOREALIS_DIR/library/lib/extern/libromfs/generator"
    BUILD_DIR="$BOREALIS_DIR/build_libromfs_generator"
    cmake -B "$BUILD_DIR" "$LIBROMFS_PATH"
    cmake --build "$BUILD_DIR"
    cp "$BUILD_DIR/libromfs-generator" "$BOREALIS_DIR/library/libromfs-generator"
    rm -rf "$BUILD_DIR"
    echo "  Built libromfs-generator"
fi

# Copy gradlew from borealis
if [ ! -f "$ANDROID_DIR/gradlew" ]; then
    cp "$BOREALIS_DIR/android-project/gradlew" "$ANDROID_DIR/gradlew"
    chmod +x "$ANDROID_DIR/gradlew"
    echo "  Copied gradlew"
fi
if [ ! -f "$ANDROID_DIR/gradlew.bat" ]; then
    cp "$BOREALIS_DIR/android-project/gradlew.bat" "$ANDROID_DIR/gradlew.bat"
    echo "  Copied gradlew.bat"
fi
if [ ! -f "$ANDROID_DIR/gradle/wrapper/gradle-wrapper.jar" ]; then
    cp "$BOREALIS_DIR/android-project/gradle/wrapper/gradle-wrapper.jar" "$ANDROID_DIR/gradle/wrapper/"
    echo "  Copied gradle-wrapper.jar"
fi

# Create local.properties
if [ ! -f "$ANDROID_DIR/local.properties" ]; then
    if [ -n "$ANDROID_SDK_ROOT" ]; then
        echo "sdk.dir=$ANDROID_SDK_ROOT" > "$ANDROID_DIR/local.properties"
    elif [ -d "$HOME/Library/Android/sdk" ]; then
        echo "sdk.dir=$HOME/Library/Android/sdk" > "$ANDROID_DIR/local.properties"
    elif [ -d "$HOME/Android/Sdk" ]; then
        echo "sdk.dir=$HOME/Android/Sdk" > "$ANDROID_DIR/local.properties"
    fi
    echo "  Created local.properties"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "To build:"
echo "  cd $ANDROID_DIR"
echo "  export JAVA_HOME=/Applications/Android\\ Studio.app/Contents/jbr/Contents/Home"
echo "  ./gradlew assembleDebug"
echo ""
echo "To install on device:"
echo "  adb install app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "NOTE: Currently using mpv stub. For production, replace with real libmpv."
