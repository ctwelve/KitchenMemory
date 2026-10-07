#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require "json"

class CoreFrameworkCoverageTest < Minitest::Test
  # Exercise the shell gate with controlled Xcode reports, not native execution.
  # Every source must still appear in the expected target's build log.
  def with_report(covered: 10, missing_adapter: false)
    Dir.mktmpdir("coverage-contract") do |root|
      paths = %w[
        KitchenKit/Interface/Persistence/Cloud/PersonalCloudStatusMonitor.swift
        KitchenKit/Interface/Persistence/Cloud/CloudKitAccountChecker.swift
        KitchenKit/Interface/Persistence/Cloud/CloudKitKitchenOwnerIDResolver.swift
        KitchenKit/Modules/Domain/Business.swift
        KitchenKitTests/Test.swift
        Configurations/Testing.xcconfig
        KitchenMemory.xcodeproj/project.pbxproj
        KitchenMemory.xcodeproj/xcshareddata/xcschemes/KitchenKit.xcscheme
        KitchenMemory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
      ]
      paths.each do |relative|
        path = File.join(root, relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "fixture")
        File.utime(Time.at(1), Time.at(1), path)
      end
      FileUtils.mkdir_p(File.join(root, "Tools"))
      FileUtils.cp(File.expand_path("../check-core-framework-coverage.sh", __dir__), File.join(root, "Tools"))
      sources = paths.first(4)
      report = sources.each_with_index.map do |path, index|
        count = index == 3 ? covered : 0
        "#{index} /runner/repository/#{path} 1 #{count * 10}.00% (#{count}/10)"
      end.join("\n")
      File.write(File.join(root, "report"), report)
      File.write(File.join(root, "build"), JSON.generate({
        commandDetails: sources.map { |path| "/runner/repository/#{path} (in target 'KitchenKit' from project 'KitchenMemory')" }.join(" ")
      }))
      File.write(File.join(root, "xcrun"), <<~SH)
        #!/bin/sh
        case "$1 $2 $3" in
          'xcresulttool get build-results') echo '{"startTime":2}' ;;
          'xcresulttool get log') cat '#{root}/build' ;;
          'xccov view --report') cat '#{root}/report' ;;
          *) exit 99 ;;
        esac
      SH
      File.chmod(0o755, File.join(root, "xcrun"))
      FileUtils.mkdir_p(File.join(root, "Tests.xcresult"))
      File.unlink(File.join(root, sources[1])) if missing_adapter
      yield Open3.capture3({"PATH" => "#{root}:#{ENV.fetch('PATH')}"}, "sh",
                          File.join(root, "Tools/check-core-framework-coverage.sh"), File.join(root, "Tests.xcresult"))
    end
  end

  def test_moved_and_split_runtime_adapters_preserve_the_existing_exclusion
    with_report do |out, err, status|
      assert status.success?, err
      assert_includes out, "10/10 business-logic executable lines covered (30 runtime-adapter lines excluded)"
    end
  end

  def test_one_uncovered_business_line_still_fails
    with_report(covered: 9) do |_out, err, status|
      refute status.success?
      assert_includes err, "1 uncovered business-logic line(s)"
    end
  end

  def test_stale_exclusion_path_fails_explicitly
    with_report(missing_adapter: true) do |_out, err, status|
      refute status.success?
      assert_includes err, "runtime-adapter exclusion is missing"
      assert_includes err, "CloudKitAccountChecker.swift"
    end
  end
end
