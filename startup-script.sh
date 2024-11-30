#!/bin/bash

# The goal of this script is to do the following:
# 1. Read the path of the main application from an env var. (For example /src/out/myapp.dll)
# 2. Read the path of the mount path from an env var.(for example /volume/)
# 3. If the application **file** exists under the volume folder (ex: /volume/src/out/myapp.dll)
# then start the application from that path.
# 4. If the mount path exists and empty, copy the application folder into the mount path (copy /src/out/ to /volume/src/out) and run the application from there
# 5. if the mount path doesn't exist, or if the app file not found there but it's not empty, we just start the application from the regular place.

# The goal here is to mirror the currently running application folder the a volume that would reflect the changes we make to the outside world.
# The other goal is that changes we make in the outer world can be quickly reflected into the pod/container. So if on the outside we make changes to the code and then
# recompile, we then can just restart our pod and the pod will run with our new changes.

# I think this script doesn't exactly work as I expect it to. It seems it doesn't load the app from the mount if it exists.
# I should rewrite this script in python. Python is more robust,readable and powerful.

echo "Startup Script for Kubernetes Pod Starting..."

# Load environment variables provided by the deployment
APPLICATION_PATH="${APPLICATION_PATH}"  # Full path to the app inside the pod, e.g., /src/out/myapp/main.dll
MOUNT_PATH_BASE="${MOUNT_PATH_BASE}"    # Mount directory (volume) on the host, e.g., /output/

# Determine the directory containing the application and root of the application source
APPLICATION_DIR="$(dirname "$APPLICATION_PATH")"
APPLICATION_BASE_DIR="/$(echo "$APPLICATION_PATH" | cut -d'/' -f2)"  # First level directory from APPLICATION_PATH

echo "Provided Variables:"
echo "  Application Path: $APPLICATION_PATH"
echo "  Application Directory: $APPLICATION_DIR"
echo "  Mount Directory (Base): $MOUNT_PATH_BASE"

# Ensure the application path is valid
if [ ! -f "$APPLICATION_PATH" ]; then
  echo "ERROR: The application path '$APPLICATION_PATH' does not exist in the pod. Exiting..."
  exit 1
fi

# Validate if the MOUNT_PATH_BASE exists as a directory
if [ -d "$MOUNT_PATH_BASE" ]; then
  echo "Mount directory '$MOUNT_PATH_BASE' exists. Checking its contents..."

  # If the mount directory is empty
  if [ -z "$(ls -A "$MOUNT_PATH_BASE")" ]; then
    echo "Mount directory is empty. Copying application files from '$APPLICATION_BASE_DIR' to '$MOUNT_PATH_BASE'..."
    rsync -a "$APPLICATION_BASE_DIR/" "$MOUNT_PATH_BASE/$APPLICATION_BASE_DIR/"
    echo "Copy complete. Launching application from the mount directory."
    cd "$(dirname "$MOUNT_PATH_BASE$APPLICATION_PATH")" || exit
    exec dotnet "$MOUNT_PATH_BASE$APPLICATION_PATH"

  # If the application file already exists in the mount directory
  elif [ -f "$MOUNT_PATH_BASE/$APPLICATION_PATH" ]; then
    echo "Application already exists in the mount directory ('$MOUNT_PATH_BASE/$APPLICATION_PATH'). Launching from there..."
    cd "$(dirname "$MOUNT_PATH_BASE$APPLICATION_PATH")" || exit
    exec dotnet "$MOUNT_PATH_BASE$APPLICATION_PATH"

  # If the mount directory is not empty but does not contain the application
  else
    echo "Mount directory is not empty but does not contain the application. Running application from its regular location in the pod."
    cd "$APPLICATION_DIR" || exit
    exec dotnet "$APPLICATION_PATH"
  fi

# If the mount directory does not exist
else
  echo "Mount directory '$MOUNT_PATH_BASE' does not exist. Running application from its regular location in the pod."
  cd "$APPLICATION_DIR" || exit
  exec dotnet "$APPLICATION_PATH"
fi
