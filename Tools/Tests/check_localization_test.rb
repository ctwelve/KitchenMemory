#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require "minitest/autorun"
require_relative "../check-localization"

class LocalizationContractTest < Minitest::Test
  Contract = KitchenMemory::LocalizationContract

  def fixture
    {"sourceLanguage" => "en-US", "strings" => {"screen.title" => {
      "extractionState" => "manual", "comment" => "Screen heading",
      "localizations" => %w[en-US es-MX fr-CA].to_h { |locale|
        [locale, {"stringUnit" => {"state" => "translated", "value" => "%1$(count)lld items"}}]
      }
    }}}
  end

  def policy
    {"sourceLanguage" => "en-US", "locales" => %w[en-US es-MX fr-CA]}
  end

  def test_complete_catalog_and_generated_usage_pass
    assert_empty Contract.catalog_errors(fixture, policy)
    assert_empty Contract.source_errors({"View.swift" => "Text(.screenTitle)"}, fixture["strings"], {})
  end

  def test_incomplete_stale_unextractable_and_colliding_catalog_entries_fail
    mutations = [
      ->(x) { x["sourceLanguage"] = "en" },
      ->(x) { x["strings"]["screen.title"]["localizations"].delete("fr-CA") },
      ->(x) { x["strings"]["screen.title"]["extractionState"] = "stale" },
      ->(x) { x["strings"]["screen.title"]["comment"] = " " },
      ->(x) { x["strings"]["English sentence"] = x["strings"].delete("screen.title") },
      ->(x) { x["strings"]["screen-title"] = x["strings"]["screen.title"] },
      ->(x) { x["strings"]["screen.title"]["localizations"]["fr-CA"]["stringUnit"]["state"] = "needs_review" },
      ->(x) { x["strings"]["screen.title"]["localizations"]["fr-CA"]["stringUnit"]["value"] = "%1$(other)lld items" }
    ]
    mutations.each do |mutation|
      catalog = fixture
      mutation.call(catalog)
      refute_empty Contract.catalog_errors(catalog, policy)
    end
  end

  def test_history_requires_a_reason_and_comments_do_not_count_as_live_usage
    entries = fixture["strings"]
    source = {"View.swift" => "// Text(.screenTitle)\n/* .screenTitle */"}
    refute_empty Contract.source_errors(source, entries, {})
    refute_empty Contract.source_errors({"View.swift" => 'let example = ".screenTitle"'}, entries, {})
    assert_empty Contract.source_errors(source, entries, {"screen.title" => "Retained previous release heading"})
    refute_empty Contract.source_errors(source, entries, {"screen.title" => " "})
  end

  def test_ui_literals_indirection_and_raw_keys_are_detected
    ['Text("English")', 'Text(#"English"#)', "Text(\"\"\"\nEnglish\n\"\"\")",
     'let heading = "English"; Text(heading)', 'String(localized: "screen.title")',
     'Label("English", systemImage: "book")', 'view.accessibilityValue("English")'].each do |source|
      refute_empty Contract.source_errors({"View.swift" => source}, {}, {}), source
    end
    assert_empty Contract.source_errors({"View.swift" => 'Text(recipe.title) // Text("Old example")'}, {}, {})
    assert_empty Contract.source_errors({"View.swift" => 'let url = "https://example.com"; Text(.screenTitle)'}, fixture["strings"], {})
  end

  def test_nonprose_exception_is_exact_and_scoped
    exception = [{"path" => "Quantity.swift", "literal" => "/", "reason" => "Fraction separator"}]
    assert_empty Contract.source_errors({"Quantity.swift" => 'Text(verbatim: "/")'}, {}, {}, exception)
    refute_empty Contract.source_errors({"Other.swift" => 'Text(verbatim: "/")'}, {}, {}, exception)
    refute_empty Contract.source_errors({"Quantity.swift" => 'Text(verbatim: "English")'}, {}, {}, exception)
  end
end
