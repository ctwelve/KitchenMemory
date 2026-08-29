#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "minitest/autorun"
require_relative "../check-release-version"

class CheckReleaseVersionTest < Minitest::Test
  CONFIGURATIONS = %w[Debug Develop Testing Production ProductionTesting].freeze

  def self.project(configurations = CONFIGURATIONS)
    identifier = 0

    configurations.map do |configuration|
      identifier += 1
      <<~CONFIGURATION
		#{format('%024X', identifier)} /* #{configuration} configuration for PBXNativeTarget "KitchenMemory" */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CURRENT_PROJECT_VERSION = 1;
				MARKETING_VERSION = 0.1.0;
			};
			name = #{configuration};
		};
      CONFIGURATION
    end.join
  end

  PBXPROJECT_CONFIGURATION = <<~CONFIGURATION.freeze
		FFFFFFFFFFFFFFFFFFFFFFFF /* Debug configuration for PBXProject "KitchenMemory" */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CURRENT_PROJECT_VERSION = 99;
				MARKETING_VERSION = 99.0.0;
			};
			name = Debug;
		};
  CONFIGURATION
  PROJECT = (PBXPROJECT_CONFIGURATION + project).freeze

  def test_matching_release_tag_passes
    version, build, configuration_count = KitchenMemory::ReleaseVersion.validate(
      project_contents: PROJECT,
      tag: "release/0.1.0",
      action: "archive"
    )

    assert_equal "0.1.0", version
    assert_equal "1", build
    assert_equal 5, configuration_count
  end

  def test_ignores_project_level_build_configurations
    version, build, configuration_count = KitchenMemory::ReleaseVersion.source_values(PROJECT)

    assert_equal "0.1.0", version
    assert_equal "1", build
    assert_equal 5, configuration_count
  end

  def test_missing_tag_skips_nonarchive_action
    result = KitchenMemory::ReleaseVersion.validate(
      project_contents: "not even an Xcode project",
      tag: nil,
      action: "build-for-testing"
    )

    assert_equal :not_a_release, result
  end

  def test_missing_tag_rejects_archive
    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: PROJECT,
        tag: nil,
        action: "archive"
      )
    end

    assert_includes error.message, "Archive requires"
  end

  def test_rejects_tag_that_does_not_match_source
    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: PROJECT,
        tag: "release/0.2.0",
        action: "archive"
      )
    end

    assert_includes error.message, "does not match"
  end

  def test_matching_release_marker_passes
    version, = KitchenMemory::ReleaseVersion.validate(
      project_contents: PROJECT,
      tag: "release/0.1.0",
      action: "archive",
      release_contents: "0.1.0\n"
    )

    assert_equal "0.1.0", version
  end

  def test_rejects_release_marker_that_does_not_match_tag
    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: PROJECT,
        tag: "release/0.1.0",
        action: "archive",
        release_contents: "0.0.9\n"
      )
    end

    assert_includes error.message, "root RELEASE marker"
  end

  def test_rejects_malformed_release_tag
    ["release-0.1.0", "release/0.1", "release/0.1.0-beta.1"].each do |tag|
      assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
        KitchenMemory::ReleaseVersion.validate(
          project_contents: PROJECT,
          tag: tag,
          action: "archive"
        )
      end
    end
  end

  def test_rejects_source_build_number_other_than_one
    project = PROJECT.sub("CURRENT_PROJECT_VERSION = 1;", "CURRENT_PROJECT_VERSION = 42;")
    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: project,
        tag: "release/0.1.0",
        action: "archive"
      )
    end

    assert_includes error.message, "must remain 1"
  end

  def test_rejects_inconsistent_application_versions
    project = PROJECT.sub("MARKETING_VERSION = 0.1.0;", "MARKETING_VERSION = 0.1.1;")
    assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: project,
        tag: "release/0.1.0",
        action: "archive"
      )
    end
  end

  def test_rejects_project_missing_application_target
    project = PROJECT.gsub("KitchenMemory", "NotKitchenMemory")

    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: project,
        tag: "release/0.1.0",
        action: "archive"
      )
    end

    assert_includes error.message, "could not find Kitchen Memory application build configurations"
  end

  def test_rejects_missing_application_configuration
    project = self.class.project(CONFIGURATIONS - ["Develop"])

    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: project,
        tag: "release/0.1.0",
        action: "archive"
      )
    end

    assert_includes error.message, "missing: Develop"
  end

  def test_rejects_duplicate_application_configuration
    project = self.class.project(CONFIGURATIONS + ["Debug"])

    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: project,
        tag: "release/0.1.0",
        action: "archive"
      )
    end

    assert_includes error.message, "duplicate: Debug"
  end

  def test_rejects_unexpected_application_configuration
    configurations = CONFIGURATIONS.map { |name| name == "Develop" ? "Beta" : name }
    project = self.class.project(configurations)

    error = assert_raises(KitchenMemory::ReleaseVersion::ContractError) do
      KitchenMemory::ReleaseVersion.validate(
        project_contents: project,
        tag: "release/0.1.0",
        action: "archive"
      )
    end

    assert_includes error.message, "unexpected: Beta"
  end
end
