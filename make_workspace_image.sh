#!/bin/bash

# make_workspace_image.sh
# By Michael Jordan <michael@glowingpixel.com>
# Given a Nexis workspace backup folder, create a sparseimagebundle and symlink in the Avid MediaFiles folder

# Check if at least one folder path is provided
if [ $# -eq 0 ]; then
	echo ""
	echo "Create sparseimagebundles, each containing a symlink to a given folder"
	echo "Useful for simulating Nexis workspaces, for example... ;) ;)"
	echo ""
	echo "Usage: $0 /path/to/folder1 [/path/to/folder2 ...]"
	echo ""
	exit 1
fi

# Loop through all provided folder paths
for FOLDER_PATH in "$@"; do
	# Check if the folder exists
	if [ ! -d "$FOLDER_PATH/Avid MediaFiles" ]; then
		echo ""
		echo "Folder $FOLDER_PATH does not contain an Avid MediaFiles folder. Skipping..." > /dev/stderr
		continue
	fi

	echo ""

	# Get absolute path of the folder
	FOLDER_PATH=$(cd "$FOLDER_PATH"; pwd)
	FOLDER_NAME=$(basename "$FOLDER_PATH")

	# Define the name for the sparse image bundle
	SPARSE_BUNDLE_PATH="$FOLDER_PATH/../${FOLDER_NAME}.sparsebundle"

	# Note: sparseimagebundles are directories, not files.  This was killing me.
	if [ -d "$SPARSE_BUNDLE_PATH" ]; then
		echo "Image already exists at $SPARSE_BUNDLE_PATH.  Skipping..." > /dev/stderr
		continue
	fi


	# Create a minimal sparse image bundle (32MB should be plenty for just a symlink)
	echo "Creating sparseimagebundle  at $SPARSE_BUNDLE_PATH..."
	hdiutil create -size 32m -fs APFS -type SPARSEBUNDLE -volname "$FOLDER_NAME" "$SPARSE_BUNDLE_PATH" > /dev/null

	if [ ! -d "$SPARSE_BUNDLE_PATH" ]; then
		echo "$SPARSE_BUNDLE_PATH was not created." > /dev/stderr
		continue
	fi

	# Mount the sparse image bundle and capture the mount path
	# TODO: Do this less `awk`wardly because ugh
	echo "Mounting $SPARSE_BUNDLE_PATH..."
	MOUNT_PATH=$(hdiutil attach "$SPARSE_BUNDLE_PATH" | grep Volumes | awk '{for(i=3;i<=NF;++i) printf $i " "; print ""}' | xargs)

	# Check if the mount was successful
	if [ -z "$MOUNT_PATH" ]; then
		echo "Failed to mount $SPARSE_BUNDLE_PATH. Skipping..." > /dev/stderr
		continue
	fi

	# Create a symlink in the mounted image to the original folder
	echo "Linking in $FOLDER_PATH/Avid MediaFiles to the disk image..."
	ln -s "$FOLDER_PATH/Avid MediaFiles" "$MOUNT_PATH/"

	if [ $? -eq 0 ]; then
		echo "Sparse image bundle was created successfully!"
	else
		echo "Oh dear, had some sort of trouble linking to $FOLDER_PATH"
	fi

	# Eject the sparse image bundle
	hdiutil detach "$MOUNT_PATH" > /dev/null

done