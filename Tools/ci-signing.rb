#!/usr/bin/env ruby
# Derived from Folio's MIT-licensed CI signing helper.
# Copyright © 2026 the Folio Project and Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'base64'
require 'fileutils'
require 'json'
require 'open3'
require 'securerandom'

# Restricted to disposable hosted runners; never edit a developer's keychain list.
abort 'Signing setup is for GitHub-hosted runners only' unless ENV['GITHUB_ACTIONS'] == 'true' && ENV['RUNNER_ENVIRONMENT'] == 'github-hosted'
root = ENV.fetch('RUNNER_TEMP')
keychain = File.join(root, 'kitchenmemory-ci.keychain-db')
certificate = File.join(root, 'kitchenmemory-ci.p12')
search_list = File.join(root, 'kitchenmemory-original-keychains.json')

def security(*args)
  output, status = Open3.capture2e('security', *args)
  # Arguments can contain passwords: never echo them or security's error output.
  raise "Keychain operation failed: #{args.first}" unless status.success?
  output
end

case ARGV.first
when 'import'
  encoded = ENV.fetch('CI_CERTIFICATE_P12_BASE64', '')
  password = ENV.fetch('CI_CERTIFICATE_PASSWORD', '')
  abort 'Configure CI_CERTIFICATE_P12_BASE64 and CI_CERTIFICATE_PASSWORD in ci-signing' if encoded.empty? || password.empty?
  abort 'Temporary signing keychain already exists' if File.exist?(keychain) || File.exist?(search_list)
  original = security('list-keychains', '-d', 'user').scan(/"([^"]+)"/).flatten
  File.write(search_list, JSON.generate(original), mode: 'w', perm: 0600)
  begin
    File.write(certificate, Base64.strict_decode64(encoded), mode: 'wb', perm: 0600)
    keychain_password = SecureRandom.hex(32)
    security('create-keychain', '-p', keychain_password, keychain)
    security('set-keychain-settings', '-lut', '3600', keychain)
    security('unlock-keychain', '-p', keychain_password, keychain)
    security('import', certificate, '-P', password, '-t', 'cert', '-f', 'pkcs12', '-k', keychain, '-T', '/usr/bin/codesign')
    security('set-key-partition-list', '-S', 'apple-tool:,apple:', '-s', '-k', keychain_password, keychain)
    identities = security('find-identity', '-v', '-p', 'codesigning', keychain).scan(/([0-9A-F]{40}) "Apple Development:[^"]+"/).flatten
    raise 'Import exactly one valid Apple Development identity' unless identities.length == 1
    security('list-keychains', '-d', 'user', '-s', keychain, *original)
    File.open(ENV.fetch('GITHUB_ENV'), 'a') { |file| file.puts("KITCHEN_MEMORY_SIGNING_IDENTITY=#{identities.first}") }
    puts 'Dedicated development identity imported; private key remains in the temporary keychain.'
  ensure
    FileUtils.rm_f(certificate)
  end
when 'cleanup'
  if File.exist?(search_list)
    security('list-keychains', '-d', 'user', '-s', *JSON.parse(File.read(search_list)))
    FileUtils.rm_f(search_list)
  end
  security('delete-keychain', keychain) if File.exist?(keychain)
  FileUtils.rm_f(certificate)
else
  abort 'Usage: ruby Tools/ci-signing.rb import|cleanup'
end
