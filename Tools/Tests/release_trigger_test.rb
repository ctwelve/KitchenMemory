# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT
require 'minitest/autorun'
require_relative '../resolve-cloud-release'

class ReleaseTriggerTest < Minitest::Test
  def event
    {'state' => 'success', 'context' => 'KitchenMemory | Tag to release/',
     'sha' => 'a' * 40,
     'target_url' => 'https://appstoreconnect.apple.com/teams/team/apps/app/ci/builds/82ba807e-0f39-4fcc-903e-af2e8dcfdbfa'}
  end

  def resolve(payload = event, tags = ['release/0.3.5'])
    KitchenMemory::ReleaseTrigger.resolve('status', payload, requested_tag: nil,
      tags_for_commit: ->(sha) { assert_equal 'a' * 40, sha; tags })
  end

  def test_completion_resolves_exact_tag_and_attempt
    assert_equal ['release/0.3.5', '82ba807e-0f39-4fcc-903e-af2e8dcfdbfa'], resolve
  end

  def test_rejects_unrelated_failed_malformed_and_ambiguous_events
    [{'state' => 'pending'}, {'state' => 'failure'}, {'context' => 'Other workflow'},
     {'sha' => '--bad'}, {'target_url' => 'https://example.com/ci/builds/82ba807e-0f39-4fcc-903e-af2e8dcfdbfa'},
     {'target_url' => event['target_url'] + '/action/test'}].each do |change|
      assert_raises(RuntimeError) { resolve(event.merge(change)) }
    end
    [[], ['release/0.3.4', 'release/0.3.5']].each do |tags|
      assert_raises(RuntimeError) { resolve(event, tags) }
    end
  end

  def test_manual_retry_validates_tag_without_needing_status_event
    resolver = ->(_) { flunk 'Manual dispatch should not resolve status SHA' }
    assert_equal ['release/0.3.5', nil], KitchenMemory::ReleaseTrigger.resolve(
      'workflow_dispatch', {}, requested_tag: 'release/0.3.5', tags_for_commit: resolver)
    assert_raises(RuntimeError) do
      KitchenMemory::ReleaseTrigger.resolve('workflow_dispatch', {},
        requested_tag: "release/0.3.5\nINJECTED=true", tags_for_commit: resolver)
    end
  end
end
