#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require "json"

module KitchenMemory
  # Source/resource checks complement Xcode's generated-symbol type checking and
  # hosted resource tests. This is a bounded source guard, not a Swift type checker.
  module LocalizationContract
    SEMANTIC_KEY = /\A[a-z][a-z0-9]*(?:\.[a-z0-9][a-z0-9-]*)+\z/
    PLACEHOLDER = /%(\d+)\$\(([^)]+)\)(ll)?([@d])/
    UI_CALL = /\b(?:Text|Label|Button|Toggle|Section|LabeledContent|ContentUnavailableView|TextField|SecureField|Picker|Menu|GroupBox|DisclosureGroup|ProgressView|Link|DatePicker|Stepper|Slider|NavigationLink|navigationSubtitle|help|navigationTitle|accessibilityLabel|accessibilityValue|accessibilityHint|alert|confirmationDialog)\s*\(\s*(?:verbatim:\s*)?/
    # Swift comments and complete ordinary/raw/multiline string tokens. Keeping
    # strings intact avoids treating URL slashes or comment-like copy as comments.
    TOKEN = /\/\/[^\n]*|\/\*.*?\*\/|\#{0,}(?:""".*?"""|"(?:\\.|[^"\\])*")\#{0,}/m

    module_function

    def symbol(key)
      head, *tail = key.split(/[.-]/)
      head + tail.map { |part| part[0].upcase + part[1..] }.join
    end

    def source_without_comments(source)
      source.gsub(TOKEN) { |token| token.start_with?("//", "/*") ? token.gsub(/[^\n]/, " ") : token }
    end

    def units(value, path = [], result = {})
      return result unless value.is_a?(Hash)
      result[path] = value["stringUnit"] if value.key?("stringUnit")
      value.each { |key, child| units(child, path + [key], result) unless key == "stringUnit" }
      result
    end

    def catalog_errors(catalog, contract, metadata: false)
      errors = []
      errors << "source language differs from contract" unless catalog["sourceLanguage"] == contract["sourceLanguage"]
      entries = catalog["strings"]
      return errors + ["missing catalog strings"] unless entries.is_a?(Hash) && !entries.empty?
      generated = {}
      entries.each do |key, entry|
        unless metadata
          errors << "unextractable semantic key: #{key}" unless SEMANTIC_KEY.match?(key)
          name = symbol(key)
          errors << "generated symbol collision: #{key}" if generated.key?(name)
          generated[name] = key
        end
        errors << "unmanaged or stale key: #{key}" unless entry["extractionState"] == "manual"
        errors << "missing translator context: #{key}" if entry.fetch("comment", "").strip.empty?
        localized = entry["localizations"] || {}
        errors << "locale mismatch: #{key}" unless localized.keys.sort == contract.fetch("locales").sort
        source_units = units(localized[contract["sourceLanguage"]])
        errors << "missing source units: #{key}" if source_units.empty?
        localized.each do |locale, value|
          translated = units(value)
          errors << "variant mismatch: #{key}/#{locale}" unless translated.keys.sort == source_units.keys.sort
          translated.each do |path, unit|
            text = unit["value"]
            errors << "incomplete value: #{key}/#{locale}" unless unit["state"] == "translated" && text.is_a?(String) && !text.strip.empty?
            next unless text.is_a?(String)
            source_text = source_units.fetch(path, {}).fetch("value", "")
            errors << "placeholder mismatch: #{key}/#{locale}" unless text.scan(PLACEHOLDER).sort == source_text.scan(PLACEHOLDER).sort
            stripped = text.gsub(PLACEHOLDER, "").gsub("%%", "")
            errors << "unnamed placeholder: #{key}/#{locale}" if stripped.match?(/%(?:\d+\$)?(?:ll)?[@d]/)
          end
        end
      end
      errors
    end

    def source_errors(sources, entries, retained, exceptions = [])
      errors = []
      clean = sources.transform_values { |source| source_without_comments(source) }
      all_source = clean.values.map { |source| source.gsub(TOKEN) { |token| " " * token.length } }.join("\n")
      entries.each_key do |key|
        used = all_source.match?(/\.#{Regexp.escape(symbol(key))}\b/)
        errors << "orphan key needs removal or documented retention: #{key}" unless used || retained.key?(key)
        errors << "retention is no longer needed: #{key}" if used && retained.key?(key)
      end
      retained.each do |key, reason|
        errors << "invalid retained key: #{key}" unless entries.key?(key) && reason.is_a?(String) && !reason.strip.empty?
      end
      clean.each do |path, source|
        string_ranges = []
        source.to_enum(:scan, TOKEN).each do
          string_ranges << (Regexp.last_match.begin(0)...Regexp.last_match.end(0))
        end
        literals = {}
        source.scan(/\b(?:let|var)\s+(\w+)(?:\s*:\s*(?:String|LocalizedStringResource|LocalizedStringKey))?\s*=\s*(\#*"(?:""|[^\n])?)/) do |name, _|
          literals[name] = true
        end
        source.to_enum(:scan, UI_CALL).each do
          match = Regexp.last_match
          next if string_ranges.any? { |range| range.cover?(match.begin(0)) }
          argument = source[match.end(0)..]
          literal = argument.match?(/\A\#*"/)
          identifier = argument[/\A([A-Za-z_]\w*)\s*[,)]/, 1]
          next unless literal || literals[identifier]
          exception = exceptions.find do |item|
            path.end_with?(item.fetch("path")) && argument.start_with?(item.fetch("literal").dump) &&
              !item.fetch("reason", "").strip.empty?
          end
          next if exception
          line = source[0...match.begin(0)].count("\n") + 1
          errors << "#{path}:#{line}: literal interface text; use a generated localization symbol"
        end
        source.to_enum(:scan, /\b(?:String\s*\(\s*localized:|LocalizedStringResource\s*\(|NSLocalizedString\s*\()\s*\#*"/).each do
          start = Regexp.last_match.begin(0)
          next if string_ranges.any? { |range| range.cover?(start) }
          line = source[0...start].count("\n") + 1
          errors << "#{path}:#{line}: raw localization key bypasses generated symbols"
        end
      end
      errors
    end

    def validate(root)
      contract = JSON.parse(File.read(File.join(root, "Configurations/LocalizationContract.json")))
      catalogs = %w[Localizable InfoPlist].to_h do |name|
        [name, JSON.parse(File.read(File.join(root, "KitchenMemory/#{name}.xcstrings")))]
      end
      errors = catalogs.flat_map do |name, catalog|
        catalog_errors(catalog, contract, metadata: name == "InfoPlist").map { |error| "#{name}: #{error}" }
      end
      sources = Dir.glob(File.join(root, "KitchenMemory/**/*.swift")).to_h { |path| [path, File.read(path)] }
      errors.concat(source_errors(sources, catalogs.fetch("Localizable").fetch("strings"), contract.fetch("retainedKeys"), contract.fetch("literalExceptions")))
      errors
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    errors = KitchenMemory::LocalizationContract.validate(File.expand_path("..", __dir__))
    abort errors.join("\n") unless errors.empty?
    puts "Validated localization catalogs, generated-key usage, and documented historical retention."
  rescue JSON::ParserError, KeyError, Errno::ENOENT => error
    abort "Localization contract error: #{error.message}"
  end
end
