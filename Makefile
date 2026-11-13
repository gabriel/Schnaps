.PHONY: beta release promote plan-beta test dev check-release-source

build/tools/schnaps-release: Sources/MeasurementCore/ReleaseChannel.swift Sources/MeasurementCore/ReleaseFeed.swift Scripts/Publish/main.swift
	@mkdir -p build/tools
	swiftc -swift-version 6 -parse-as-library Sources/MeasurementCore/ReleaseChannel.swift Sources/MeasurementCore/ReleaseFeed.swift Scripts/Publish/main.swift -o $@

beta: check-release-source build/tools/schnaps-release
	@build/tools/schnaps-release beta $(ARGS)

release: check-release-source build/tools/schnaps-release
	@build/tools/schnaps-release stable $(ARGS)

promote: check-release-source build/tools/schnaps-release
	@build/tools/schnaps-release promote $(ARGS)

check-release-source:
	@sh Scripts/check-release-source.sh

plan-beta: build/tools/schnaps-release
	@build/tools/schnaps-release beta --plan $(ARGS)

test:
	swift test

dev:
	swift Scripts/build-app.swift --install-debug
	open /Applications/SchnapsDebug.app
