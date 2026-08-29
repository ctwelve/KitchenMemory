#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "minitest/autorun"
require_relative "../check-project-structure"

class CheckProjectStructureTest < Minitest::Test
  class Fixture
    attr_reader :plans, :prebuild_phase_ids, :project, :schemes, :source_phase_ids, :target_ids

    def initialize(configuration_overrides = {})
      target_names = KitchenMemory::ProjectStructure::TARGET_TYPES.keys
      group_paths = KitchenMemory::ProjectStructure::SYNCHRONIZED_GROUPS.values.flatten.uniq
      @target_ids = identifier_map(target_names, 100)
      @configuration_list_ids = identifier_map(target_names, 1_000)
      @group_ids = identifier_map(group_paths, 300)
      @exception_ids = {
        "KitchenMemoryIOS" => format("%024X", 400),
        "KitchenMemoryMacOS" => format("%024X", 401)
      }
      @prebuild_phase_ids = identifier_map(
        KitchenMemory::ProjectStructure::TEST_PREBUILD_PHASES.keys,
        500
      )
      @source_phase_ids = identifier_map(
        KitchenMemory::ProjectStructure::TEST_PREBUILD_PHASES.keys,
        510
      )
      @project_configuration_list_id = format("%024X", 1_100)
      @project_configuration_ids = identifier_map(
        KitchenMemory::ProjectStructure::APP_CONFIGURATIONS,
        1_200
      )
      @configuration_file_ids = identifier_map(
        KitchenMemory::ProjectStructure::APP_CONFIGURATIONS,
        1_300
      )
      @configuration_ids = {}
      @configurations = default_configurations.merge(configuration_overrides)
      @project = build_project
      @plans = build_plans
      @schemes = build_schemes
    end

    private

    def identifier_map(names, offset)
      names.each_with_index.each_with_object({}) do |(name, index), result|
        result[name] = format("%024X", offset + index)
      end
    end

    def default_configurations
      KitchenMemory::ProjectStructure::TARGET_TYPES.keys.each_with_object({}) do |name, result|
        result[name] = KitchenMemory::ProjectStructure::APP_CONFIGURATIONS
      end
    end

    def build_project
      target_objects = KitchenMemory::ProjectStructure::TARGET_TYPES.map do |name, product_type|
        group_references = KitchenMemory::ProjectStructure::SYNCHRONIZED_GROUPS.fetch(name).map do |path|
          "\t\t\t\t#{@group_ids.fetch(path)} /* #{path} */,\n"
        end.join
        phase_references = if @prebuild_phase_ids.key?(name)
                             <<~PHASES
				#{@prebuild_phase_ids.fetch(name)} /* Embed Localization Catalog Contract */,
				#{@source_phase_ids.fetch(name)} /* Sources */,
                             PHASES
                           else
                             ""
                           end
        <<~TARGET
		#{@target_ids.fetch(name)} /* #{name} */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = #{@configuration_list_ids.fetch(name)} /* Build configuration list for PBXNativeTarget "#{name}" */;
			buildPhases = (
#{phase_references}			);
			fileSystemSynchronizedGroups = (
#{group_references}			);
			name = "#{name}";
			productType = "#{product_type}";
		};
        TARGET
      end

      group_objects = @group_ids.map do |path, identifier|
        exception = @exception_ids[path]
        exceptions = if exception
                       <<~EXCEPTIONS
			exceptions = (
				#{exception} /* Info.plist exception for #{path} */,
			);
                       EXCEPTIONS
                     else
                       ""
                     end
        <<~GROUP
		#{identifier} /* #{path} */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
#{exceptions}			path = #{path};
		};
        GROUP
      end

      exception_objects = @exception_ids.map do |path, identifier|
        target_name = KitchenMemory::ProjectStructure::PLATFORM_INFO_EXCEPTIONS.fetch(path)
        <<~EXCEPTION
		#{identifier} /* Info.plist exception for #{path} */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Info.plist,
			);
			target = #{@target_ids.fetch(target_name)} /* #{target_name} */;
		};
        EXCEPTION
      end

      prebuild_phase_objects = @prebuild_phase_ids.map do |target_name, identifier|
        <<~PHASE
		#{identifier} /* Embed Localization Catalog Contract */ = {
			isa = PBXShellScriptBuildPhase;
			name = "#{KitchenMemory::ProjectStructure::TEST_PREBUILD_PHASES.fetch(target_name)}";
		};
        PHASE
      end
      source_phase_objects = @source_phase_ids.map do |_target_name, identifier|
        <<~PHASE
		#{identifier} /* Sources */ = {
			isa = PBXSourcesBuildPhase;
		};
        PHASE
      end

      configuration_objects = []
      configuration_list_objects = []
      next_identifier = 2_000
      @configurations.each do |target_name, configuration_names|
        ids = configuration_names.map do |configuration_name|
          next_identifier += 1
          identifier = format("%024X", next_identifier)
          (@configuration_ids[target_name] ||= []) << identifier
          settings = configuration_settings(target_name, configuration_name)
          configuration_objects << <<~CONFIGURATION
		#{identifier} /* #{configuration_name} configuration for PBXNativeTarget "#{target_name}" */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
