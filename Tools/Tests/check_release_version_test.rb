#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "minitest/autorun"
require_relative "../check-release-version"

class CheckReleaseVersionTest < Minitest::Test
  PROJECT = <<~PROJECT.freeze
		A1 /* Debug configuration for PBXNativeTarget "KitchenMemory" */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CURRENT_PROJECT_VERSION = 1;
				MARKETING_VERSION = 0.1.0;
			};
			name = Debug;
		};
		A2 /* Production configuration for PBXNativeTarget "KitchenMemory" */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CURRENT_PROJECT_VERSION = 1;
				MARKETING_VERSION = 0.1.0;
			};
			name = Production;
		};
  PROJECT

  def test_matching_release_tag_passes
    version, build, configuration_count = KitchenMemory::ReleaseVersion.validate(
      project_contents: PROJECT,
      tag: "release/0.1.0",
      action: "archive"
    )

    assert_equal "0.1.0", version
    assert_equal "1", build
    assert_equal 2, configuration_count
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
end
