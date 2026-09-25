#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT
require 'minitest/autorun'
require_relative '../ci-evidence'

class CIEvidenceTest < Minitest::Test
  C = KitchenMemory::CIEvidence

  def test_draft_push_is_fast_but_ready_candidate_and_retarget_require_validation
    refute C.full_candidate?('pull_request', {'action' => 'synchronize', 'pull_request' => {'draft' => true}})
    assert C.full_candidate?('pull_request', {'action' => 'ready_for_review', 'pull_request' => {'draft' => false}})
    assert C.full_candidate?('pull_request', {'action' => 'edited', 'pull_request' => {'draft' => false}})
    assert C.full_candidate?('pull_request', {'action' => 'edited', 'changes' => {'base' => {}}, 'pull_request' => {'draft' => false}})
    assert C.full_candidate?('merge_group', {})
    assert C.full_candidate?('push', {})
  end

  def run_record
    {'id' => 42, 'run_attempt' => 2, 'status' => 'completed', 'conclusion' => 'success',
     'path' => '.github/workflows/development.yml', 'event' => 'pull_request',
     'repository' => {'full_name' => 'owner/repo'}, 'head_repository' => {'full_name' => 'owner/repo'}}
  end

  def proof
    {'schema' => 1, 'policy' => C::POLICY, 'validation' => 'full', 'tree' => 'a' * 40,
     'commit' => 'b' * 40, 'run_id' => 42, 'run_attempt' => 2}
  end

  def test_only_successful_same_repository_development_runs_are_eligible
    assert C.eligible_run?(run_record, 'owner/repo')
    [{'status' => 'in_progress'}, {'conclusion' => 'failure'}, {'conclusion' => 'cancelled'},
     {'path' => '.github/workflows/other.yml'}, {'event' => 'pull_request_target'},
     {'head_repository' => {'full_name' => 'fork/repo'}}].each do |change|
      refute C.eligible_run?(run_record.merge(change), 'owner/repo')
    end
  end

  def test_reuse_requires_exact_tree_policy_and_current_attempt
    assert C.matching?(proof, run_record, 'a' * 40)
    [{'tree' => 'c' * 40}, {'policy' => 'old-xcode'}, {'run_id' => 43},
     {'run_attempt' => 1}, {'validation' => 'fast'}, {'schema' => 0}].each do |change|
      refute C.matching?(proof.merge(change), run_record, 'a' * 40)
    end
  end

  def test_round_trip_record_uses_actual_git_tree
    Dir.mktmpdir do |dir|
      %w[GITHUB_RUN_ID GITHUB_RUN_ATTEMPT].each { |key| ENV[key] = {'GITHUB_RUN_ID' => '42', 'GITHUB_RUN_ATTEMPT' => '2'}.fetch(key) }
      file = File.join(dir, 'validation.json')
      C.record(file)
      value = JSON.parse(File.read(file))
      tree = C.capture('git', 'rev-parse', 'HEAD^{tree}')
      assert C.matching?(value, run_record, tree)
      refute C.matching?(value, run_record, '0' * 40)
    ensure
      ENV.delete('GITHUB_RUN_ID')
      ENV.delete('GITHUB_RUN_ATTEMPT')
    end
  end
end