#{settings}			};
			name = #{configuration_name};
		};
          CONFIGURATION
          identifier
        end

        references = ids.zip(configuration_names).map do |identifier, configuration_name|
          "\t\t\t\t#{identifier} /* #{configuration_name} configuration for PBXNativeTarget \"#{target_name}\" */,\n"
        end.join
        configuration_list_objects << <<~LIST
		#{@configuration_list_ids.fetch(target_name)} /* Build configuration list for PBXNativeTarget "#{target_name}" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
#{references}			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		};
        LIST
      end

      project_configuration_objects = KitchenMemory::ProjectStructure::APP_CONFIGURATIONS.map do |name|
        identifier = @project_configuration_ids.fetch(name)
        file_identifier = @configuration_file_ids.fetch(name)
        <<~CONFIGURATION
		#{identifier} /* #{name} configuration for PBXProject "KitchenMemory" */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = #{file_identifier} /* #{name}.xcconfig */;
			buildSettings = {
				MERGED_BINARY_TYPE = automatic;
			};
			name = #{name};
		};
        CONFIGURATION
      end
      project_configuration_references = KitchenMemory::ProjectStructure::APP_CONFIGURATIONS.map do |name|
        "\t\t\t\t#{@project_configuration_ids.fetch(name)} /* #{name} configuration for PBXProject \"KitchenMemory\" */,\n"
      end.join
      project_configuration_list = <<~LIST
		#{@project_configuration_list_id} /* Build configuration list for PBXProject "KitchenMemory" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
