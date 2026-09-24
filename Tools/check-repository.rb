#!/usr/bin/env ruby
# frozen_string_literal: true
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'rbconfig'

Dir.chdir(File.expand_path('..', __dir__))
checks = Dir['Tools/Tests/*_test.rb'].sort + %w[
  Tools/check-documentation.rb
  Tools/check-localization.rb
  Tools/check-project-structure.rb
  Tools/check-software-inventory.rb
  Tools/check-release-version.rb
]
checks.each do |path|
  puts "Checking #{path}"
  abort "Failed: #{path}" unless system(RbConfig.ruby, path)
end
