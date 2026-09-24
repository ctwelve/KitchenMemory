#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'

module KitchenMemory
  module CI
    LANES = %w[mac-tests ios-tests core mac-build ios-build].freeze
    module_function

    def simulator_destination
      output, status = Open3.capture2('xcrun', 'simctl', 'list', 'devices', 'available', '--json')
      raise 'Cannot enumerate iOS simulators' unless status.success?
      devices = JSON.parse(output).fetch('devices')
      candidates = devices.flat_map do |runtime, entries|
        next [] unless runtime.match?(/\.iOS-\d/)
        version = runtime.split('iOS-').last.split('-').map(&:to_i)
        next [] if (version <=> [26, 5]) == -1
        entries.select { |device| device.fetch('isAvailable', false) && device.fetch('name').start_with?('iPhone') }
          .map { |device| [version, device.fetch('name'), device.fetch('udid')] }
      end
      raise 'Install an iOS 26.5 or newer iPhone simulator' if candidates.empty?
      "platform=iOS Simulator,id=#{candidates.sort.last.last}"
    end

    def commands(lane, output, destination:, identity: nil)
      raise "Unknown CI lane: #{lane}" unless LANES.include?(lane)
      framework = lane == 'core'
      scheme = framework ? 'KitchenKit' : 'KitchenMemory'
      derived = File.join(output, 'DerivedData')
      common = ['xcodebuild', '-project', 'KitchenMemory.xcodeproj', '-scheme', scheme,
                '-destination', destination, '-derivedDataPath', derived,
                '-onlyUsePackageVersionsFromResolvedFile', '-skipPackagePluginValidation', '-skipMacroValidation']
      if lane.end_with?('-build')
        return [
          ['analyze', common + ['analyze', '-configuration', 'Testing', 'CODE_SIGNING_ALLOWED=NO']],
          ['production', common + ['build', '-configuration', 'Production', 'CODE_SIGNING_ALLOWED=NO']]
        ]
      end
      if lane == 'mac-tests'
        raise 'A dedicated development signing identity is required for hosted macOS tests' if identity.to_s.empty?
        signing = ["CODE_SIGN_IDENTITY=#{identity}", 'CODE_SIGN_STYLE=Manual']
      elsif framework
        signing = ['CODE_SIGNING_ALLOWED=NO']
      else
        signing = ['CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_REQUIRED=NO']
      end
      plan = framework ? 'KitchenKit' : 'KitchenMemory'
      testing = common + ['-testPlan', plan, '-enableCodeCoverage', framework ? 'YES' : 'NO']
      result = File.join(output, 'Tests.xcresult')
      jobs = [
        ['build', testing + ['build-for-testing', '-resultBundlePath', File.join(output, 'Build.xcresult')] + signing],
        ['test', testing + ['test-without-building', '-resultBundlePath', result]]
      ]
      if lane == 'mac-tests'
        jobs.insert(1, ['signing', [RbConfig.ruby, 'Tools/check-ci-signing.rb', File.join(derived, 'Build/Products/Testing')]])
      end
      if framework
        jobs << ['coverage', ['sh', 'Tools/check-core-framework-coverage.sh', result]]
        jobs << ['interface', [RbConfig.ruby, 'Tools/check-ingredient-authoring-interface.rb', File.join(derived, 'Build/Products/Testing')]]
      end
      jobs
    end

    def run(jobs, output)
      jobs.each do |name, command|
        log = File.join(output, "#{name}.log")
        File.open(log, 'w') do |file|
          file.sync = true
          file.puts(command.inspect)
          Open3.popen2e(*command) do |input, stream, waiter|
            input.close
            stream.each_line { |line| print line; file.write(line) }
            raise "#{name} failed; see #{log}" unless waiter.value.success?
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'Usage: ruby Tools/ci.rb LANE NEW_OUTPUT_DIRECTORY' unless ARGV.length == 2
  # Local native application testing belongs to Xcode's Test action; see docs/agents/xcode.md.
  abort 'Run native app tests through Xcode locally; this driver is for hosted CI' unless ENV['GITHUB_ACTIONS'] == 'true'
  $stdout.sync = true
  Dir.chdir(File.expand_path('..', __dir__))
  lane, output = ARGV
  output = File.expand_path(output)
  abort 'Use a new output directory for each CI lane' if File.exist?(output)
  destination = if lane == 'ios-tests'
                  KitchenMemory::CI.simulator_destination
                elsif lane == 'ios-build'
                  'generic/platform=iOS'
                else
                  'platform=macOS'
                end
  jobs = KitchenMemory::CI.commands(lane, output, destination: destination,
                                    identity: ENV['KITCHEN_MEMORY_SIGNING_IDENTITY'])
  FileUtils.mkdir_p(output)
  KitchenMemory::CI.run(jobs, output)
end