#{project_configuration_references}			);
		};
      LIST
      project_object = <<~PROJECT
		#{format('%024X', 1_150)} /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = #{@project_configuration_list_id} /* Build configuration list for PBXProject "KitchenMemory" */;
		};
      PROJECT
      file_references = KitchenMemory::ProjectStructure::APP_CONFIGURATIONS.map do |name|
        identifier = @configuration_file_ids.fetch(name)
        "\t\t#{identifier} /* #{name}.xcconfig */ = {isa = PBXFileReference; path = #{name}.xcconfig;};\n"
      end

      (
        target_objects + group_objects + exception_objects + prebuild_phase_objects +
          source_phase_objects + configuration_objects +
          configuration_list_objects + project_configuration_objects +
          [project_configuration_list, project_object] + file_references
      ).join
    end

    def configuration_settings(target_name, configuration_name)
      platforms = KitchenMemory::ProjectStructure::TARGET_PLATFORMS.fetch(target_name).join(" ")
      lines = ["\t\t\t\tSUPPORTED_PLATFORMS = \"#{platforms}\";\n"]
      if target_name == "KitchenMemoryIOS"
        KitchenMemory::ProjectStructure::IOS_COMPATIBILITY_EXCLUSIONS.each do |setting, value|
          lines << "\t\t\t\t#{setting} = #{value};\n"
        end
      end
      if target_name == "KitchenMemoryUITests"
        KitchenMemory::ProjectStructure::UI_TEST_HOSTS.each do |setting, value|
          lines << "\t\t\t\t\"#{setting}\" = \"#{value}\";\n"
        end
      end
      contract = KitchenMemory::ProjectStructure::APP_FILE_CONTRACTS[target_name]
      if contract
        lines << "\t\t\t\tINFOPLIST_FILE = #{contract[:info_plist]};\n"
        entitlement_path = if %w[Testing ProductionTesting].include?(configuration_name)
                             contract[:testing_entitlements]
                           else
                             contract[:production_entitlements]
                           end
        contract[:entitlement_keys].each do |setting|
          lines << "\t\t\t\t\"#{setting}\" = \"#{entitlement_path}\";\n"
        end
        bundle_identifier = KitchenMemory::ProjectStructure::APP_BUNDLE_IDENTIFIERS.fetch(
          configuration_name,
          KitchenMemory::ProjectStructure::PRODUCTION_BUNDLE_IDENTIFIER
        )
        lines << "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = #{bundle_identifier};\n"
      end
      lines.join
    end

    def build_plans
      KitchenMemory::ProjectStructure::PLANS.each_with_object({}) do |(filename, target_names), result|
        policy = KitchenMemory::ProjectStructure::PLAN_POLICIES.fetch(filename)
        result[filename] = JSON.pretty_generate(
          "configurations" => [
            {
              "id" => "00000000-0000-0000-0000-000000000000",
              "name" => policy[:configuration],
              "options" => {}
            }
          ],
          "defaultOptions" => {
            "performanceAntipatternCheckerEnabled" => true,
            "targetForVariableExpansion" => {
              "containerPath" => "container:KitchenMemory.xcodeproj",
              "identifier" => @target_ids.fetch(policy[:variable_expansion_target]),
              "name" => policy[:variable_expansion_target]
            }
          },
          "testTargets" => target_names.map do |target_name|
            {
              "parallelizable" => true,
              "target" => {
                "containerPath" => "container:KitchenMemory.xcodeproj",
                "identifier" => @target_ids.fetch(target_name),
                "name" => target_name
              }
            }
          end,
          "version" => 1
        )
      end
    end

    def build_schemes
      KitchenMemory::ProjectStructure::SCHEMES.each_with_object({}) do |(name, expectation), result|
        if expectation[:automatic_plan]
          build_entries = expectation.fetch(:build_targets).map do |target_name|
            product_attributes = if target_name == "KitchenKit"
                                   {
                                     "buildForTesting" => "YES",
                                     "buildForRunning" => "YES",
                                     "buildForProfiling" => "YES",
                                     "buildForArchiving" => "YES",
                                     "buildForAnalyzing" => "YES"
                                   }
                                 else
                                   {
                                     "buildForTesting" => "YES",
                                     "buildForRunning" => "NO",
                                     "buildForProfiling" => "NO",
                                     "buildForArchiving" => "NO",
                                     "buildForAnalyzing" => "YES"
                                   }
                                 end
            attributes = product_attributes.map { |key, value| %(#{key}="#{value}") }.join("\n")
            <<~ENTRY
              <BuildActionEntry #{attributes}>
                <BuildableReference
                  BlueprintIdentifier="#{@target_ids.fetch(target_name)}"
                  BlueprintName="#{target_name}"
                  ReferencedContainer="container:KitchenMemory.xcodeproj"/>
              </BuildActionEntry>
            ENTRY
          end.join
          testables = expectation.fetch(:test_targets).map do |target_name|
            <<~TESTABLE
              <TestableReference skipped="NO">
                <BuildableReference
                  BlueprintIdentifier="#{@target_ids.fetch(target_name)}"
                  BlueprintName="#{target_name}"
                  ReferencedContainer="container:KitchenMemory.xcodeproj"/>
              </TestableReference>
            TESTABLE
          end.join
          result["#{name}.xcscheme"] = <<~SCHEME
            <?xml version="1.0" encoding="UTF-8"?>
            <Scheme>
              <BuildAction>
                <BuildActionEntries>
                  #{build_entries}
                </BuildActionEntries>
              </BuildAction>
              <TestAction buildConfiguration="Testing" shouldAutocreateTestPlan="YES">
                <Testables>
                  #{testables}
                </Testables>
              </TestAction>
              <LaunchAction buildConfiguration="Debug"/>
              <ProfileAction buildConfiguration="Release"/>
              <AnalyzeAction buildConfiguration="Testing"/>
              <ArchiveAction buildConfiguration="Production"/>
            </Scheme>
          SCHEME
          next
        end

        if expectation[:core]
          plan = expectation.fetch(:plan)
          build_entries = expectation.fetch(:build_targets).map do |target_name|
            <<~ENTRY
              <BuildActionEntry
                buildForTesting="YES"
                buildForRunning="NO"
                buildForProfiling="NO"
                buildForArchiving="NO"
                buildForAnalyzing="YES">
                <BuildableReference
                  BlueprintIdentifier="#{@target_ids.fetch(target_name)}"
                  BlueprintName="#{target_name}"
                  ReferencedContainer="container:KitchenMemory.xcodeproj"/>
              </BuildActionEntry>
            ENTRY
          end.join
          testables = KitchenMemory::ProjectStructure::PLANS.fetch(plan).map do |target_name|
            <<~TESTABLE
              <TestableReference skipped="NO">
                <BuildableReference
                  BlueprintIdentifier="#{@target_ids.fetch(target_name)}"
                  BlueprintName="#{target_name}"
                  ReferencedContainer="container:KitchenMemory.xcodeproj"/>
              </TestableReference>
            TESTABLE
          end.join
          result["#{name}.xcscheme"] = <<~SCHEME
            <?xml version="1.0" encoding="UTF-8"?>
            <Scheme>
              <BuildAction>
                <BuildActionEntries>
                  #{build_entries}
                </BuildActionEntries>
              </BuildAction>
              <TestAction buildConfiguration="Testing">
                <TestPlans>
                  <TestPlanReference reference="container:#{plan}" default="YES"/>
                </TestPlans>
                <Testables>
                  #{testables}
                </Testables>
              </TestAction>
              <AnalyzeAction buildConfiguration="Testing"/>
            </Scheme>
          SCHEME
          next
        end

        app = expectation.fetch(:app)
        plan = expectation.fetch(:plan)
        action_configurations = KitchenMemory::ProjectStructure::SCHEME_ACTION_CONFIGURATIONS.fetch(name)
        archive = "YES"
        profile = "YES"
        testables = expectation.fetch(
          :scheme_test_targets,
          KitchenMemory::ProjectStructure::PLANS.fetch(plan)
        ).map do |target_name|
          <<~TESTABLE
            <TestableReference skipped="NO">
              <BuildableReference
                BlueprintIdentifier="#{@target_ids.fetch(target_name)}"
                BlueprintName="#{target_name}"
                ReferencedContainer="container:KitchenMemory.xcodeproj"/>
            </TestableReference>
          TESTABLE
        end.join
        result["#{name}.xcscheme"] = <<~SCHEME
          <?xml version="1.0" encoding="UTF-8"?>
          <Scheme>
            <BuildAction>
              <BuildActionEntries>
                <BuildActionEntry
                  buildForTesting="YES"
                  buildForRunning="YES"
                  buildForProfiling="#{profile}"
                  buildForArchiving="#{archive}"
                  buildForAnalyzing="YES">
                  <BuildableReference
                    BlueprintIdentifier="#{@target_ids.fetch(app)}"
                    BlueprintName="#{app}"
                    ReferencedContainer="container:KitchenMemory.xcodeproj"/>
                </BuildActionEntry>
              </BuildActionEntries>
            </BuildAction>
            <TestAction buildConfiguration="#{action_configurations.fetch('TestAction')}">
              <TestPlans>
                <TestPlanReference reference="container:#{plan}" default="YES"/>
              </TestPlans>
              <Testables>
                #{testables}
              </Testables>
            </TestAction>
            <LaunchAction buildConfiguration="#{action_configurations.fetch('LaunchAction')}">
              <BuildableProductRunnable>
                <BuildableReference
                  BlueprintIdentifier="#{@target_ids.fetch(app)}"
                  BlueprintName="#{app}"
                  ReferencedContainer="container:KitchenMemory.xcodeproj"/>
              </BuildableProductRunnable>
            </LaunchAction>
            <ProfileAction buildConfiguration="#{action_configurations.fetch('ProfileAction')}">
              <BuildableProductRunnable>
                <BuildableReference
                  BlueprintIdentifier="#{@target_ids.fetch(app)}"
                  BlueprintName="#{app}"
                  ReferencedContainer="container:KitchenMemory.xcodeproj"/>
              </BuildableProductRunnable>
            </ProfileAction>
            <AnalyzeAction buildConfiguration="#{action_configurations.fetch('AnalyzeAction')}"/>
            <ArchiveAction buildConfiguration="#{action_configurations.fetch('ArchiveAction')}"/>
          </Scheme>
        SCHEME
      end
    end
  end

  def test_valid_native_project_structure_passes_with_discovered_identifiers
    fixture = Fixture.new

    result = validate(fixture)

    assert_equal 7, result[:target_count]
    assert_equal 3, result[:scheme_count]
    assert_equal 2, result[:plan_count]
    expected_core_groups = {
      "KitchenKit" => ["KitchenKit"],
      "KitchenKitTests" => ["KitchenKitTests"]
    }
    actual_core_groups = expected_core_groups.keys.to_h do |target_name|
      [
        target_name,
        KitchenMemory::ProjectStructure::SYNCHRONIZED_GROUPS.fetch(target_name)
      ]
    end
    assert_equal expected_core_groups, actual_core_groups
  end

  def test_allows_synchronized_navigator_group_without_target_membership
    fixture = Fixture.new
    fixture.project << <<~GROUP
		FFFFFFFFFFFFFFFFFFFFFFFF /* docs */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = docs;
		};
    GROUP

    result = validate(fixture)

    assert_equal 7, result[:target_count]
  end

  def test_rejects_missing_or_unexpected_native_target
    fixture = Fixture.new
    fixture.project.sub!('name = "KitchenKit";', 'name = "OrphanedKit";')

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "native targets"
    assert_includes error.message, "missing: KitchenKit"
    assert_includes error.message, "unexpected: OrphanedKit"
  end

  def test_rejects_wrong_target_product_type
    fixture = Fixture.new
    fixture.project.sub!(
      'productType = "com.apple.product-type.framework";',
      'productType = "com.apple.product-type.application";'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "product type"
  end

  def test_rejects_incomplete_application_configuration_matrix
    configurations = KitchenMemory::ProjectStructure::APP_CONFIGURATIONS - ["Develop"]
    fixture = Fixture.new("KitchenMemoryIOS" => configurations)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryIOS configurations"
    assert_includes error.message, "missing: Develop"
  end

  def test_rejects_incomplete_framework_configuration_matrix
    configurations = KitchenMemory::ProjectStructure::APP_CONFIGURATIONS - ["ProductionTesting"]
    fixture = Fixture.new("KitchenKit" => configurations)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenKit configurations"
    assert_includes error.message, "missing: ProductionTesting"
  end

  def test_rejects_project_configuration_using_wrong_xcconfig
    fixture = Fixture.new
    fixture.project.sub!(
      "path = Develop.xcconfig;",
      "path = Production.xcconfig;"
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "project Develop must use Develop.xcconfig"
  end

  def test_rejects_project_configuration_without_automatic_merged_binaries
    fixture = Fixture.new
    fixture.project.sub!("MERGED_BINARY_TYPE = automatic;", "MERGED_BINARY_TYPE = none;")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "project Debug must set MERGED_BINARY_TYPE to automatic"
  end

  def test_rejects_localization_contract_phase_after_product_build_phase
    fixture = Fixture.new
    target_name = "KitchenMemoryIOSTests"
    prebuild = "#{fixture.prebuild_phase_ids.fetch(target_name)} " \
      "/* Embed Localization Catalog Contract */"
    sources = "#{fixture.source_phase_ids.fetch(target_name)} /* Sources */"
    fixture.project.sub!("#{prebuild},\n#{sources},", "#{sources},\n#{prebuild},")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryIOSTests must run"
    assert_includes error.message, "before every product build phase"
  end

  def test_rejects_wrong_platform_info_plist
    fixture = Fixture.new
    fixture.project.sub!(
      "INFOPLIST_FILE = KitchenMemoryIOS/Info.plist;",
      "INFOPLIST_FILE = KitchenMemoryMacOS/Info.plist;"
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryIOS Debug must use KitchenMemoryIOS/Info.plist"
  end

  def test_rejects_wrong_testing_entitlements
    fixture = Fixture.new
    fixture.project.sub!(
      '"CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]" = "KitchenMemoryIOS/KitchenMemory-Testing.entitlements";',
      '"CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]" = "KitchenMemoryIOS/KitchenMemory.entitlements";'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryIOS Testing must use only"
    assert_includes error.message, "KitchenMemory-Testing.entitlements"
  end

  def test_rejects_develop_configuration_using_production_bundle_identifier
    fixture = Fixture.new
    fixture.project.sub!(
      "PRODUCT_BUNDLE_IDENTIFIER = net.ctwelve.dev.KitchenMemory;",
      "PRODUCT_BUNDLE_IDENTIFIER = net.ctwelve.KitchenMemory;"
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "Develop must use bundle identifier net.ctwelve.dev.KitchenMemory"
  end

  def test_rejects_target_missing_synchronized_source_group
    fixture = Fixture.new
    fixture.project.sub!(/^\s*[0-9A-F]+ \/\* KitchenMemoryIOS \*\/,[\t ]*\n/, "")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryIOS synchronized groups"
    assert_includes error.message, "missing: KitchenMemoryIOS"
  end

  def test_rejects_platform_group_without_info_plist_exception
    fixture = Fixture.new
    fixture.project.sub!(/^\s*[0-9A-F]+ \/\* Info.plist exception for KitchenMemoryIOS \*\/,[\t ]*\n/, "")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryIOS must contain exactly one Info.plist membership exception"
  end

  def test_rejects_non_native_application_platform
    fixture = Fixture.new
    fixture.project.sub!(
      'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
      'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "must support only iphoneos, iphonesimulator"
  end

  def test_rejects_missing_ios_compatibility_exclusion
    fixture = Fixture.new
    fixture.project.sub!("\t\t\t\tSUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;\n", "")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"
  end

  def test_rejects_incomplete_sdk_conditional_ui_test_host_map
    fixture = Fixture.new
    fixture.project.sub!(
      '"TEST_TARGET_NAME[sdk=macosx*]" = "KitchenMemoryMacOS";',
      '"TEST_TARGET_NAME[sdk=macosx*]" = "KitchenMemoryIOS";'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "map native SDK hosts"
  end

  def test_rejects_host_settings_on_a_core_test_target
    fixture = Fixture.new
    platforms = 'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";'
    insertion_index = fixture.project.rindex(platforms) + platforms.length
    fixture.project.insert(insertion_index, "\n\t\t\t\tTEST_HOST = KitchenMemory.app;")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "must remain unhosted"
  end

  def test_rejects_unexpected_shared_scheme
    fixture = Fixture.new
    fixture.schemes["Obsolete.xcscheme"] = "<Scheme/>"

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "shared schemes"
    assert_includes error.message, "unexpected: Obsolete"
  end

  def test_rejects_platform_plan_without_ui_smoke_target
    fixture = Fixture.new
    plan = JSON.parse(fixture.plans.fetch("KitchenMemoryMacOS.xctestplan"))
    plan["testTargets"].reject! do |entry|
      entry.dig("target", "name") == "KitchenMemoryUITests"
    end
    fixture.plans["KitchenMemoryMacOS.xctestplan"] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryMacOS.xctestplan test targets"
    assert_includes error.message, "missing: KitchenMemoryUITests"
  end

  def test_rejects_platform_plan_with_wrong_variable_expansion_target
    fixture = Fixture.new
    plan = JSON.parse(fixture.plans.fetch("KitchenMemoryIOS.xctestplan"))
    plan["defaultOptions"]["targetForVariableExpansion"]["name"] = "KitchenMemoryMacOS"
    fixture.plans["KitchenMemoryIOS.xctestplan"] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "expand variables against KitchenMemoryIOS"
  end

  def test_rejects_platform_scheme_using_debug_for_tests
    fixture = Fixture.new
    fixture.schemes["KitchenMemoryMacOS.xcscheme"] = fixture.schemes.fetch(
      "KitchenMemoryMacOS.xcscheme"
    ).sub('TestAction buildConfiguration="Testing"', 'TestAction buildConfiguration="Debug"')

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryMacOS TestAction must use Testing"
  end

  def test_rejects_saved_plan_for_kitchenkit_scheme
    fixture = Fixture.new
    fixture.schemes["KitchenKit.xcscheme"] = fixture.schemes.fetch("KitchenKit.xcscheme").sub(
      '<Testables>',
      '<TestPlans><TestPlanReference reference="container:KitchenKit.xctestplan"/></TestPlans><Testables>'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "automatic test plan"
  end

  def test_rejects_disabled_automatic_kitchenkit_plan
    fixture = Fixture.new
    fixture.schemes["KitchenKit.xcscheme"] = fixture.schemes.fetch("KitchenKit.xcscheme").sub(
      'shouldAutocreateTestPlan="YES"',
      'shouldAutocreateTestPlan="NO"'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "automatically create its test plan"
  end

  def test_rejects_runnable_product_in_kitchenkit_launch_action
    fixture = Fixture.new
    runnable = <<~RUNNABLE.chomp
      <BuildableProductRunnable>
        <BuildableReference
          BlueprintIdentifier="#{fixture.target_ids.fetch('KitchenKit')}"
          BlueprintName="KitchenKit"
          ReferencedContainer="container:KitchenMemory.xcodeproj"/>
      </BuildableProductRunnable>
    RUNNABLE
    fixture.schemes["KitchenKit.xcscheme"] = fixture.schemes.fetch("KitchenKit.xcscheme").sub(
      '<LaunchAction buildConfiguration="Debug"/>',
      %(<LaunchAction buildConfiguration="Debug">#{runnable}</LaunchAction>)
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "must not declare a runnable product"
  end

  private

  def validate(fixture)
    KitchenMemory::ProjectStructure.validate(
      project_contents: fixture.project,
      schemes: fixture.schemes,
      plans: fixture.plans
    )
  end

  def assert_contract_error(&block)
    assert_raises(KitchenMemory::ProjectStructure::ContractError, &block)
  end
end
