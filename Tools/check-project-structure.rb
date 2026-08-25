#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "json"
require "optparse"
require "rexml/document"
require "rexml/xpath"

module KitchenMemory
  module ProjectStructure
    APP_CONFIGURATIONS = %w[
      Debug
      Develop
      Testing
      Production
      ProductionTesting
    ].freeze
    TARGET_TYPES = {
      "KitchenMemory iOS" => "com.apple.product-type.application",
      "KitchenMemory macOS" => "com.apple.product-type.application",
      "KitchenMemoryIOSTests" => "com.apple.product-type.bundle.unit-test",
      "KitchenMemoryMacTests" => "com.apple.product-type.bundle.unit-test",
      "KitchenMemoryUITests" => "com.apple.product-type.bundle.ui-testing",
      "KitchenMemoryDomain" => "com.apple.product-type.framework",
      "KitchenMemoryImport" => "com.apple.product-type.framework",
      "KitchenMemoryLogic" => "com.apple.product-type.framework",
      "KitchenMemoryPersistence" => "com.apple.product-type.framework"
    }.freeze
    TARGET_PLATFORMS = {
      "KitchenMemory iOS" => %w[iphoneos iphonesimulator],
      "KitchenMemory macOS" => %w[macosx],
      "KitchenMemoryIOSTests" => %w[iphoneos iphonesimulator],
      "KitchenMemoryMacTests" => %w[macosx],
      "KitchenMemoryUITests" => %w[iphoneos iphonesimulator macosx],
      "KitchenMemoryDomain" => %w[iphoneos iphonesimulator macosx],
      "KitchenMemoryImport" => %w[iphoneos iphonesimulator macosx],
      "KitchenMemoryLogic" => %w[iphoneos iphonesimulator macosx],
      "KitchenMemoryPersistence" => %w[iphoneos iphonesimulator macosx]
    }.freeze
    IOS_COMPATIBILITY_EXCLUSIONS = {
      "SUPPORTS_MACCATALYST" => "NO",
      "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD" => "NO",
      "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD" => "NO"
    }.freeze
    UI_TEST_HOSTS = {
      "TEST_TARGET_NAME[sdk=iphoneos*]" => "KitchenMemory iOS",
      "TEST_TARGET_NAME[sdk=iphonesimulator*]" => "KitchenMemory iOS",
      "TEST_TARGET_NAME[sdk=macosx*]" => "KitchenMemory macOS"
    }.freeze
    PROJECT_CONFIGURATION_FILES = APP_CONFIGURATIONS.to_h do |configuration|
      [configuration, "#{configuration}.xcconfig"]
    end.freeze
    APP_FILE_CONTRACTS = {
      "KitchenMemory iOS" => {
        info_plist: "KitchenMemoryIOS/Info.plist",
        entitlement_keys: [
          "CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]",
          "CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]"
        ],
        production_entitlements: "KitchenMemoryIOS/KitchenMemory.entitlements",
        testing_entitlements: "KitchenMemoryIOS/KitchenMemory-Testing.entitlements"
      },
      "KitchenMemory macOS" => {
        info_plist: "KitchenMemoryMac/Info.plist",
        entitlement_keys: ["CODE_SIGN_ENTITLEMENTS"],
        production_entitlements: "KitchenMemoryMac/KitchenMemory.entitlements",
        testing_entitlements: "KitchenMemoryMac/KitchenMemory-Testing.entitlements"
      }
    }.freeze
    APP_BUNDLE_IDENTIFIERS = {
      "Develop" => "net.ctwelve.dev.KitchenMemory"
    }.freeze
    PRODUCTION_BUNDLE_IDENTIFIER = "net.ctwelve.KitchenMemory"
    SYNCHRONIZED_GROUPS = {
      "KitchenMemory iOS" => ["KitchenMemory", "KitchenMemoryIOS"],
      "KitchenMemory macOS" => ["KitchenMemory", "KitchenMemoryMac"],
      "KitchenMemoryIOSTests" => ["KitchenMemoryTests"],
      "KitchenMemoryMacTests" => ["KitchenMemoryTests"],
      "KitchenMemoryUITests" => ["KitchenMemoryUITests"],
      "KitchenMemoryDomain" => ["KitchenMemoryDomain"],
      "KitchenMemoryImport" => ["KitchenMemoryImport"],
      "KitchenMemoryLogic" => ["KitchenMemoryLogic"],
      "KitchenMemoryPersistence" => ["KitchenMemoryPersistence"]
    }.freeze
    PLATFORM_INFO_EXCEPTIONS = {
      "KitchenMemoryIOS" => "KitchenMemory iOS",
      "KitchenMemoryMac" => "KitchenMemory macOS"
    }.freeze
    PLANS = {
      "KitchenMemoryIOSTesting.xctestplan" => ["KitchenMemoryIOSTests"],
      "KitchenMemoryIOSProduction.xctestplan" => [
        "KitchenMemoryIOSTests",
        "KitchenMemoryUITests"
      ],
      "KitchenMemoryMacTesting.xctestplan" => ["KitchenMemoryMacTests"],
      "KitchenMemoryMacProduction.xctestplan" => [
        "KitchenMemoryMacTests",
        "KitchenMemoryUITests"
      ]
    }.freeze
    PLAN_POLICIES = {
      "KitchenMemoryIOSTesting.xctestplan" => {
        configuration: "Core and Application Tests",
        code_coverage: true
      },
      "KitchenMemoryIOSProduction.xctestplan" => {
        configuration: "Production Validation",
        code_coverage: false
      },
      "KitchenMemoryMacTesting.xctestplan" => {
        configuration: "Core and Application Tests",
        code_coverage: true
      },
      "KitchenMemoryMacProduction.xctestplan" => {
        configuration: "Production Validation",
        code_coverage: false
      }
    }.freeze
    SCHEME_ACTION_CONFIGURATIONS = {
      "Development" => {
        "TestAction" => "Testing",
        "LaunchAction" => "Develop",
        "ProfileAction" => "Production",
        "AnalyzeAction" => "Develop",
        "ArchiveAction" => "Develop"
      },
      "Testing" => {
        "TestAction" => "Testing",
        "LaunchAction" => "Testing",
        "ProfileAction" => "Testing",
        "AnalyzeAction" => "Testing",
        "ArchiveAction" => "Testing"
      },
      "Production" => {
        "TestAction" => "ProductionTesting",
        "LaunchAction" => "Production",
        "ProfileAction" => "Production",
        "AnalyzeAction" => "Production",
        "ArchiveAction" => "Production"
      }
    }.freeze
    SCHEMES = {
      "KitchenMemory iOS Development" => {
        app: "KitchenMemory iOS",
        plan: "KitchenMemoryIOSTesting.xctestplan"
      },
      "KitchenMemory iOS Testing" => {
        app: "KitchenMemory iOS",
        plan: "KitchenMemoryIOSTesting.xctestplan"
      },
      "KitchenMemory iOS Production" => {
        app: "KitchenMemory iOS",
        plan: "KitchenMemoryIOSProduction.xctestplan"
      },
      "KitchenMemory macOS Development" => {
        app: "KitchenMemory macOS",
        plan: "KitchenMemoryMacTesting.xctestplan"
      },
      "KitchenMemory macOS Testing" => {
        app: "KitchenMemory macOS",
        plan: "KitchenMemoryMacTesting.xctestplan"
      },
      "KitchenMemory macOS Production" => {
        app: "KitchenMemory macOS",
        plan: "KitchenMemoryMacProduction.xctestplan"
      }
    }.freeze
    OBJECT_HEADER = /\A([\t ]*)([0-9A-F]+) \/\* (.*?) \*\/ = \{[\t ]*\z/.freeze

    class ContractError < StandardError; end

    module_function

    def validate(project_contents:, schemes:, plans:)
      objects = parse_objects(project_contents)
      validate_project_configurations(objects, parse_file_references(project_contents))
      targets = validate_targets(objects)
      configurations = validate_configurations(objects, targets)
      validate_platforms(configurations)
      validate_ui_test_hosts(configurations.fetch("KitchenMemoryUITests"))
      validate_app_file_settings(configurations)
      validate_synchronized_groups(objects, targets)

      normalized_plans = normalize_files(plans)
      normalized_schemes = normalize_files(schemes, ".xcscheme")
      validate_plans(normalized_plans, targets)
      validate_schemes(normalized_schemes, normalized_plans, targets)

      {
        target_count: targets.length,
        scheme_count: normalized_schemes.length,
        plan_count: normalized_plans.length
      }
    end

    def validate_repository(root)
      project_path = File.join(root, "KitchenMemory.xcodeproj", "project.pbxproj")
      scheme_pattern = File.join(root, "KitchenMemory.xcodeproj", "xcshareddata", "xcschemes", "*.xcscheme")
      plan_pattern = File.join(root, "*.xctestplan")
      schemes = Dir[scheme_pattern].each_with_object({}) { |path, result| result[path] = File.read(path) }
      plans = Dir[plan_pattern].each_with_object({}) { |path, result| result[path] = File.read(path) }

      validate(project_contents: File.read(project_path), schemes: schemes, plans: plans)
    end

    def parse_objects(contents)
      lines = contents.lines
      objects = {}
      index = 0

      while index < lines.length
        line = lines[index].sub(/\r?\n\z/, "")
        header = OBJECT_HEADER.match(line)
        unless header
          index += 1
          next
        end

        indent = header[1]
        closing_line = "#{indent}};"
        cursor = index + 1
        body = []
        while cursor < lines.length && lines[cursor].sub(/\r?\n\z/, "") != closing_line
          body << lines[cursor]
          cursor += 1
        end
        raise ContractError, "unterminated project object #{header[2]}" if cursor == lines.length
        raise ContractError, "duplicate project object identifier #{header[2]}" if objects.key?(header[2])

        body_text = body.join
        objects[header[2]] = {
          id: header[2],
          comment: header[3],
          isa: property(body_text, "isa"),
          body: body_text
        }
        index = cursor + 1
      end

      objects
    end

    def validate_targets(objects)
      targets = {}
      objects.each_value do |object|
        next unless object[:isa] == "PBXNativeTarget"

        name = property(object[:body], "name")
        raise ContractError, "native target #{object[:id]} has no name" if name.to_s.empty?
        raise ContractError, "duplicate native target name #{name.inspect}" if targets.key?(name)

        targets[name] = object.merge(
          name: name,
          product_type: property(object[:body], "productType"),
          configuration_list_id: reference_id(property(object[:body], "buildConfigurationList")),
          synchronized_group_ids: reference_ids(
            object[:body],
            "fileSystemSynchronizedGroups"
          )
        )
      end

      assert_exact_names("native targets", targets.keys, TARGET_TYPES.keys)
      TARGET_TYPES.each do |name, expected_type|
        actual_type = targets.fetch(name)[:product_type]
        next if actual_type == expected_type

        raise ContractError,
              "#{name} must use product type #{expected_type.inspect}; found #{actual_type.inspect}"
      end
      targets
    end

    def validate_project_configurations(objects, file_references)
      projects = objects.each_value.select { |object| object[:isa] == "PBXProject" }
      raise ContractError, "project must contain exactly one PBXProject object" unless projects.length == 1

      list_id = reference_id(property(projects.first[:body], "buildConfigurationList"))
      records = configuration_records(objects, list_id, "project")
      assert_exact_names("project configurations", records.map { |record| record[:name] }, APP_CONFIGURATIONS)

      records.each do |record|
        reference = property(objects.fetch(record[:id])[:body], "baseConfigurationReference")
        reference_identifier = reference_id(reference)
        actual_path = file_references[reference_identifier]
        expected_path = PROJECT_CONFIGURATION_FILES.fetch(record[:name])
        next if actual_path == expected_path

        raise ContractError,
              "project #{record[:name]} must use #{expected_path}; found #{actual_path.inspect}"
      end
    end

    def validate_configurations(objects, targets)
      configurations = {}
      targets.each do |target_name, target|
        configurations[target_name] = configuration_records(
          objects,
          target[:configuration_list_id],
          target_name
        )
      end

      TARGET_TYPES.each_key do |target_name|
        names = configurations.fetch(target_name).map { |record| record[:name] }
        assert_exact_names("#{target_name} configurations", names, APP_CONFIGURATIONS)
      end
      configurations
    end

    def configuration_records(objects, list_id, owner_name)
      list = objects[list_id]
      unless list && list[:isa] == "XCConfigurationList"
        raise ContractError, "#{owner_name} references missing configuration list #{list_id.inspect}"
      end

      ids = configuration_ids(list[:body])
      raise ContractError, "#{owner_name} has no build configurations" if ids.empty?
      if ids.uniq.length != ids.length
        raise ContractError, "#{owner_name} repeats a build configuration identifier"
      end

      records = ids.map do |identifier|
        configuration = objects[identifier]
        unless configuration && configuration[:isa] == "XCBuildConfiguration"
          raise ContractError, "#{owner_name} references missing build configuration #{identifier.inspect}"
        end

        {
          id: identifier,
          name: property(configuration[:body], "name"),
          settings: build_settings(configuration[:body])
        }
      end
      names = records.map { |record| record[:name] }
      duplicates = names.group_by { |name| name }.select { |_name, entries| entries.length > 1 }.keys
      unless duplicates.empty?
        raise ContractError, "#{owner_name} repeats build configuration #{duplicates.join(', ')}"
      end

      records
    end

    def validate_platforms(configurations)
      TARGET_PLATFORMS.each do |target_name, expected_platforms|
        configurations.fetch(target_name).each do |configuration|
          settings = configuration[:settings]
          actual_platforms = settings.fetch("SUPPORTED_PLATFORMS", "").split.sort
          next if actual_platforms == expected_platforms.sort

          raise ContractError,
                "#{target_name} #{configuration[:name]} must support only " \
                "#{expected_platforms.join(', ')}; found #{actual_platforms.join(', ')}"
        end
      end

      configurations.fetch("KitchenMemory iOS").each do |configuration|
        IOS_COMPATIBILITY_EXCLUSIONS.each do |setting, expected_value|
          actual_value = configuration[:settings][setting]
          next if actual_value == expected_value

          raise ContractError,
                "KitchenMemory iOS #{configuration[:name]} must set #{setting} to " \
                "#{expected_value}; found #{actual_value.inspect}"
        end
      end
    end

    def validate_ui_test_hosts(configurations)
      configurations.each do |configuration|
        actual_hosts = configuration[:settings].select do |setting, _value|
          setting.start_with?("TEST_TARGET_NAME")
        end
        next if actual_hosts == UI_TEST_HOSTS

        raise ContractError,
              "KitchenMemoryUITests #{configuration[:name]} must map native SDK hosts to both applications"
      end
    end

    def validate_app_file_settings(configurations)
      APP_FILE_CONTRACTS.each do |target_name, contract|
        configurations.fetch(target_name).each do |configuration|
          settings = configuration[:settings]
          name = configuration[:name]
          unless settings["INFOPLIST_FILE"] == contract[:info_plist]
            raise ContractError,
                  "#{target_name} #{name} must use #{contract[:info_plist]}"
          end

          entitlement_path = if %w[Testing ProductionTesting].include?(name)
                               contract[:testing_entitlements]
                             else
                               contract[:production_entitlements]
                             end
          expected_entitlements = contract[:entitlement_keys].to_h do |key|
            [key, entitlement_path]
          end
          actual_entitlements = settings.select do |setting, _value|
            setting.start_with?("CODE_SIGN_ENTITLEMENTS")
          end
          unless actual_entitlements == expected_entitlements
            raise ContractError,
                  "#{target_name} #{name} must use only #{entitlement_path} for its native SDKs"
          end

          expected_bundle_identifier = APP_BUNDLE_IDENTIFIERS.fetch(
            name,
            PRODUCTION_BUNDLE_IDENTIFIER
          )
          next if settings["PRODUCT_BUNDLE_IDENTIFIER"] == expected_bundle_identifier

          raise ContractError,
                "#{target_name} #{name} must use bundle identifier #{expected_bundle_identifier}"
        end
      end
    end

    def validate_synchronized_groups(objects, targets)
      groups = objects.each_value.select do |object|
        object[:isa] == "PBXFileSystemSynchronizedRootGroup"
      end
      groups_by_id = groups.to_h { |group| [group[:id], group] }
      groups_by_path = {}
      groups.each do |group|
        path = property(group[:body], "path")
        raise ContractError, "synchronized group #{group[:id]} has no path" if path.to_s.empty?
        raise ContractError, "duplicate synchronized group path #{path}" if groups_by_path.key?(path)

        groups_by_path[path] = group
      end
      expected_paths = SYNCHRONIZED_GROUPS.values.flatten.uniq
      assert_exact_names("synchronized root groups", groups_by_path.keys, expected_paths)

      SYNCHRONIZED_GROUPS.each do |target_name, expected_paths_for_target|
        actual_paths = targets.fetch(target_name)[:synchronized_group_ids].map do |identifier|
          group = groups_by_id[identifier]
          raise ContractError, "#{target_name} references missing synchronized group #{identifier}" unless group

          property(group[:body], "path")
        end
        assert_exact_names(
          "#{target_name} synchronized groups",
          actual_paths,
          expected_paths_for_target
        )
      end

      referenced_exception_ids = []
      groups_by_path.each do |path, group|
        exception_ids = reference_ids(group[:body], "exceptions")
        expected_target_name = PLATFORM_INFO_EXCEPTIONS[path]
        if expected_target_name
          unless exception_ids.length == 1
            raise ContractError, "#{path} must contain exactly one Info.plist membership exception"
          end
          validate_info_exception(objects, exception_ids.first, targets.fetch(expected_target_name), path)
        elsif !exception_ids.empty?
          raise ContractError, "#{path} must not contain synchronized membership exceptions"
        end
        referenced_exception_ids.concat(exception_ids)
      end

      exception_ids = objects.each_value.each_with_object([]) do |object, result|
        result << object[:id] if object[:isa] == "PBXFileSystemSynchronizedBuildFileExceptionSet"
      end
      assert_exact_names(
        "synchronized membership exception sets",
        exception_ids,
        referenced_exception_ids
      )
    end

    def validate_info_exception(objects, identifier, target, group_path)
      exception = objects[identifier]
      unless exception && exception[:isa] == "PBXFileSystemSynchronizedBuildFileExceptionSet"
        raise ContractError, "#{group_path} references missing membership exception #{identifier}"
      end
      members = list_values(exception[:body], "membershipExceptions")
      unless members == ["Info.plist"]
        raise ContractError, "#{group_path} exception must contain only Info.plist"
      end

      actual_target_id = reference_id(property(exception[:body], "target"))
      return if actual_target_id == target[:id]

      raise ContractError, "#{group_path} Info.plist exception must belong to #{target[:name]}"
    end

    def validate_plans(plans, targets)
      assert_exact_names("test plans", plans.keys, PLANS.keys)
      targets_by_id = targets.each_value.each_with_object({}) do |target, result|
        result[target[:id]] = target
      end

      PLANS.each do |filename, expected_target_names|
        begin
          plan = JSON.parse(plans.fetch(filename))
        rescue JSON::ParserError => error
          raise ContractError, "#{filename} is not valid JSON: #{error.message}"
        end

        unless plan["version"] == 1
          raise ContractError, "#{filename} must use test plan format version 1"
        end
        policy = PLAN_POLICIES.fetch(filename)
        plan_configurations = plan.fetch("configurations", [])
        configuration_names = plan_configurations.map { |entry| entry["name"] }
        unless configuration_names == [policy[:configuration]]
          raise ContractError,
                "#{filename} must contain only configuration #{policy[:configuration].inspect}"
        end
        unless plan_configurations.first["options"] == {}
          raise ContractError, "#{filename} configuration options must remain empty"
        end
        default_options = plan.fetch("defaultOptions", {})
        unless default_options["codeCoverage"] == policy[:code_coverage]
          raise ContractError,
                "#{filename} codeCoverage must be #{policy[:code_coverage]}"
        end
        expected_arguments = [{ "argument" => "--unit-testing" }]
        unless default_options["commandLineArgumentEntries"] == expected_arguments
          raise ContractError, "#{filename} must pass only --unit-testing by default"
        end

        test_targets = plan.fetch("testTargets", [])
        actual_target_names = test_targets.map { |entry| entry.dig("target", "name") }
        assert_exact_names("#{filename} test targets", actual_target_names, expected_target_names)

        test_targets.each do |entry|
          reference = entry.fetch("target", {})
          identifier = reference["identifier"]
          name = reference["name"]
          target = targets_by_id[identifier]
          raise ContractError, "#{filename} references missing target identifier #{identifier.inspect}" unless target
          unless target[:name] == name
            raise ContractError,
                  "#{filename} target identifier #{identifier} names #{target[:name].inspect}, not #{name.inspect}"
          end
          unless reference["containerPath"] == "container:KitchenMemory.xcodeproj"
            raise ContractError, "#{filename} must reference container:KitchenMemory.xcodeproj"
          end
        end
      end
    end

    def validate_schemes(schemes, plans, targets)
      assert_exact_names("shared schemes", schemes.keys, SCHEMES.keys)
      targets_by_id = targets.each_value.each_with_object({}) do |target, result|
        result[target[:id]] = target
      end

      SCHEMES.each do |scheme_name, expected|
        document = parse_scheme(scheme_name, schemes.fetch(scheme_name))
        references = REXML::XPath.match(
          document,
          "/Scheme/TestAction/TestPlans/TestPlanReference"
        ).map { |element| element.attributes["reference"] }
        expected_reference = "container:#{expected[:plan]}"
        unless references == [expected_reference]
          raise ContractError,
                "#{scheme_name} must reference only #{expected_reference}; found #{references.inspect}"
        end
        raise ContractError, "#{scheme_name} references missing plan #{expected[:plan]}" unless plans.key?(expected[:plan])

        validate_scheme_buildables(scheme_name, document, targets_by_id)
        build_names = REXML::XPath.match(
          document,
          "/Scheme/BuildAction/BuildActionEntries/BuildActionEntry/BuildableReference"
        ).map { |element| element.attributes["BlueprintName"] }
        unless build_names == [expected[:app]]
          raise ContractError,
                "#{scheme_name} build action must contain only #{expected[:app]}; found #{build_names.inspect}"
        end
        validate_scheme_action_membership(scheme_name, document)
        validate_scheme_action_configurations(scheme_name, document)
        validate_scheme_runnable(scheme_name, document, "LaunchAction", expected[:app])
        validate_scheme_runnable(scheme_name, document, "ProfileAction", expected[:app])

        expected_testables = PLANS.fetch(expected[:plan])
        testable_names = REXML::XPath.match(
          document,
          "/Scheme/TestAction/Testables/TestableReference/BuildableReference"
        ).map { |element| element.attributes["BlueprintName"] }
        assert_exact_names("#{scheme_name} testables", testable_names, expected_testables)
      end
    end

    def validate_scheme_action_membership(scheme_name, document)
      entries = REXML::XPath.match(
        document,
        "/Scheme/BuildAction/BuildActionEntries/BuildActionEntry"
      )
      raise ContractError, "#{scheme_name} must contain one build action entry" unless entries.length == 1

      flavor = scheme_name.split.last
      expected_attributes = {
        "buildForTesting" => "YES",
        "buildForRunning" => "YES",
        "buildForProfiling" => flavor == "Testing" ? "NO" : "YES",
        "buildForArchiving" => flavor == "Production" ? "YES" : "NO",
        "buildForAnalyzing" => "YES"
      }
      expected_attributes.each do |attribute, expected_value|
        actual_value = entries.first.attributes[attribute]
        next if actual_value == expected_value

        raise ContractError,
              "#{scheme_name} must set #{attribute} to #{expected_value}; found #{actual_value.inspect}"
      end
    end

    def validate_scheme_action_configurations(scheme_name, document)
      flavor = scheme_name.split.last
      SCHEME_ACTION_CONFIGURATIONS.fetch(flavor).each do |action, expected_configuration|
        elements = REXML::XPath.match(document, "/Scheme/#{action}")
        unless elements.length == 1
          raise ContractError, "#{scheme_name} must contain exactly one #{action}"
        end
        actual_configuration = elements.first.attributes["buildConfiguration"]
        next if actual_configuration == expected_configuration

        raise ContractError,
              "#{scheme_name} #{action} must use #{expected_configuration}; " \
              "found #{actual_configuration.inspect}"
      end
    end

    def validate_scheme_runnable(scheme_name, document, action, expected_app)
      references = REXML::XPath.match(
        document,
        "/Scheme/#{action}/BuildableProductRunnable/BuildableReference"
      )
      names = references.map { |reference| reference.attributes["BlueprintName"] }
      return if names == [expected_app]

      raise ContractError,
            "#{scheme_name} #{action} must run only #{expected_app}; found #{names.inspect}"
    end

    def validate_scheme_buildables(scheme_name, document, targets_by_id)
      REXML::XPath.match(document, "//BuildableReference").each do |reference|
        next unless reference.attributes["ReferencedContainer"] == "container:KitchenMemory.xcodeproj"

        identifier = reference.attributes["BlueprintIdentifier"]
        name = reference.attributes["BlueprintName"]
        target = targets_by_id[identifier]
        raise ContractError, "#{scheme_name} references missing target identifier #{identifier.inspect}" unless target
        next if target[:name] == name

        raise ContractError,
              "#{scheme_name} target identifier #{identifier} names #{target[:name].inspect}, not #{name.inspect}"
      end
    end

    def parse_scheme(name, contents)
      REXML::Document.new(contents)
    rescue REXML::ParseException => error
      raise ContractError, "#{name}.xcscheme is not valid XML: #{error.message}"
    end

    def parse_file_references(contents)
      contents.each_line.each_with_object({}) do |line, result|
        match = /\A[\t ]*([0-9A-F]+) \/\*.*?\*\/ = \{(.*?)\};[\t ]*\r?\n?\z/.match(line)
        next unless match
        next unless match[2].match?(/(?:\A|;[\t ]*)isa = PBXFileReference;/)

        path_match = /(?:\A|;[\t ]*)path = (.*?);/.match(match[2])
        result[match[1]] = unquote(path_match[1]) if path_match
      end
    end

    def normalize_files(files, extension = nil)
      files.each_with_object({}) do |(path, contents), result|
        name = extension ? File.basename(path, extension) : File.basename(path)
        raise ContractError, "duplicate file named #{name}" if result.key?(name)

        result[name] = contents
      end
    end

    def assert_exact_names(label, actual, expected)
      actual_counts = actual.each_with_object(Hash.new(0)) { |name, counts| counts[name] += 1 }
      missing = expected.reject { |name| actual_counts.key?(name) }
      unexpected = actual_counts.keys.reject { |name| expected.include?(name) }
      duplicates = actual_counts.select { |_name, count| count > 1 }.keys
      return if missing.empty? && unexpected.empty? && duplicates.empty? && actual.length == expected.length

      details = []
      details << "missing: #{missing.join(', ')}" unless missing.empty?
      details << "unexpected: #{unexpected.join(', ')}" unless unexpected.empty?
      details << "duplicate: #{duplicates.join(', ')}" unless duplicates.empty?
      raise ContractError, "#{label} must be exactly #{expected.join(', ')} (#{details.join('; ')})"
    end

    def property(body, name)
      body.each_line do |line|
        match = /\A[\t ]*#{Regexp.escape(name)}[\t ]*=[\t ]*(.*?);[\t ]*\r?\n?\z/.match(line)
        return unquote(match[1]) if match
      end
      nil
    end

    def reference_id(value)
      value.to_s[/\A[0-9A-F]+/]
    end

    def configuration_ids(body)
      block_lines(body, "buildConfigurations", "(", ");").each_with_object([]) do |line, result|
        identifier = line[/\A[\t ]*([0-9A-F]+)(?:[\t ]+\/\*.*?\*\/)?[\t ]*,?[\t ]*\r?\n?\z/, 1]
        result << identifier if identifier
      end
    end

    def reference_ids(body, name)
      block_lines(body, name, "(", ");").each_with_object([]) do |line, result|
        identifier = line[/\A[\t ]*([0-9A-F]+)(?:[\t ]+\/\*.*?\*\/)?[\t ]*,?[\t ]*\r?\n?\z/, 1]
        result << identifier if identifier
      end
    end

    def list_values(body, name)
      block_lines(body, name, "(", ");").each_with_object([]) do |line, result|
        value = line.strip.sub(/,[\t ]*\z/, "").sub(/[\t ]+\/\*.*?\*\/[\t ]*\z/, "")
        result << unquote(value) unless value.empty?
      end
    end

    def build_settings(body)
      block_lines(body, "buildSettings", "{", "};").each_with_object({}) do |line, result|
        match = /\A[\t ]*(.+?)[\t ]+=[\t ]+(.*?);[\t ]*\r?\n?\z/.match(line)
        next unless match

        result[unquote(match[1])] = unquote(match[2])
      end
    end

    def block_lines(body, name, opener, closer)
      lines = body.lines
      start_index = nil
      indent = nil
      lines.each_with_index do |line, index|
        match = /\A([\t ]*)#{Regexp.escape(name)}[\t ]*=[\t ]*#{Regexp.escape(opener)}[\t ]*\r?\n?\z/.match(line)
        next unless match

        start_index = index
        indent = match[1]
        break
      end
      return [] unless start_index

      result = []
      cursor = start_index + 1
      closing_line = "#{indent}#{closer}"
      while cursor < lines.length && lines[cursor].sub(/\r?\n\z/, "") != closing_line
        result << lines[cursor]
        cursor += 1
      end
      result
    end

    def unquote(value)
      stripped = value.to_s.strip
      return stripped unless stripped.start_with?("\"") && stripped.end_with?("\"")

      stripped[1...-1]
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = { root: File.expand_path("..", __dir__) }
  OptionParser.new do |arguments|
    arguments.banner = "Usage: check-project-structure.rb [options]"
    arguments.on("--root PATH", "Repository root; defaults to the parent of Tools") do |path|
      options[:root] = File.expand_path(path)
    end
  end.parse!

  begin
    result = KitchenMemory::ProjectStructure.validate_repository(options[:root])
    puts "Validated #{result[:target_count]} targets, #{result[:scheme_count]} shared schemes, " \
         "and #{result[:plan_count]} test plans."
  rescue KitchenMemory::ProjectStructure::ContractError, Errno::ENOENT => error
    warn "Project structure contract failed: #{error.message}"
    exit 1
  end
end
