#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "optparse"

module KitchenMemory
  module ReleaseVersion
    VERSION_PATTERN = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/.freeze
    TAG_PATTERN = /\Arelease\/((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))\z/.freeze
    APP_TARGETS = ["KitchenMemory iOS", "KitchenMemory macOS"].freeze
    APP_CONFIGURATIONS = [
      "Debug",
      "Develop",
      "Testing",
      "Production",
      "ProductionTesting"
    ].freeze
    APP_CONFIGURATION_PATTERN = %r{
      ^[\t ]*[0-9A-F]+\s+/\*\s+([^\r\n]*?)\s+configuration\s+for\s+PBXNativeTarget\s+
      "(KitchenMemory\s+(?:iOS|macOS))"\s+\*/\s+=\s+\{\n
      (.*?)
      ^[\t ]*\};$
    }mx.freeze
    MARKETING_SETTING = /^\s*MARKETING_VERSION\s*=\s*"?([^";]+)"?;$/m.freeze
    BUILD_SETTING = /^\s*CURRENT_PROJECT_VERSION\s*=\s*"?([^";]+)"?;$/m.freeze

    class ContractError < StandardError; end

    module_function

    def source_values(project_contents)
      matches = project_contents.scan(APP_CONFIGURATION_PATTERN)
      configurations = matches.map(&:last)
      if configurations.empty?
        raise ContractError, "could not find Kitchen Memory application build configurations"
      end

      discovered_targets = matches.map { |match| match[1] }.uniq.sort
      unless discovered_targets == APP_TARGETS.sort
        raise ContractError, "both KitchenMemory iOS and KitchenMemory macOS must define versions"
      end

      APP_TARGETS.each do |target|
        names = matches.each_with_object([]) do |(name, matched_target, _body), result|
          result << name if matched_target == target
        end
        counts = names.each_with_object(Hash.new(0)) { |name, result| result[name] += 1 }
        missing = APP_CONFIGURATIONS.reject { |name| counts.key?(name) }
        unexpected = counts.keys.reject { |name| APP_CONFIGURATIONS.include?(name) }
        duplicates = counts.select { |_name, count| count > 1 }.keys
        next if missing.empty? && unexpected.empty? && duplicates.empty? && names.length == APP_CONFIGURATIONS.length

        details = []
        details << "missing: #{missing.join(', ')}" unless missing.empty?
        details << "unexpected: #{unexpected.join(', ')}" unless unexpected.empty?
        details << "duplicate: #{duplicates.join(', ')}" unless duplicates.empty?
        raise ContractError,
              "#{target} configurations must be exactly #{APP_CONFIGURATIONS.join(', ')} " \
              "(#{details.join('; ')})"
      end

      marketing_versions = configurations.map { |body| body[MARKETING_SETTING, 1] }
      build_numbers = configurations.map { |body| body[BUILD_SETTING, 1] }
      if marketing_versions.any?(&:nil?) || build_numbers.any?(&:nil?)
        raise ContractError, "every KitchenMemory application configuration must define both versions"
      end

      marketing_versions.uniq.then do |versions|
        unless versions.length == 1 && VERSION_PATTERN.match?(versions.first)
          raise ContractError,
                "KitchenMemory application configurations must share one numeric marketing version"
        end
      end
      unless build_numbers.uniq == ["1"]
        raise ContractError, "KitchenMemory source build number must remain 1 for Xcode Cloud"
      end

      [marketing_versions.first, build_numbers.first, configurations.length]
    end

    def validate(project_contents:, tag:, action:)
      if tag.to_s.empty?
        if action == "archive"
          raise ContractError, "Archive requires an immutable release/<major>.<minor>.<patch> tag"
        end

        return :not_a_release
      end

      match = TAG_PATTERN.match(tag)
      unless match
        raise ContractError,
              "release tag must use release/<major>.<minor>.<patch>; received #{tag.inspect}"
      end

      marketing_version, build_number, configuration_count = source_values(project_contents)
      unless marketing_version == match[1]
        raise ContractError,
              "release tag #{tag.inspect} does not match source marketing version " \
              "#{marketing_version.inspect}"
      end

      [marketing_version, build_number, configuration_count]
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  project_path = File.expand_path("../KitchenMemory.xcodeproj/project.pbxproj", __dir__)
  options = {
    tag: ENV["CI_TAG"],
    action: ENV["CI_XCODEBUILD_ACTION"],
    project_path: project_path
  }

  OptionParser.new do |arguments|
    arguments.banner = "Usage: check-release-version.rb [options]"
    arguments.on("--tag TAG", "Release tag; defaults to CI_TAG") { |tag| options[:tag] = tag }
    arguments.on("--action ACTION", "Xcode action; defaults to CI_XCODEBUILD_ACTION") do |action|
      options[:action] = action
    end
    arguments.on("--project PATH", "Path to project.pbxproj") { |path| options[:project_path] = path }
  end.parse!

  begin
    result = KitchenMemory::ReleaseVersion.validate(
      project_contents: File.read(options[:project_path]),
      tag: options[:tag],
      action: options[:action]
    )
    if result == :not_a_release
      puts "No release tag is associated with this action; release version check skipped."
    else
      version, build, configuration_count = result
      puts "Validated Kitchen Memory #{version} (source build #{build}) across " \
           "#{configuration_count} application configurations."
    end
  rescue KitchenMemory::ReleaseVersion::ContractError, Errno::ENOENT => error
    warn "Release version contract failed: #{error.message}"
    exit 1
  end
end
