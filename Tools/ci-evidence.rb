#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'json'
require 'open3'
require 'tmpdir'
require 'time'

module KitchenMemory
  module CIEvidence
    POLICY = 'xos-27.0-full-development-v2'
    module_function

    def capture(*args)
      output, error, status = Open3.capture3(*args)
      raise "#{args.first} failed: #{error}" unless status.success?
      output.strip
    end

    def api(path)
      JSON.parse(capture('gh', 'api', path))
    end

    def full_candidate?(event, payload)
      return !payload.dig('pull_request', 'draft') if event == 'pull_request'
      %w[push merge_group workflow_dispatch].include?(event)
    end

    def eligible_run?(run, repo)
      run['status'] == 'completed' && run['conclusion'] == 'success' &&
        run['path'] == '.github/workflows/development.yml' &&
        %w[pull_request merge_group push workflow_dispatch].include?(run['event']) &&
        run.dig('repository', 'full_name') == repo && run.dig('head_repository', 'full_name') == repo
    end

    def matching?(proof, run, tree)
      proof['schema'] == 1 && proof['policy'] == POLICY && proof['tree'] == tree &&
        proof['run_id'].to_s == run['id'].to_s && proof['run_attempt'].to_i == run['run_attempt'].to_i &&
        proof['validation'] == 'full' && proof['commit'].to_s.match?(/\A[0-9a-f]{40}\z/)
    end

    def reusable_run(tree, repo)
      artifacts = api("repos/#{repo}/actions/artifacts?name=validated-tree-#{tree}&per_page=100").fetch('artifacts')
      artifacts.each do |artifact|
        next if artifact['expired'] || artifact.fetch('size_in_bytes') > 65_536
        next if Time.parse(artifact.fetch('created_at')) < Time.now - 7 * 86_400
        id = artifact.dig('workflow_run', 'id')
        next unless id.is_a?(Integer) && id.to_s != ENV['GITHUB_RUN_ID']
        run = api("repos/#{repo}/actions/runs/#{id}")
        next unless eligible_run?(run, repo)
        proof = Dir.mktmpdir do |temp|
          # Download only data from a successful run; never execute artifact contents.
          capture('gh', 'run', 'download', id.to_s, '--repo', repo, '--name', artifact.fetch('name'), '--dir', temp)
          file = File.join(temp, 'validation.json')
          next unless File.file?(file) && !File.symlink?(file) && File.size(file) <= 16_384
          JSON.parse(File.read(file))
        end
        return id if proof && matching?(proof, run, tree)
      end
      nil
    end

    def decide
      event = ENV.fetch('GITHUB_EVENT_NAME')
      payload = JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH')))
      tree = capture('git', 'rev-parse', 'HEAD^{tree}')
      mode, source = 'fast', nil
      if full_candidate?(event, payload)
        # Reuse only identical, recently validated trees. This also avoids rerunning
        # a completed candidate when only its PR description changes. Manual runs force tests.
        source = reusable_run(tree, ENV.fetch('GITHUB_REPOSITORY')) unless event == 'workflow_dispatch'
        mode = source ? 'reuse' : 'full'
      end
      File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') do |out|
        out.puts "mode=#{mode}"
        out.puts "tree=#{tree}"
        out.puts "source_run=#{source}"
      end
      puts source ? "Reuse full validation from run #{source} for tree #{tree}" : "Validation mode: #{mode}"
    rescue StandardError => error
      # A service problem must never authorize a skip. Fall back to the full
      # suite rather than blocking integration on an optional optimization.
      warn "Evidence unavailable; run full validation (#{error.class})."
      File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') { |out| out.puts 'mode=full' }
    end

    def record(path)
      proof = {schema: 1, policy: POLICY, validation: 'full',
               tree: capture('git', 'rev-parse', 'HEAD^{tree}'), commit: capture('git', 'rev-parse', 'HEAD'),
               run_id: ENV.fetch('GITHUB_RUN_ID'), run_attempt: ENV.fetch('GITHUB_RUN_ATTEMPT')}
      File.write(path, JSON.pretty_generate(proof) + "\n")
    end
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.first
  when 'decide' then KitchenMemory::CIEvidence.decide
  when 'record' then KitchenMemory::CIEvidence.record(ARGV.fetch(1))
  else abort 'Usage: ci-evidence.rb decide | record FILE'
  end
end
