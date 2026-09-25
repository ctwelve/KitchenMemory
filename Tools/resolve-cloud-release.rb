#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'json'
require 'uri'
require_relative 'prepare-release-collection'

module KitchenMemory
  module ReleaseTrigger
    module_function

    # The status is a wake-up hint, never authorization to publish. The collector
    # independently validates the configured Apple workflow, tag, SHA and attempt.
    def resolve(event_name, event, requested_tag:, tags_for_commit:)
      if event_name == 'workflow_dispatch'
        raise 'Invalid release tag' unless ReleaseVersion::TAG_PATTERN.match?(requested_tag.to_s)
        return [requested_tag, nil]
      end
      unless event_name == 'status' && event['state'] == 'success' &&
             event['context'] == 'KitchenMemory | Tag to release/'
        raise 'Expected successful release-workflow status'
      end
      sha = event.fetch('sha')
      raise 'Invalid source SHA' unless sha.match?(/\A[0-9a-f]{40}\z/)
      uri = URI(event.fetch('target_url'))
      run = uri.path.match(%r{/ci/builds/([0-9a-f-]{36})\z}i)
      unless uri.scheme == 'https' && uri.host == 'appstoreconnect.apple.com' && run
        raise 'Expected an Xcode Cloud build URL'
      end
      tags = tags_for_commit.call(sha).select { |tag| ReleaseVersion::TAG_PATTERN.match?(tag) }
      raise 'Expected exactly one release tag for the completed commit' unless tags.length == 1
      [tags.first, run[1]]
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    tag, run = KitchenMemory::ReleaseTrigger.resolve(
      ENV.fetch('GITHUB_EVENT_NAME'), JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH'))),
      requested_tag: ENV['REQUESTED_TAG'],
      tags_for_commit: ->(sha) { KitchenMemory::ReleaseCollection.capture('git', 'tag', '--points-at', sha).lines.map(&:strip) }
    )
    File.open(ENV.fetch('GITHUB_ENV'), 'a') do |file|
      file.puts "RELEASE_TAG=#{tag}"
      file.puts "ASC_BUILD_RUN_ID=#{run}"
    end
  rescue StandardError => error
    abort error.message
  end
end
