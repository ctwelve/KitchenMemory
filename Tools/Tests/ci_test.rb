#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require 'yaml'
require_relative '../ci'

class CITest < Minitest::Test
  def commands(lane, identity: nil)
    KitchenMemory::CI.commands(lane, '/tmp/evidence', destination: 'platform=macOS', identity: identity)
  end

  def test_mac_tests_fail_without_dedicated_signing
    assert_raises(RuntimeError) { commands('mac-tests') }
    build = commands('mac-tests', identity: 'TEST-IDENTITY').first.last
    assert_includes build, 'CODE_SIGN_IDENTITY=TEST-IDENTITY'
    refute_includes build, 'CODE_SIGNING_ALLOWED=NO'
    assert_equal 'KitchenMemory', build[build.index('-testPlan') + 1]
  end

  def test_core_has_exact_coverage_and_consumer_checks_after_tests
    jobs = commands('core')
    assert_equal %w[test coverage interface], jobs.map(&:first)
    assert_includes jobs.first.last, 'test'
    refute_includes jobs.first.last, 'test-without-building'
    result = jobs.first.last[jobs.first.last.index('-resultBundlePath') + 1]
    assert_includes jobs.first.last, '-enableCodeCoverage'
    assert_equal 'YES', jobs.first.last[jobs.first.last.index('-enableCodeCoverage') + 1]
    assert_equal result, jobs[1].last.last
  end

  def test_daily_build_checks_production_without_archiving
    jobs = commands('ios-build')
    assert_equal %w[production], jobs.map(&:first)
    assert_includes jobs.last.last, 'Production'
    refute_includes jobs.flatten, 'archive'
  end

  def workflow(name)
    YAML.load_file(File.expand_path("../../.github/workflows/#{name}.yml", __dir__))
  end

  def test_every_stack_base_and_merge_queue_receive_checks
    triggers = workflow('development').fetch('on') { workflow('development').fetch(true) }
    refute triggers.fetch('pull_request').key?('branches')
    assert_includes triggers.fetch('pull_request').fetch('types'), 'edited'
    assert triggers.key?('merge_group')
    assert_equal ['main'], triggers.fetch('push').fetch('branches')
  end

  def test_aggregate_rejects_skipped_failed_and_cancelled_jobs
    job = workflow('development').fetch('jobs').fetch('required')
    assert_equal 'always()', job.fetch('if')
    assert_equal %w[decision repository build mac-tests analysis], job.fetch('needs')
    script = job.fetch('steps').first.fetch('run')
    good = {'DECISION_RESULT' => 'success', 'VALIDATION_MODE' => 'full', 'ANALYSIS_RESULT' => 'skipped', 'REPOSITORY_RESULT' => 'success', 'BUILD_RESULT' => 'success', 'MAC_TEST_RESULT' => 'success'}
    assert Open3.capture3(good, 'bash', '-c', script).last.success?
    %w[DECISION_RESULT REPOSITORY_RESULT BUILD_RESULT MAC_TEST_RESULT].product(%w[failure skipped cancelled]).each do |key, result|
      refute Open3.capture3(good.merge(key => result), 'bash', '-c', script).last.success?, "Accepted #{key}=#{result}"
    end
  end

  def test_reuse_requires_verified_source_and_skipped_native_lanes
    script = workflow('development').fetch('jobs').fetch('required').fetch('steps').first.fetch('run')
    env = {'DECISION_RESULT' => 'success', 'REPOSITORY_RESULT' => 'success',
           'VALIDATION_MODE' => 'reuse', 'SOURCE_RUN' => '42', 'ANALYSIS_RESULT' => 'skipped',
           'BUILD_RESULT' => 'skipped', 'MAC_TEST_RESULT' => 'skipped'}
    assert Open3.capture3(env, 'bash', '-c', script).last.success?
    refute Open3.capture3(env.merge('SOURCE_RUN' => ''), 'bash', '-c', script).last.success?
    refute Open3.capture3(env.merge('BUILD_RESULT' => 'failure'), 'bash', '-c', script).last.success?
  end

  def test_cloud_wait_does_not_occupy_a_mac_runner
    jobs = workflow('release').fetch('jobs')
    assert_equal 'ubuntu-latest', jobs.fetch('wait').fetch('runs-on')
    assert_equal 'wait', jobs.fetch('collect').fetch('needs')
    assert_equal 30, jobs.fetch('collect').fetch('timeout-minutes')
  end

  def test_source_policy_preserves_governed_main_and_supports_merge_queue
    script = workflow('pr-source-policy').fetch('jobs').fetch('source-branch-policy').fetch('steps').first.fetch('run')
    assert Open3.capture3({'EVENT_NAME' => 'pull_request', 'HEAD_REF' => 'release-eng/test'}, 'bash', '-c', script).last.success?
    refute Open3.capture3({'EVENT_NAME' => 'pull_request', 'HEAD_REF' => 'unreviewed'}, 'bash', '-c', script).last.success?
    assert Open3.capture3({'EVENT_NAME' => 'merge_group', 'HEAD_REF' => ''}, 'bash', '-c', script).last.success?
  end

  def test_failed_command_stops_before_dependent_checks
    Dir.mktmpdir do |output|
      marker = File.join(output, 'should-not-exist')
      jobs = [['failure', [RbConfig.ruby, '-e', 'exit 7']],
              ['later', [RbConfig.ruby, '-e', 'File.write(ARGV.first, "bad")', marker]]]
      assert_raises(RuntimeError) { KitchenMemory::CI.run(jobs, output) }
      refute File.exist?(marker)
      assert File.file?(File.join(output, 'failure.log'))
    end
  end
end
