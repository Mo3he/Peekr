#!/bin/sh
set -e

# Install XcodeGen via Homebrew (Homebrew is available on Xcode Cloud agents)
brew install xcodegen

# Generate HSM.xcodeproj from project.yml
xcodegen generate --spec "$CI_PRIMARY_REPOSITORY_PATH/project.yml" --project "$CI_PRIMARY_REPOSITORY_PATH"
