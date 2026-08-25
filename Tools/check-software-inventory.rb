#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "json"
require_relative "check-release-version"

module KitchenMemory
  module SoftwareInventory
    RESOLVED_IDENTITY_REFERENCE = "resolved-package-identity"
    APP_PACKAGE_ID = "SPDXRef-Package-KitchenMemory"

    class ContractError < StandardError; end

    module_function

    def validate(resolved_contents:, sbom_contents:, project_contents:)
      resolved = JSON.parse(resolved_contents)
      sbom = JSON.parse(sbom_contents)
      assert_equal("SPDX version", sbom["spdxVersion"], "SPDX-2.3")
      assert_equal("SBOM data license", sbom["dataLicense"], "CC0-1.0")

      packages = sbom.fetch("packages")
      packages_by_id = packages.to_h { |package| [package.fetch("SPDXID"), package] }
      unless packages_by_id.length == packages.length
        raise ContractError, "SBOM package SPDX identifiers must be unique"
      end

      marketing_version, = ReleaseVersion.source_values(project_contents)
      app = packages_by_id.fetch(APP_PACKAGE_ID)
      assert_equal("Kitchen Memory SBOM version", app["versionInfo"], marketing_version)
      assert_equal("Kitchen Memory declared license", app["licenseDeclared"], "GPL-3.0-only")

      resolved_packages = packages.each_with_object([]) do |package, result|
        identity = resolved_identity(package)
        result << [identity, package] if identity
      end
      inventory_by_identity = resolved_packages.to_h
      if inventory_by_identity.length != resolved_packages.length
        raise ContractError, "resolved package identities must be unique in the SBOM"
      end

      pins = resolved.fetch("pins")
      pins_by_identity = pins.to_h { |pin| [pin.fetch("identity"), pin] }
      assert_exact_set(
        "resolved package identities",
        inventory_by_identity.keys,
        pins_by_identity.keys
      )

      pins_by_identity.each do |identity, pin|
        package = inventory_by_identity.fetch(identity)
        state = pin.fetch("state")
        assert_equal("#{identity} version", package["versionInfo"], state.fetch("version"))
        assert_equal("#{identity} source", package["downloadLocation"], pin.fetch("location"))
        checksum = package.fetch("checksums").find { |entry| entry["algorithm"] == "SHA1" }
        raise ContractError, "#{identity} must record its resolved revision as SHA1" unless checksum

        assert_equal("#{identity} revision", checksum["checksumValue"], state.fetch("revision"))
        if [nil, "", "NOASSERTION"].include?(package["licenseDeclared"])
          raise ContractError, "#{identity} must record a reviewed declared license"
        end
      end

      {
        package_count: packages.length,
        resolved_package_count: pins.length,
        marketing_version: marketing_version
      }
    rescue JSON::ParserError, KeyError => error
      raise ContractError, error.message
    end

    def resolved_identity(package)
      reference = package.fetch("externalRefs", []).find do |entry|
        entry["referenceType"] == RESOLVED_IDENTITY_REFERENCE
      end
      reference&.fetch("referenceLocator")
    end

    def assert_equal(label, actual, expected)
      return if actual == expected

      raise ContractError, "#{label} must be #{expected.inspect}; found #{actual.inspect}"
    end

    def assert_exact_set(label, actual, expected)
      return if actual.sort == expected.sort

      missing = expected - actual
      unexpected = actual - expected
      details = []
      details << "missing: #{missing.join(', ')}" unless missing.empty?
      details << "unexpected: #{unexpected.join(', ')}" unless unexpected.empty?
      raise ContractError, "#{label} differ (#{details.join('; ')})"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  root = File.expand_path("..", __dir__)
  resolved_path = File.join(
    root,
    "KitchenMemory.xcodeproj",
    "project.xcworkspace",
    "xcshareddata",
    "swiftpm",
    "Package.resolved"
  )

  begin
    result = KitchenMemory::SoftwareInventory.validate(
      resolved_contents: File.read(resolved_path),
      sbom_contents: File.read(File.join(root, "SBOM.spdx.json")),
      project_contents: File.read(File.join(root, "KitchenMemory.xcodeproj", "project.pbxproj"))
    )
    puts "Validated Kitchen Memory #{result[:marketing_version]} software inventory: " \
         "#{result[:package_count]} components, " \
         "#{result[:resolved_package_count]} resolved packages."
  rescue KitchenMemory::SoftwareInventory::ContractError, Errno::ENOENT => error
    warn "Software inventory contract failed: #{error.message}"
    exit 1
  end
end
