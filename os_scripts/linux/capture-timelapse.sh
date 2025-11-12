#!/bin/bash

# Configuration
DEVICE="/dev/video0"  # Change if your webcam is on a different device
OUTPUT_DIR="/mnt/webcam_captures"
COPY_DIR="/mnt/bag_movies/mp4"
RESOLUTION="1920x1080"  # Adjust to your preferred resolution
INTERVAL=10  # Seconds between captures
SKIP_FRAMES=20  # Number of frames to skip to let camera adjust
WARMUP_DELAY=2  # Additional seconds to let camera stabilize

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Starting webcam capture..."
echo "Saving images to: $OUTPUT_DIR"
echo "Camera device: $DEVICE"
echo "Press Ctrl+C to stop"
echo ""

# Configure camera settings for better exposure
echo "Configuring camera settings..."
#v4l2-ctl -d "$DEVICE" --set-ctrl=gain=128 2>/dev/null  # Increase gain (was 16, max 255)
#v4l2-ctl -d "$DEVICE" --set-ctrl=brightness=180 2>/dev/null  # Increase brightness (was 135, max 255)
#v4l2-ctl -d "$DEVICE" --set-ctrl=backlight_compensation=100 2>/dev/null  # Help with LCD brightness
v4l2-ctl -d "$DEVICE" --set-ctrl=auto_exposure=3 2>/dev/null  # Keep aperture priority mode
echo "Camera configured"
echo ""

# Test if device exists
if [ ! -e "$DEVICE" ]; then
    echo "Error: Camera device $DEVICE not found!"
    echo "Available video devices:"
    ls -la /dev/video* 2>/dev/null
    exit 1
fi

# Capture loop
FIRST_CAPTURE=true
while true; do
    # On first capture, give camera extra time to initialize
    if [ "$FIRST_CAPTURE" = true ]; then
        echo "Initializing camera (waiting ${WARMUP_DELAY}s)..."
        sleep "$WARMUP_DELAY"
        FIRST_CAPTURE=false
    fi
    
    # Generate filename with timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    FILENAME="$OUTPUT_DIR/capture_$TIMESTAMP.jpg"
    
    # Capture image with frame skipping to allow camera adjustment
    # -S skips frames to let the camera warm up and adjust exposure
    # --set can adjust brightness/contrast if needed
    fswebcam -r "$RESOLUTION" -d "$DEVICE" -S "$SKIP_FRAMES" \
             --set brightness=60% --set contrast=50% \
             --no-banner "$FILENAME"

    cp "$FILENAME" "$COPY_DIR"/current.jpg

    if [ $? -eq 0 ]; then
        # Check file size to detect black/corrupt images
        FILESIZE=$(stat -f%z "$FILENAME" 2>/dev/null || stat -c%s "$FILENAME" 2>/dev/null)
        if [ "$FILESIZE" -lt 5000 ]; then
            echo "Warning: $FILENAME seems too small ($FILESIZE bytes) - possibly black image"
        else
            echo "✓ Captured: $FILENAME ($FILESIZE bytes)"
        fi
    else
        echo "✗ Error capturing image at $(date)"
    fi
    
    # Wait for the specified interval
    sleep "$INTERVAL"
done

