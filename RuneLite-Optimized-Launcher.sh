#!/bin/bash

# Launch RuneLite from the JAR with optimized JVM flags
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 java \
  --add-opens java.desktop/javax.swing=ALL-UNNAMED \
  -Xms512m \
  -Xmx2048m \
  -XX:+UseZGC \
  -XX:+ZGenerational \
  -XX:MaxGCPauseMillis=5 \
  -XX:+AlwaysPreTouch \
  -Dsun.java2d.opengl=true \
  -Dsun.java2d.xrender=true \
  -Dsun.java2d.uiScale=1 \
  -Dprism.verbose=false \
  -jar /home/sid/Applications/RuneLite.jar

