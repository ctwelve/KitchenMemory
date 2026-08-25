#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: GPL-3.0-only

require "minitest/autorun"
require_relative "../check-project-structure"

class CheckProjectStructureTest < Minitest::Test
  class Fixture
    attr_reader :plans, :project, :schemes, :target_ids

    def initialize(configuration_overrides = {})
      target_names = KitchenMemory::ProjectStructure::TARGET_TYPES.keys
      group_paths = KitchenMemory::ProjectStructure::SYNCHRONIZED_GROUPS.values.flatten.uniq
      @target_ids = identifier_map(target_names, 100)
      @configuration_list_ids = identifier_map(target_names, 1_000)
      @group_ids = identifier_map(group_paths, 300)
      @exception_ids = {
        "KitchenMemoryIOS" => format("%024X", 400),
        "KitchenMemoryMac" => format("%024X", 401)
      }
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
        <<~TARGET
		#{@target_ids.fetch(name)} /* #{name} */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = #{@configuration_list_ids.fetch(name)} /* Build configuration list for PBXNativeTarget "#{name}" */;
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
        target_objects + group_objects + exception_objects + configuration_objects +
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
            "codeCoverage" => policy[:code_coverage],
            "commandLineArgumentEntries" => [
              { "argument" => "--unit-testing" }
            ]
          },
          "testTargets" => target_names.map do |target_name|
            {
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
        app = expectation.fetch(:app)
        plan = expectation.fetch(:plan)
        flavor = name.split.last
        action_configurations = KitchenMemory::ProjectStructure::SCHEME_ACTION_CONFIGURATIONS.fetch(flavor)
        archive = flavor == "Production" ? "YES" : "NO"
        profile = "YES"
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

    assert_equal 9, result[:target_count]
    assert_equal 6, result[:scheme_count]
    assert_equal 4, result[:plan_count]
  end

  def test_rejects_missing_or_unexpected_native_target
    fixture = Fixture.new
    fixture.project.sub!('name = "KitchenMemoryLogic";', 'name = "OrphanedLogic";')

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "native targets"
    assert_includes error.message, "missing: KitchenMemoryLogic"
    assert_includes error.message, "unexpected: OrphanedLogic"
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
    fixture = Fixture.new("KitchenMemoryLogic" => configurations)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemoryLogic configurations"
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

  def test_rejects_wrong_platform_info_plist
    fixture = Fixture.new
    fixture.project.sub!(
      "INFOPLIST_FILE = KitchenMemoryIOS/Info.plist;",
      "INFOPLIST_FILE = KitchenMemoryMac/Info.plist;"
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

  def test_rejects_missing_test_plan_file
    fixture = Fixture.new
    fixture.plans.delete("KitchenMemoryIOSTesting.xctestplan")

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "test plans"
    assert_includes error.message, "missing: KitchenMemoryIOSTesting.xctestplan"
  end

  def test_rejects_wrong_test_plan_configuration_policy
    fixture = Fixture.new
    filename = "KitchenMemoryIOSProduction.xctestplan"
    plan = JSON.parse(fixture.plans.fetch(filename))
    plan.fetch("configurations") << {
      "id" => "11111111-1111-1111-1111-111111111111",
      "name" => "Extra Validation",
      "options" => {}
    }
    fixture.plans[filename] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "must contain only configuration"
  end

  def test_rejects_wrong_test_plan_coverage_policy
    fixture = Fixture.new
    filename = "KitchenMemoryMacTesting.xctestplan"
    plan = JSON.parse(fixture.plans.fetch(filename))
    plan.fetch("defaultOptions")["codeCoverage"] = false
    fixture.plans[filename] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "codeCoverage must be true"
  end

  def test_rejects_per_configuration_test_plan_overrides
    fixture = Fixture.new
    filename = "KitchenMemoryIOSTesting.xctestplan"
    plan = JSON.parse(fixture.plans.fetch(filename))
    plan.fetch("configurations").first["options"] = { "codeCoverage" => false }
    fixture.plans[filename] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "configuration options must remain empty"
  end

  def test_rejects_extra_default_test_plan_argument
    fixture = Fixture.new
    filename = "KitchenMemoryMacProduction.xctestplan"
    plan = JSON.parse(fixture.plans.fetch(filename))
    plan.fetch("defaultOptions").fetch("commandLineArgumentEntries") << {
      "argument" => "--unexpected"
    }
    fixture.plans[filename] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "must pass only --unit-testing"
  end

  def test_rejects_scheme_pointing_to_wrong_test_plan
    fixture = Fixture.new
    scheme_name = "KitchenMemory iOS Development.xcscheme"
    fixture.schemes[scheme_name] = fixture.schemes.fetch(scheme_name).sub(
      "KitchenMemoryIOSTesting.xctestplan",
      "KitchenMemoryIOSProduction.xctestplan"
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "KitchenMemory iOS Development must reference only"
  end

  def test_rejects_development_scheme_that_can_archive
    fixture = Fixture.new
    scheme_name = "KitchenMemory iOS Development.xcscheme"
    fixture.schemes[scheme_name] = fixture.schemes.fetch(scheme_name).sub(
      'buildForArchiving="NO"',
      'buildForArchiving="YES"'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "buildForArchiving to NO"
  end

  def test_rejects_incomplete_scheme_build_action_flags
    fixture = Fixture.new
    scheme_name = "KitchenMemory macOS Production.xcscheme"
    fixture.schemes[scheme_name] = fixture.schemes.fetch(scheme_name).sub(
      'buildForTesting="YES"',
      'buildForTesting="NO"'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "buildForTesting to YES"
  end

  def test_rejects_scheme_action_using_wrong_configuration
    fixture = Fixture.new
    scheme_name = "KitchenMemory iOS Production.xcscheme"
    fixture.schemes[scheme_name] = fixture.schemes.fetch(scheme_name).sub(
      '<TestAction buildConfiguration="ProductionTesting">',
      '<TestAction buildConfiguration="Production">'
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "TestAction must use ProductionTesting"
  end

  def test_rejects_scheme_launching_other_platform_application
    fixture = Fixture.new
    scheme_name = "KitchenMemory iOS Development.xcscheme"
    document = REXML::Document.new(fixture.schemes.fetch(scheme_name))
    reference = REXML::XPath.first(
      document,
      "/Scheme/LaunchAction/BuildableProductRunnable/BuildableReference"
    )
    reference.attributes["BlueprintIdentifier"] = fixture.target_ids.fetch("KitchenMemoryMacOS")
    reference.attributes["BlueprintName"] = "KitchenMemoryMacOS"
    updated_scheme = String.new
    document.write(updated_scheme)
    fixture.schemes[scheme_name] = updated_scheme

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "LaunchAction must run only KitchenMemoryIOS"
  end

  def test_rejects_plan_target_identifier_that_does_not_exist
    fixture = Fixture.new
    filename = "KitchenMemoryMacTesting.xctestplan"
    plan = JSON.parse(fixture.plans.fetch(filename))
    plan.fetch("testTargets").first.fetch("target")["identifier"] = "FFFFFFFFFFFFFFFFFFFFFFFF"
    fixture.plans[filename] = JSON.generate(plan)

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "references missing target identifier"
  end

  def test_rejects_scheme_buildable_identifier_that_does_not_exist
    fixture = Fixture.new
    scheme_name = "KitchenMemory macOS Testing.xcscheme"
    valid_identifier = fixture.target_ids.fetch("KitchenMemoryMacOS")
    fixture.schemes[scheme_name] = fixture.schemes.fetch(scheme_name).sub(
      valid_identifier,
      "EEEEEEEEEEEEEEEEEEEEEEEE"
    )

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "references missing target identifier"
  end

  def test_rejects_unexpected_shared_scheme
    fixture = Fixture.new
    fixture.schemes["Obsolete.xcscheme"] = fixture.schemes.values.first

    error = assert_contract_error { validate(fixture) }

    assert_includes error.message, "shared schemes"
    assert_includes error.message, "unexpected: Obsolete"
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
