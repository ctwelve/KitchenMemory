#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require_relative 'Release/cloud'
require_relative 'prepare-release-collection'

if $PROGRAM_NAME == __FILE__
  $stdout.sync = true
  begin
    tag = ARGV.fetch(0)
    KitchenMemory::ReleaseCollection.prepare(tag)
    sha = KitchenMemory::ReleaseCollection.capture('git', 'rev-parse', "refs/tags/#{tag}^{commit}")
    client = KitchenMemory::Release::Cloud.new(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'),
                                               private_key: ENV.fetch('ASC_PRIVATE_KEY'))
    run = client.wait_for_run(workflow: ENV.fetch('ASC_RELEASE_WORKFLOW_ID'), tag: tag, sha: sha)
    File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') { |file| file.puts "run_id=#{run.fetch('id')}" }
  rescue StandardError => error
    abort error.message
  end
end
