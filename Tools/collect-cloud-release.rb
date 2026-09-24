#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'digest'
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'Release/cloud'

module KitchenMemory
  module Release
    module_function

    def command(*args)
      output, status = Open3.capture2e(*args)
      raise "#{args.first} failed: #{output}" unless status.success?
      output.strip
    end

    def verify_app(app, version)
      plist = File.join(app, 'Contents/Info.plist')
      read = ->(key) { command('/usr/libexec/PlistBuddy', '-c', "Print :#{key}", plist) }
      raise 'Wrong application identity' unless read.call('CFBundleIdentifier') == 'net.ctwelve.KitchenMemory'
      raise 'Wrong application version' unless read.call('CFBundleShortVersionString') == version
      command('codesign', '--verify', '--deep', '--strict', app)
      details = command('codesign', '-d', '--verbose=4', app)
      raise 'Wrong signing team' unless details.include?('TeamIdentifier=FT9KDL728H')
      raise 'Expected Developer ID distribution signature' unless details.include?('Authority=Developer ID Application:')
      raise 'Hardened Runtime missing' unless details.match?(/flags=.*runtime/)
      Dir.mktmpdir('KitchenMemoryEntitlements.') do |temp|
        entitlement_path = File.join(temp, 'entitlements.plist')
        xml, error, status = Open3.capture3('codesign', '-d', '--entitlements', ':-', app)
        raise "Cannot inspect entitlements: #{error}" unless status.success?
        File.write(entitlement_path, xml)
        entitlements = JSON.parse(command('plutil', '-convert', 'json', '-o', '-', entitlement_path))
        raise 'App sandbox missing' unless entitlements['com.apple.security.app-sandbox'] == true
        %w[com.apple.security.get-task-allow com.apple.security.cs.disable-library-validation com.apple.security.cs.allow-dyld-environment-variables].each do |key|
          raise "Unexpected release entitlement: #{key}" if entitlements[key] == true
        end
        raise 'Expected Production CloudKit environment' unless entitlements['com.apple.developer.icloud-container-environment'] == 'Production'
        raise 'Wrong CloudKit container' unless entitlements['com.apple.developer.icloud-container-identifiers'] == ['iCloud.net.ctwelve.KitchenMemory']
      end
      command('xcrun', 'stapler', 'validate', app)
      command('spctl', '--assess', '--type', 'execute', '--verbose=2', app)
      architectures = command('lipo', '-archs', File.join(app, 'Contents/MacOS', read.call('CFBundleExecutable'))).split
      raise 'Expected universal Mac application' unless %w[arm64 x86_64].all? { |arch| architectures.include?(arch) }
      read.call('CFBundleVersion')
    end

    def collect(tag, output)
      raise 'Expected release/major.minor.patch' unless tag.match?(%r{\Arelease/\d+\.\d+\.\d+\z})
      raise 'Use a new output directory' if File.exist?(output)
      sha = command('git', 'rev-parse', "#{tag}^{commit}")
      raise 'Release tags must be annotated' unless command('git', 'cat-file', '-t', "refs/tags/#{tag}") == 'tag'
      command('git', 'merge-base', '--is-ancestor', sha, 'origin/main')
      version = tag.delete_prefix('release/')
      raise 'Tag and RELEASE marker differ' unless command('git', 'show', "#{tag}:RELEASE") == version
      client = Cloud.new(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'),
                         private_key: ENV.fetch('ASC_PRIVATE_KEY'))
      workflow = ENV.fetch('ASC_RELEASE_WORKFLOW_ID')
      raise 'Invalid workflow ID' unless workflow.match?(/\A[0-9a-f-]{36}\z/i)
      run = client.wait_for_run(workflow: workflow, tag: tag, sha: sha)
      artifact = client.notarized_artifact(run.fetch('id'))
      attrs = artifact.fetch('attributes')
      url = URI(attrs.fetch('downloadUrl'))
      raise 'Artifact download must use HTTPS' unless url.scheme == 'https'
      FileUtils.mkdir_p(output)
      archive = File.join(output, "KitchenMemory-#{version}-macOS.zip")
      # Keep the signed URL out of process arguments, logs, and release evidence.
      config = "url = #{JSON.generate(url.to_s)}\noutput = #{JSON.generate(archive)}\n"
      _, status = Open3.capture2e('curl', '--config', '-', '--fail', '--silent', '--show-error', '--location',
                                 '--proto', '=https', '--proto-redir', '=https', '--max-time', '600', stdin_data: config)
      raise 'Artifact download failed' unless status.success?
      raise 'Artifact size mismatch' unless File.size(archive) == attrs.fetch('fileSize')
      build = Dir.mktmpdir('KitchenMemoryRelease.') do |directory|
        entries = command('unzip', '-Z1', archive).lines.map(&:strip)
        raise 'Unsafe archive paths' if entries.any? { |name| name.start_with?('/') || name.split('/').include?('..') }
        command('ditto', '-x', '-k', archive, directory)
        apps = Dir.glob(File.join(directory, '*.app'))
        raise 'Expected exactly one top-level app in notarized download; inspect Cloud artifact layout' unless apps.length == 1
        verify_app(apps.first, version)
      end
      checksum = Digest::SHA256.file(archive).hexdigest
      File.write(File.join(output, 'SHA256SUMS'), "#{checksum}  #{File.basename(archive)}\n")
      evidence = {tag: tag, commit: sha, version: version, build: build, cloud_workflow: workflow,
                  cloud_run: run.fetch('id'), cloud_build_number: run.dig('attributes', 'number'),
                  cloud_artifact: artifact.fetch('id'), artifact_type: attrs.fetch('fileType'),
                  artifact_name: File.basename(archive), sha256: checksum,
                  acceptance: 'Automated checks passed; install/launch and release-tier acceptance still required.'}
      File.write(File.join(output, 'release-evidence.json'), JSON.pretty_generate(evidence) + "\n")
      puts "Verified #{File.basename(archive)} from Cloud build #{run.dig('attributes', 'number')}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'Usage: collect-cloud-release.rb RELEASE_TAG NEW_OUTPUT_DIRECTORY' unless ARGV.length == 2
  begin
    KitchenMemory::Release.collect(*ARGV)
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
