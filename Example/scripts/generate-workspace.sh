#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p PyxisExample.xcworkspace
cat > PyxisExample.xcworkspace/contents.xcworkspacedata <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
   <FileRef location="group:PyxisExample.xcodeproj"/>
   <FileRef location="group:."/>
</Workspace>
XML
