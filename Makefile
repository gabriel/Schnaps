.PHONY: beta release plan-beta test

build/tools/schnaps-release: Sources/MeasurementCore/ReleaseChannel.swift Sources/MeasurementCore/ReleaseFeed.swift Scripts/Publish/main.swift
	@mkdir -p build/tools
	swiftc -swift-version 6 -parse-as-library Sources/MeasurementCore/ReleaseChannel.swift Sources/MeasurementCore/ReleaseFeed.swift Scripts/Publish/main.swift -o $@

beta: build/tools/schnaps-release
	@build/tools/schnaps-release beta $(ARGS)

release: build/tools/schnaps-release
	@build/tools/schnaps-release stable $(ARGS)

plan-beta: build/tools/schnaps-release
	@build/tools/schnaps-release beta --plan $(ARGS)

test:
	swift test
