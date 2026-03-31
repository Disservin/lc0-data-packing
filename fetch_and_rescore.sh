#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

BASE_URL="https://storage.lczero.org/files/training_data/test91/"
DATA_DIR="./data"
BINPACK_DIR="./binpacks"
SYZYGY_PATH=$1
RESCORER_BIN="./lc0/build/release/rescorer"

if [ -z "$SYZYGY_PATH" ]; then
    echo "Usage: $0 <SYZYGY_PATH>"
    exit 1
fi

# Create necessary directories
mkdir -p "$DATA_DIR"
mkdir -p "$BINPACK_DIR"

echo "Fetching list of tarballs from $BASE_URL..."
# Fetch the directory index and parse out the .tar links
TARBALLS=$(curl -s "$BASE_URL" | grep -oE 'href="[^"]+\.tar"' | sed -E 's/href="([^"]+)"/\1/')

if [ -z "$TARBALLS" ]; then
    echo "No tarballs found at $BASE_URL"
    exit 1
fi

for TARBALL in $TARBALLS; do
    echo "============================================="
    echo "Processing $TARBALL..."
    
    NAME="${TARBALL%.tar}"
    TAR_PATH="${DATA_DIR}/${TARBALL}"
    EXTRACT_PATH="${DATA_DIR}/${NAME}"
    
    # Check if the binpack already exists to allow resuming
    if [ -f "${BINPACK_DIR}/${NAME}.binpack" ]; then
        echo "Binpack ${NAME}.binpack already exists, skipping..."
        continue
    fi
    
    echo "Downloading ${TARBALL}..."
    wget -c "${BASE_URL}${TARBALL}" -O "$TAR_PATH"
    
    echo "Extracting ${TARBALL}..."
    tar -xf "$TAR_PATH" -C "$DATA_DIR"
    
    echo "Running rescorer..."
    "$RESCORER_BIN" rescore \
        --syzygy-paths="$SYZYGY_PATH" \
        --input="$EXTRACT_PATH" \
        --binpack-file="${BINPACK_DIR}/${NAME}.binpack" \
        --nnue-best-score=true \
        --nnue-best-move=true \
        --deblunder=true \
        --deblunder-q-blunder-threshold=0.10 \
        --deblunder-q-blunder-width=0.03 \
        --threads=5 \
        --delete-files
        
    echo "Cleaning up..."
    rm -f "$TAR_PATH"
    rm -rf "$EXTRACT_PATH"
    
    echo "Finished processing $TARBALL"
done

echo "All done!"
