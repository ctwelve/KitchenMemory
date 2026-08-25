#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "minitest/autorun"
require_relative "../check-software-inventory"

class CheckSoftwareInventoryTest < Minitest::Test
  PROJECT = begin
    configurations = %w[Debug Develop Testing Production ProductionTesting]
    identifier = 0
    %w[KitchenMemoryIOS KitchenMemoryMacOS].flat_map do |target|
      configurations.map do |configuration|
        identifier += 1
        <<~CONFIGURATION
		#{format('%024X', identifier)} /* #{configuration} configuration for PBXNativeTarget "#{target}" */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CURRENT_PROJECT_VERSION = 1;
				MARKETING_VERSION = 0.1.1;
			};
			name = #{configuration};
		};
        CONFIGURATION
      end
    end.join
  end

  RESOLVED = JSON.generate(
    "pins" => [
      {
        "identity" => "defaults",
        "location" => "https://github.com/sindresorhus/Defaults",
        "state" => {
          "revision" => "00a7465a0668a87fa159e779b9d80f1f9652357e",
          "version" => "9.0.9"
        }
      }
    ]
  )

  def sbom(
    version: "0.1.1",
    dependency_version: "9.0.9",
    revision: "00a7465a0668a87fa159e779b9d80f1f9652357e"
  )
    JSON.generate(
      "spdxVersion" => "SPDX-2.3",
      "dataLicense" => "CC0-1.0",
      "packages" => [
        {
          "name" => "Kitchen Memory",
          "SPDXID" => "SPDXRef-Package-KitchenMemory",
          "versionInfo" => version,
          "licenseDeclared" => "GPL-3.0-only"
        },
        {
          "name" => "Defaults",
          "SPDXID" => "SPDXRef-Package-Defaults",
          "versionInfo" => dependency_version,
          "downloadLocation" => "https://github.com/sindresorhus/Defaults",
          "licenseDeclared" => "MIT",
          "checksums" => [{ "algorithm" => "SHA1", "checksumValue" => revision }],
          "externalRefs" => [
            {
              "referenceType" => "resolved-package-identity",
              "referenceLocator" => "defaults"
            }
          ]
        }
      ]
    )
  end

  def validate(contents = sbom, resolved: RESOLVED)
    KitchenMemory::SoftwareInventory.validate(
      resolved_contents: resolved,
      sbom_contents: contents,
      project_contents: PROJECT
    )
  end

  def test_matching_inventory_passes
    result = validate

    assert_equal 2, result[:package_count]
    assert_equal 1, result[:resolved_package_count]
    assert_equal "0.1.1", result[:marketing_version]
  end

  def test_rejects_stale_application_version
    error = assert_raises(KitchenMemory::SoftwareInventory::ContractError) do
      validate(sbom(version: "0.1.0"))
    end

    assert_includes error.message, "SBOM version"
  end

  def test_rejects_stale_dependency_version
    assert_raises(KitchenMemory::SoftwareInventory::ContractError) do
      validate(sbom(dependency_version: "9.0.8"))
    end
  end

  def test_rejects_stale_revision
    assert_raises(KitchenMemory::SoftwareInventory::ContractError) do
      validate(sbom(revision: "1111111111111111111111111111111111111111"))
    end
  end

  def test_rejects_missing_resolved_package
    resolved = JSON.generate(
      "pins" => JSON.parse(RESOLVED).fetch("pins") + [
        {
          "identity" => "another-package",
          "location" => "https://example.invalid/another-package",
          "state" => {
            "revision" => "2222222222222222222222222222222222222222",
            "version" => "1.0.0"
          }
        }
      ]
    )

    error = assert_raises(KitchenMemory::SoftwareInventory::ContractError) do
      validate(sbom, resolved: resolved)
    end

    assert_includes error.message, "missing: another-package"
  end
end
