#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'json'
require 'digest'
require 'open3'
require 'tmpdir'
require_relative 'check-release-version'

module KitchenMemory
  module ReleaseCollection
    module_function

    def capture(*args)
      output, error, status = Open3.capture3(*args)
      raise "#{args.first} failed: #{error}" unless status.success?
      output.strip
    end

    def prepare(tag, directory = nil)
      raise 'Invalid release tag' unless ReleaseVersion::TAG_PATTERN.match?(tag.to_s)
      sha = capture('git', 'rev-parse', "refs/tags/#{tag}^{commit}")
      repo = ENV.fetch('GH_REPO')
      runs = JSON.parse(capture('gh', 'api', "repos/#{repo}/actions/workflows/development.yml/runs?event=push&branch=main&head_sha=#{sha}&per_page=100")).fetch('workflow_runs')
      latest = runs.select { |run| run['head_sha'] == sha && run['event'] == 'push' && run['head_branch'] == 'main' }.max_by { |run| run.fetch('id') }
      raise 'Exact tagged commit has no successful push-to-main Development CI run' unless latest && latest['status'] == 'completed' && latest['conclusion'] == 'success'
      # A missing release is expected; other API failures must remain errors.
      releases = JSON.parse(capture('gh', 'api', '--paginate', '--slurp', "repos/#{repo}/releases?per_page=100")).flatten
      existing = releases.find { |release| release['tag_name'] == tag }
      raise 'Refusing to modify an already published release' if existing && !existing['draft']
      return puts("Verified GitHub push-to-main run #{latest.fetch('id')}") unless directory
      evidence = JSON.parse(File.read(File.join(directory, 'release-evidence.json')))
      raise 'Collected evidence does not match release commit' unless evidence['tag'] == tag && evidence['commit'] == sha
      unless existing
        Dir.mktmpdir do |temp|
          notes = File.join(temp, 'notes.md')
          File.write(notes, "Verified notarized macOS artifact from Xcode Cloud build #{evidence.fetch('cloud_build_number')}.\n\nPending install/launch acceptance and release-tier review. Do not publish until those checks are complete.\n\nCommit: #{sha}\n")
          capture('gh', 'release', 'create', tag, '--repo', repo, '--verify-tag', '--draft', '--title', "Kitchen Memory #{tag.delete_prefix('release/')}", '--notes-file', notes)
        end
      end
      files = [evidence.fetch('artifact_name'), 'SHA256SUMS', 'release-evidence.json'].map { |name| File.join(directory, name) }
      files.each do |file|
        asset = existing && existing.fetch('assets').find { |item| item['name'] == File.basename(file) }
        if asset
          Dir.mktmpdir do |temp|
            capture('gh', 'release', 'download', tag, '--repo', repo, '--pattern', File.basename(file), '--dir', temp)
            downloaded = File.join(temp, File.basename(file))
            raise "Existing asset differs: #{File.basename(file)}; refusing replacement" unless Digest::SHA256.file(downloaded).hexdigest == Digest::SHA256.file(file).hexdigest
          end
        else
          capture('gh', 'release', 'upload', tag, file, '--repo', repo)
        end
      end
      puts "Prepared draft #{tag}; publication requires release acceptance."
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'Usage: prepare-release-collection.rb TAG [ARTIFACT_DIRECTORY]' unless (1..2).cover?(ARGV.length)
  begin
    KitchenMemory::ReleaseCollection.prepare(*ARGV)
  rescue StandardError => error
    abort error.message
  end
end
