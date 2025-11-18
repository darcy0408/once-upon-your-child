#!/bin/bash
# Post-build script to optimize Flutter web build size

echo "Optimizing Flutter web build..."

# Remove CanvasKit to reduce bundle size (uses HTML renderer)
if [ -d "build/web/canvaskit" ]; then
    echo "Removing CanvasKit to reduce bundle size..."
    rm -rf build/web/canvaskit
fi

# Compress assets if available
if command -v gzip &> /dev/null; then
    echo "Compressing assets..."
    find build/web -name "*.js" -exec gzip -9 -k {} \;
    find build/web -name "*.css" -exec gzip -9 -k {} \;
fi

# Show final size
echo "Final build size:"
du -sh build/web/