#!/bin/bash
set -e

# This script takes a full JRE and repacks it to include only the
# components necessary for running a headless Minecraft server.

TARGET_VERSION=$1
SOURCE_JRE_PATH=$2
DEST_JRE_PATH=$3

echo "Repacking JRE for Java $TARGET_VERSION..."
echo "Source: $SOURCE_JRE_PATH"
echo "Destination: $DEST_JRE_PATH"

if [ -d "$DEST_JRE_PATH" ]; then
    rm -rf "$DEST_JRE_PATH"
fi

if [ "$TARGET_VERSION" == "8" ]; then
    # For Java 8, we copy the whole JRE and then remove unneeded parts.
    echo "Using delete-list strategy for Java 8..."
    cp -r "$SOURCE_JRE_PATH" "$DEST_JRE_PATH"

    # Remove documentation, headers, and debug symbols
    rm -rf "$DEST_JRE_PATH/man" \
           "$DEST_JRE_PATH/include" \
           "$DEST_JRE_PATH/lib/missioncontrol" \
           "$DEST_JRE_PATH/lib/visualvm"

    # Remove source code zip
    find "$DEST_JRE_PATH" -name "src.zip" -delete

    echo "Java 8 JRE repacked."

elif [ "$TARGET_VERSION" -ge 17 ]; then
    # For modern Java, we use jlink to build a new, minimal JRE.
    echo "Using jlink strategy for Java $TARGET_VERSION..."

    # Define the modules a Minecraft server needs. This includes 'java.desktop'
    # because many servers and plugins still use AWT classes for image processing,
    # which works in headless mode.
    MODULES_TO_INCLUDE="java.base,java.logging,java.sql,java.naming,java.desktop,jdk.unsupported"

    # Find the jlink executable from the Boot JDK we used to build everything
    JLINK_EXEC="$JAVA_HOME/bin/jlink"

    "$JLINK_EXEC" \
        --module-path "$SOURCE_JRE_PATH/jmods" \
        --add-modules "$MODULES_TO_INCLUDE" \
        --output "$DEST_JRE_PATH" \
        --strip-debug \
        --no-man-pages \
        --no-header-files \
        --compress=2

    echo "Java $TARGET_VERSION JRE repacked with jlink."
fi

echo "Repacking complete."
