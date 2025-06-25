#!/bin/bash
#
# docker-build.sh - Docker build helper for versioned image tagging
#
# This script builds a Docker image with a version tag that includes a base version and an auto-incremented build number.
# 
# Usage:
# - When executed, the user is prompted to enter a base version (e.g., 1.0.2a).
#   - If a version is entered, the image will be tagged as apps:<version>-1 (e.g., apps:1.0.2a-1).
#   - If left blank, the script reads the current version from the 'apps:snapshot' image,
#     increments the build number, and uses that as the new tag.
#
# The final image is tagged with:
# - apps:<base-version>-<build-no> (e.g., apps:1.0.2a-4)
# - apps:snapshot (always points to the latest build)
#
# The version tag is also saved as a Docker image label: version_tag=<tag>


IMAGE_NAME="docker.picosoft.com.my/ibtws"
SNAPSHOT_TAG="${IMAGE_NAME}:snapshot"

read -p "Enter base version (e.g., 1.0.2a) or press Enter to auto-detect from snapshot: " BASE

if [[ -n "$BASE" ]]; then
  # User entered a base version
  NEXT_NO=1
else
  # Auto-detect from snapshot image
  echo "Checking version from snapshot..."
  docker pull ${SNAPSHOT_TAG} > /dev/null 2>&1
  VERSION_TAG=$(docker inspect ${SNAPSHOT_TAG} --format='{{ index .Config.Labels "version_tag" }}' 2>/dev/null)

  if [[ -z "$VERSION_TAG" ]]; then
    echo "No version_tag found in snapshot. Please enter a version manually."
    exit 1
  fi

  BASE=$(echo "$VERSION_TAG" | cut -d'-' -f1)
  LAST_NO=$(echo "$VERSION_TAG" | cut -d'-' -f2)
  NEXT_NO=$((LAST_NO + 1))
fi

NEW_TAG="${BASE}-${NEXT_NO}"
echo "Building image: ${IMAGE_NAME}:${NEW_TAG}"

docker build \
  --build-arg VERSION_TAG=${NEW_TAG} \
  --label version_tag=${NEW_TAG} \
  -t ${IMAGE_NAME}:${NEW_TAG} .

# Tag image also as snapshot
docker tag ${IMAGE_NAME}:${NEW_TAG} ${SNAPSHOT_TAG}

echo "Build complete:"
echo "   - ${IMAGE_NAME}:${NEW_TAG}"
echo "   - ${IMAGE_NAME}:snapshot"
