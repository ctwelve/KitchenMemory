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
      "KitchenMemory" => "com.apple.product-type.application",
      "KitchenMemoryTests" => "com.apple.product-type.bundle.unit-test",
      "KitchenMemoryUITests" => "com.apple.product-type.bundle.ui-testing",
      "KitchenKit" => "com.apple.product-type.framework",
      "KitchenKitTests" => "com.apple.product-type.bundle.unit-test"
    }.freeze
    TARGET_PLATFORMS = {
      "KitchenMemory" => %w[iphoneos iphonesimulator macosx],
      "KitchenMemoryTests" => %w[iphoneos iphonesimulator macosx],
      "KitchenMemoryUITests" => %w[iphoneos iphonesimulator macosx],
      "KitchenKit" => %w[iphoneos iphonesimulator macosx],
      "KitchenKitTests" => %w[iphoneos iphonesimulator macosx]
    }.freeze
    IOS_COMPATIBILITY_EXCLUSIONS = {
      "SUPPORTS_MACCATALYST" => "NO",
      "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD" => "NO",
      "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD" => "NO"
    }.freeze
    UI_TEST_HOSTS = {
      "TEST_TARGET_NAME[sdk=iphoneos*]" => "KitchenMemory",
      "TEST_TARGET_NAME[sdk=iphonesimulator*]" => "KitchenMemory",
      "TEST_TARGET_NAME[sdk=macosx*]" => "KitchenMemory"
    }.freeze
    HOSTED_TEST_SETTINGS = {
      "BUNDLE_LOADER" => "$(TEST_HOST)",
      "TEST_HOST" => "$(BUILT_PRODUCTS_DIR)/KitchenMemory.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/KitchenMemory"
    }.freeze
    UNHOSTED_TEST_TARGETS = %w[KitchenKitTests].freeze
    PROJECT_CONFIGURATION_FILES = APP_CONFIGURATIONS.to_h do |configuration|
      [configuration, "#{configuration}.xcconfig"]
    end.freeze
    PROJECT_BUILD_SETTINGS = {
      "MERGED_BINARY_TYPE" => "automatic"
    }.freeze
    APP_FILE_CONTRACTS = {
      "KitchenMemory" => {
        info_plist_settings: {
          "GENERATE_INFOPLIST_FILE" => "NO",
          "INFOPLIST_FILE[sdk=iphoneos*]" => "KitchenMemory/Info-iOS.plist",
          "INFOPLIST_FILE[sdk=iphonesimulator*]" => "KitchenMemory/Info-iOS.plist",
          "INFOPLIST_FILE[sdk=macosx*]" => "KitchenMemory/Info-macOS.plist"
        },
        production_entitlements: {
          "CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]" => "KitchenMemory/KitchenMemory-iOS.entitlements",
          "CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]" => "KitchenMemory/KitchenMemory-iOS.entitlements",
          "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]" => "KitchenMemory/KitchenMemory-macOS.entitlements"
        },
        testing_entitlements: {
          "CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]" => "KitchenMemory/KitchenMemory-iOS-Testing.entitlements",
          "CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]" => "KitchenMemory/KitchenMemory-iOS-Testing.entitlements",
          "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]" => "KitchenMemory/KitchenMemory-macOS-Testing.entitlements"
        }
      }
    }.freeze
    APP_BUNDLE_IDENTIFIERS = {
      "Develop" => "net.ctwelve.dev.KitchenMemory"
    }.freeze
    PRODUCTION_BUNDLE_IDENTIFIER = "net.ctwelve.KitchenMemory"
    SYNCHRONIZED_GROUPS = {
      "KitchenMemory" => ["KitchenMemory"],
      "KitchenMemoryTests" => ["KitchenMemoryTests"],
      "KitchenMemoryUITests" => ["KitchenMemoryUITests"],
      "KitchenKit" => ["KitchenKit"],
      "KitchenKitTests" => ["KitchenKitTests"]
    }.freeze
    PLATFORM_INFO_EXCEPTIONS = {
      "KitchenMemory" => "KitchenMemory"
    }.freeze
    APPLICATION_MEMBERSHIP_EXCEPTIONS = %w[Info-iOS.plist Info-macOS.plist].freeze
    IOS_ONLY_LAUNCH_RESOURCES = [
      "/Localized: LaunchScreen.storyboard",
      "LaunchScreenAssets.xcassets"
    ].freeze
    OBSOLETE_PROJECT_METADATA = [
      "KitchenMemory iOS",
      "KitchenMemory macOS",
      "KitchenMemoryIOS",
      "KitchenMemoryMacOS"
    ].freeze
    SHARED_INFO_PLIST_KEYS = %w[
      CFBundleDevelopmentRegion
      CFBundleDisplayName
      CFBundleExecutable
      CFBundleIdentifier
      CFBundleInfoDictionaryVersion
      CFBundleName
      CFBundlePackageType
      CFBundleShortVersionString
      CFBundleVersion
      KitchenMemoryCloudKitContainerIdentifier
      LSApplicationCategoryType
      NSHumanReadableCopyright
    ].freeze
    IOS_INFO_PLIST_KEYS = %w[
      UIBackgroundModes
      UIApplicationSceneManifest
      UIApplicationSupportsIndirectInputEvents
      UILaunchStoryboardName
      UISupportedInterfaceOrientations~ipad
      UISupportedInterfaceOrientations~iphone
    ].freeze
    TEST_PREBUILD_PHASES = {
      "KitchenMemoryTests" => "Embed Localization Catalog Contract"
    }.freeze
    PLANS = {
      "KitchenKit.xctestplan" => %w[KitchenKitTests],
      "KitchenMemory.xctestplan" => %w[KitchenMemoryTests KitchenMemoryUITests]
    }.freeze
    PLAN_POLICIES = {
      "KitchenKit.xctestplan" => {
        configuration: "Test Scheme Action"
      },
      "KitchenMemory.xctestplan" => {
        configuration: "Test Scheme Action",
        variable_expansion_target: "KitchenMemory"
      }
    }.freeze
    SCHEME_ACTION_CONFIGURATIONS = {
      "KitchenKit" => {
        "TestAction" => "Testing",
        "LaunchAction" => "Debug",
        "ProfileAction" => "Production",
        "AnalyzeAction" => "Testing",
        "ArchiveAction" => "Production"
      },
      "KitchenMemory" => {
        "TestAction" => "Testing",
        "LaunchAction" => "Debug",
        "ProfileAction" => "Production",
        "AnalyzeAction" => "Testing",
        "ArchiveAction" => "Production"
      }
    }.freeze
    SCHEMES = {
      "KitchenKit" => {
        product: "KitchenKit",
        plan: "KitchenKit.xctestplan",
        runnable: false
      },
      "KitchenMemory" => {
        product: "KitchenMemory",
        plan: "KitchenMemory.xctestplan",
        runnable: true
      }
    }.freeze
    OBJECT_HEADER = /\A([\t ]*)([0-9A-F]+) \/\* (.*?) \*\/ = \{[\t ]*\z/.freeze

    class ContractError < StandardError; end

    module_function

    def validate(project_contents:, schemes:, plans:)
      validate_obsolete_project_metadata(project_contents)
      objects = parse_objects(project_contents)
      validate_project_configurations(objects, parse_file_references(project_contents))
      targets = validate_targets(objects)
      validate_test_prebuild_phases(objects, targets)
      configurations = validate_configurations(objects, targets)
      validate_platforms(configurations)
      validate_hosted_tests(configurations.fetch("KitchenMemoryTests"))
      validate_ui_test_hosts(configurations.fetch("KitchenMemoryUITests"))
      validate_unhosted_tests(configurations)
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

    def validate_obsolete_project_metadata(project_contents)
      obsolete_name = OBSOLETE_PROJECT_METADATA.find do |name|
        project_contents.include?(name)
      end
      return unless obsolete_name

      raise ContractError, "obsolete Xcode target metadata remains: #{obsolete_name}"
    end

    def validate_repository(root)
      project_path = File.join(root, "KitchenMemory.xcodeproj", "project.pbxproj")
      scheme_pattern = File.join(root, "KitchenMemory.xcodeproj", "xcshareddata", "xcschemes", "*.xcscheme")
      plan_pattern = File.join(root, "*.xctestplan")
      schemes = Dir[scheme_pattern].each_with_object({}) { |path, result| result[path] = File.read(path) }
      plans = Dir[plan_pattern].each_with_object({}) { |path, result| result[path] = File.read(path) }
      validate_info_plist_sources(
        ios_contents: File.read(File.join(root, "KitchenMemory", "Info-iOS.plist")),
        macos_contents: File.read(File.join(root, "KitchenMemory", "Info-macOS.plist"))
      )

      validate(project_contents: File.read(project_path), schemes: schemes, plans: plans)
    end

    def validate_info_plist_sources(ios_contents:, macos_contents:)
      ios_values = info_plist_values(ios_contents, "iOS")
      mac_values = info_plist_values(macos_contents, "macOS")
      assert_exact_names("source macOS Info.plist keys", mac_values.keys, SHARED_INFO_PLIST_KEYS)
      assert_exact_names(
        "source iOS Info.plist keys",
        ios_values.keys,
        SHARED_INFO_PLIST_KEYS + IOS_INFO_PLIST_KEYS
      )
      background_modes = ios_values.fetch("UIBackgroundModes").elements.to_a.map(&:text)
      return if background_modes == ["remote-notification"]

      raise ContractError,
            "source iOS Info.plist UIBackgroundModes must contain only remote-notification"
    end

    def info_plist_values(contents, platform)
      document = REXML::Document.new(contents)
      dictionary = REXML::XPath.first(document, "/plist/dict")
      raise ContractError, "source #{platform} Info.plist must contain a root dictionary" unless dictionary

      elements = dictionary.elements.to_a
      if elements.length.odd? || elements.each_slice(2).any? { |key, _value| key.name != "key" }
        raise ContractError, "source #{platform} Info.plist dictionary is malformed"
      end
      values = elements.each_slice(2).to_h { |key, value| [key.text, value] }
      unless values.length == elements.length / 2
        raise ContractError, "source #{platform} Info.plist keys must be unique"
      end

      values
    rescue REXML::ParseException => error
      raise ContractError, "source #{platform} Info.plist is malformed: #{error.message}"
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

      records.each do |record|
        PROJECT_BUILD_SETTINGS.each do |setting, expected_value|
          actual_value = record[:settings][setting]
          next if actual_value == expected_value

          raise ContractError,
                "project #{record[:name]} must set #{setting} to #{expected_value}; " \
                "found #{actual_value.inspect}"
        end
      end
    end

    def validate_test_prebuild_phases(objects, targets)
      TEST_PREBUILD_PHASES.each do |target_name, expected_name|
        phase_ids = reference_ids(targets.fetch(target_name)[:body], "buildPhases")
        matching_phase_ids = phase_ids.select do |identifier|
          phase = objects[identifier]
          phase && phase[:isa] == "PBXShellScriptBuildPhase" &&
            property(phase[:body], "name") == expected_name
        end
        unless matching_phase_ids.length == 1
          raise ContractError,
                "#{target_name} must contain exactly one #{expected_name.inspect} shell phase"
        end
        next if phase_ids.first == matching_phase_ids.first

        raise ContractError,
              "#{target_name} must run #{expected_name.inspect} before every product build phase"
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

      configurations.fetch("KitchenMemory").each do |configuration|
        IOS_COMPATIBILITY_EXCLUSIONS.each do |setting, expected_value|
          actual_value = configuration[:settings][setting]
          next if actual_value == expected_value

          raise ContractError,
                "KitchenMemory #{configuration[:name]} must set #{setting} to " \
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
              "KitchenMemoryUITests #{configuration[:name]} must map every native SDK to KitchenMemory"
      end
    end

    def validate_hosted_tests(configurations)
      configurations.each do |configuration|
        actual_settings = configuration[:settings].select do |setting, _value|
          HOSTED_TEST_SETTINGS.key?(setting)
        end
        next if actual_settings == HOSTED_TEST_SETTINGS

        raise ContractError,
              "KitchenMemoryTests #{configuration[:name]} must be hosted by KitchenMemory"
      end
    end

    def validate_unhosted_tests(configurations)
      UNHOSTED_TEST_TARGETS.each do |target_name|
        configurations.fetch(target_name).each do |configuration|
          hosted_settings = configuration[:settings].keys & %w[BUNDLE_LOADER TEST_HOST]
          next if hosted_settings.empty?

          raise ContractError,
                "#{target_name} #{configuration[:name]} must remain unhosted; " \
                "found #{hosted_settings.join(', ')}"
        end
      end
    end

    def validate_app_file_settings(configurations)
      APP_FILE_CONTRACTS.each do |target_name, contract|
        configurations.fetch(target_name).each do |configuration|
          settings = configuration[:settings]
          name = configuration[:name]
          actual_info_plist_settings = settings.select do |setting, _value|
            setting == "GENERATE_INFOPLIST_FILE" || setting.start_with?("INFOPLIST_")
          end
          unless actual_info_plist_settings == contract[:info_plist_settings]
            raise ContractError,
                  "#{target_name} #{name} must select the editable platform Info.plists by SDK"
          end

          expected_entitlements = if %w[Testing ProductionTesting].include?(name)
                                    contract[:testing_entitlements]
                                  else
                                    contract[:production_entitlements]
                                  end
          actual_entitlements = settings.select do |setting, _value|
            setting.start_with?("CODE_SIGN_ENTITLEMENTS")
          end
          unless actual_entitlements == expected_entitlements
            raise ContractError,
                  "#{target_name} #{name} must select only the platform-appropriate entitlements"
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
      # Xcode also uses synchronized root groups for navigator-only folders.
      # Build ownership is the target reference contract enforced below, not
      # the existence of a synchronized group in the project navigator.
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
      unless members == APPLICATION_MEMBERSHIP_EXCEPTIONS
        raise ContractError,
              "#{group_path} exception must contain only the two source Info.plists"
      end
      expected_filters = IOS_ONLY_LAUNCH_RESOURCES.to_h { |path| [path, ["ios"]] }
      actual_filters = platform_filters(exception[:body])
      unless actual_filters == expected_filters
        raise ContractError,
              "#{group_path} exception must define the exact iOS-only launch resource filters"
      end

      actual_target_id = reference_id(property(exception[:body], "target"))
      return if actual_target_id == target[:id]

      raise ContractError, "#{group_path} Info.plist exception must belong to #{target[:name]}"
    end

    def platform_filters(body)
      dictionary = body.match(
        /^[\t ]*platformFiltersByRelativePath = \{\r?\n(?<entries>.*?)^[\t ]*\};/m
      )
      return {} unless dictionary

      dictionary[:entries].scan(
        /^[\t ]*(?:"(?<quoted>[^"]+)"|(?<plain>[^=\s]+))[\t ]*= \((?<values>.*?)\);/m
      ).each_with_object({}) do |(quoted, plain, values), result|
        result[quoted || plain] = values.scan(/(?:"([^"]+)"|([^,\s]+)),/).map do |quoted_value, plain_value|
          quoted_value || plain_value
        end
      end
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
        expected_default_options = {
          "performanceAntipatternCheckerEnabled" => true
        }
        if policy[:variable_expansion_target]
          expansion_target = targets.fetch(policy[:variable_expansion_target])
          expected_default_options["targetForVariableExpansion"] = {
            "containerPath" => "container:KitchenMemory.xcodeproj",
            "identifier" => expansion_target[:id],
            "name" => expansion_target[:name]
          }
        end
        unless plan.fetch("defaultOptions", {}) == expected_default_options
          detail = if policy[:variable_expansion_target]
                     " and expand variables against #{policy[:variable_expansion_target]}"
                   else
                     " without an application variable-expansion target"
                   end
          raise ContractError, "#{filename} must retain Xcode's default diagnostics#{detail}"
        end

        test_targets = plan.fetch("testTargets", [])
        actual_target_names = test_targets.map { |entry| entry.dig("target", "name") }
        assert_exact_names("#{filename} test targets", actual_target_names, expected_target_names)

        test_targets.each do |entry|
          unless entry["parallelizable"] == true
            raise ContractError, "#{filename} test targets must remain parallelizable"
          end
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
        )
        expected_reference = "container:#{expected[:plan]}"
        unless references.length == 1 &&
               references.first.attributes["reference"] == expected_reference &&
               references.first.attributes["default"] == "YES"
          raise ContractError,
                "#{scheme_name} must use #{expected_reference} as its only default test plan"
        end
        raise ContractError, "#{scheme_name} references missing plan #{expected[:plan]}" unless plans.key?(expected[:plan])
        test_action = REXML::XPath.first(document, "/Scheme/TestAction")
        if test_action&.attributes&.[]("shouldAutocreateTestPlan") == "YES"
          raise ContractError, "#{scheme_name} must not combine an explicit plan with automatic-plan creation"
        end

        validate_scheme_buildables(scheme_name, document, targets_by_id)
        build_names = REXML::XPath.match(
          document,
          "/Scheme/BuildAction/BuildActionEntries/BuildActionEntry/BuildableReference"
        ).map { |element| element.attributes["BlueprintName"] }
        expected_build_names = [expected[:product]]
        unless build_names == expected_build_names
          raise ContractError,
                "#{scheme_name} build action must contain only #{expected_build_names.join(', ')}; " \
                "found #{build_names.inspect}"
        end
        validate_scheme_action_membership(scheme_name, document)
        validate_scheme_action_configurations(scheme_name, document)
        if expected[:runnable]
          validate_scheme_runnable(scheme_name, document, "LaunchAction", expected[:product])
          validate_scheme_runnable(scheme_name, document, "ProfileAction", expected[:product])
        else
          validate_scheme_has_no_runnable(scheme_name, document, "LaunchAction")
          validate_scheme_has_no_runnable(scheme_name, document, "ProfileAction")
        end

        testable_references = REXML::XPath.match(
          document,
          "/Scheme/TestAction/Testables/TestableReference"
        )
        unless testable_references.empty?
          raise ContractError,
                "#{scheme_name} must leave test-target membership exclusively to #{expected[:plan]}"
        end
      end
    end

    def validate_scheme_action_membership(scheme_name, document)
      entries = REXML::XPath.match(
        document,
        "/Scheme/BuildAction/BuildActionEntries/BuildActionEntry"
      )
      raise ContractError, "#{scheme_name} must contain one build action entry" unless entries.length == 1

      expected_attributes = {
        "buildForTesting" => "YES",
        "buildForRunning" => "YES",
        "buildForProfiling" => "YES",
        "buildForArchiving" => "YES",
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
      SCHEME_ACTION_CONFIGURATIONS.fetch(scheme_name).each do |action, expected_configuration|
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

    def validate_scheme_has_no_runnable(scheme_name, document, action)
      references = REXML::XPath.match(
        document,
        "/Scheme/#{action}/BuildableProductRunnable/BuildableReference"
      )
      return if references.empty?

      raise ContractError, "#{scheme_name} #{action} must not declare a runnable product"
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
