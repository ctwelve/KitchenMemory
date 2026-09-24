#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require_relative '../prepare-release-collection'

class ReleaseCollectionTest < Minitest::Test
  def setup
    @old_repo = ENV['GH_REPO']
    ENV['GH_REPO'] = 'owner/project'
    @sha = 'a' * 40
    @run = {'id' => 42, 'head_sha' => @sha, 'event' => 'push', 'head_branch' => 'main',
            'status' => 'completed', 'conclusion' => 'success'}
    @releases = []
    @calls = []
  end

  def teardown
    ENV['GH_REPO'] = @old_repo
  end

  def prepare(directory = nil)
    fake = lambda do |*args|
      @calls << args
      if args.first == 'git'
        @sha
      elsif args.include?('api')
        args.last.include?('/runs?') ? JSON.generate('workflow_runs' => [@run]) : JSON.generate([@releases])
      elsif args[1..2] == %w[release download]
        File.write(File.join(args.last, args[args.index('--pattern') + 1]), @download)
        ''
      else
        ''
      end
    end
    KitchenMemory::ReleaseCollection.stub(:capture, fake) do
      KitchenMemory::ReleaseCollection.prepare('release/1.2.3', directory)
    end
  end

  def with_artifacts
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'KitchenMemory-1.2.3-macOS.zip'), 'verified archive')
      File.write(File.join(directory, 'SHA256SUMS'), 'checksum')
      File.write(File.join(directory, 'release-evidence.json'), JSON.generate(
        tag: 'release/1.2.3', commit: @sha, cloud_build_number: 429,
        artifact_name: 'KitchenMemory-1.2.3-macOS.zip'
      ))
      yield directory
    end
  end

  def test_rejects_failed_incomplete_and_wrong_commit_evidence
    [{'conclusion' => 'failure'}, {'status' => 'in_progress'}, {'head_sha' => 'b' * 40},
     {'event' => 'pull_request'}, {'head_branch' => 'release-eng/example'}].each do |change|
      original = @run
      @run = original.merge(change)
      assert_raises(RuntimeError) { prepare }
      @run = original
    end
    refute @calls.any? { |args| args[1] == 'release' }
  end

  def test_published_release_is_never_modified
    @releases = [{'tag_name' => 'release/1.2.3', 'draft' => false}]
    assert_raises(RuntimeError) { prepare }
    refute @calls.any? { |args| args[1] == 'release' }
  end

  def test_new_release_is_draft_and_uploads_all_three_assets
    with_artifacts { |directory| prepare(directory) }
    creation = @calls.find { |args| args[1..2] == %w[release create] }
    assert_includes creation, '--draft'
    assert_includes creation, '--verify-tag'
    assert_equal 3, @calls.count { |args| args[1..2] == %w[release upload] }
  end

  def test_resume_skips_identical_asset_and_uploads_only_missing_assets
    @releases = [{'tag_name' => 'release/1.2.3', 'draft' => true,
                  'assets' => [{'name' => 'KitchenMemory-1.2.3-macOS.zip'}]}]
    @download = 'verified archive'
    with_artifacts { |directory| prepare(directory) }
    refute @calls.any? { |args| args[1..2] == %w[release create] }
    assert_equal 2, @calls.count { |args| args[1..2] == %w[release upload] }
  end

  def test_resume_refuses_to_replace_different_bytes
    @releases = [{'tag_name' => 'release/1.2.3', 'draft' => true,
                  'assets' => [{'name' => 'KitchenMemory-1.2.3-macOS.zip'}]}]
    @download = 'different archive'
    with_artifacts { |directory| assert_raises(RuntimeError) { prepare(directory) } }
    refute @calls.any? { |args| args[1..2] == %w[release upload] }
  end

  def test_mismatched_collected_commit_cannot_create_draft
    with_artifacts do |directory|
      @sha = 'b' * 40
      @run['head_sha'] = @sha
      assert_raises(RuntimeError) { prepare(directory) }
    end
    refute @calls.any? { |args| args[1] == 'release' }
  end
end
