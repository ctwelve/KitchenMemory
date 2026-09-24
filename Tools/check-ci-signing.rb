#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'json'
require 'open3'

abort 'Usage: ruby Tools/check-ci-signing.rb MACOS_PRODUCTS' unless ARGV.length == 1
products = File.expand_path(ARGV.first)
app = File.join(products, 'KitchenMemory.app')
abort 'The test host is missing' unless File.directory?(app)
output, status = Open3.capture2e('codesign', '--verify', '--deep', '--strict', app)
abort output unless status.success?
details, status = Open3.capture2e('codesign', '-d', '--verbose=4', app)
abort 'Cannot inspect test host signature' unless status.success?
abort 'Test host must retain the project team signature' unless details.include?('TeamIdentifier=FT9KDL728H')
abort 'Test host must retain Hardened Runtime' unless details.match?(/flags=.*\bruntime\b/)
xml, errors, status = Open3.capture3('codesign', '-d', '--entitlements', '-', '--xml', app)
abort errors unless status.success?
json, errors, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', '--', '-', stdin_data: xml)
abort errors unless status.success?
entitlements = JSON.parse(json)
%w[com.apple.security.cs.disable-library-validation com.apple.security.cs.allow-dyld-environment-variables].each do |key|
  abort "Test host must not enable #{key}" if entitlements[key]
end
abort 'Test host must retain App Sandbox' unless entitlements['com.apple.security.app-sandbox']
puts 'Test host team signature, Hardened Runtime, library validation, and sandbox verified.'
