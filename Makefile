.PHONY: run build clean open

# Quick run: build and launch the app
run:
	@echo "Building and launching VisualInspiration..."
	@xcodebuild -project VisualInspiration.xcodeproj -scheme VisualInspiration -configuration Debug -derivedDataPath ./build build > /dev/null 2>&1 || (echo "Build failed!" && exit 1)
	@echo "Build succeeded! Launching app..."
	@open build/Build/Products/Debug/VisualInspiration.app

# Just build without launching
build:
	@echo "Building VisualInspiration..."
	@xcodebuild -project VisualInspiration.xcodeproj -scheme VisualInspiration -configuration Debug -derivedDataPath ./build build

# Open the app without rebuilding
open:
	@open build/Build/Products/Debug/VisualInspiration.app

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build
	@echo "Clean complete!"

# Open project in Xcode
xcode:
	@open VisualInspiration.xcodeproj
