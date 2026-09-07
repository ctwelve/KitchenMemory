#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../check-documentation"

class DocumentationContractTest < Minitest::Test
  Contract = KitchenMemory::DocumentationContract
  ROOT = File.expand_path("../..", __dir__)

  def with_tree(files)
    Dir.mktmpdir("KitchenMemoryDocumentation") do |root|
      files.each do |path, contents|
        full = File.join(root, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, contents)
      end
      yield root, files.to_h { |path, contents| [File.join(root, path), contents] }
    end
  end

  def test_repository_contract
    assert_empty Contract.validate(ROOT)
  end

  def test_links_handle_references_fragments_spaces_and_parentheses
    files = {
      "README.md" => "[one](docs/a%20b.md#hello-world) [two](<docs/a b.md#hello-world-1>)\n" \
        "[ref][target]\n[target]: docs/topic_(test).md\n",
      "docs/a b.md" => "# Hello, *World*!\n# Hello World\n",
      "docs/topic_(test).md" => "# Topic\n"
    }
    with_tree(files) { |root, docs| assert_empty Contract.link_errors(docs, root) }
  end

  def test_links_ignore_examples_symbols_and_remote_urls
    source = "`[example](missing.md)`\n```md\n[example](missing.md)\n```\n" \
      "~~~\n[example](missing.md)\n~~~\n``Recipe`` [Apple](https://example.com/path_(a))\n"
    with_tree("README.md" => source) { |root, docs| assert_empty Contract.link_errors(docs, root) }
  end

  def test_missing_files_headings_and_escaping_paths_fail
    with_tree("README.md" => "[file](missing.md) [heading](present.md#lost) [escape](../private.md)", "present.md" => "# Present") do |root, docs|
      errors = Contract.link_errors(docs, root)
      assert_equal 3, errors.length
      assert errors.any? { |error| error.include?("missing heading") }
      assert errors.any? { |error| error.include?("../private.md") }
    end
  end

  def test_duplicate_and_explicit_heading_anchors
    assert_equal ["a", "a-1", "a-1-1", "café", "legacy"],
      Contract.anchors("# A\n# A\n# A-1\n# Café\n<a id=\"legacy\"></a>\n")
  end

  def test_new_pages_need_classification_and_a_reachable_route
    files = {
      "README.md" => "[map](docs/README.md)",
      "docs/README.md" => "[history](history.md) [decisions](adr/README.md) [research](research/README.md)",
      "docs/history.md" => "# History", "docs/adr/README.md" => "# Decisions",
      "docs/research/README.md" => "# Research", "docs/new-guide.md" => "# New",
      "docs/adr/0099-new.md" => "# New decision"
    }
    with_tree(files) do |root, docs|
      errors = Contract.navigation_errors(docs, root)
      assert errors.any? { |error| error.include?("new-guide.md: classify") }
      assert errors.any? { |error| error.include?("0099-new.md: absent from docs/adr/README.md") }
      assert_equal 2, errors.count { |error| error.start_with?("unreachable") }
    end
  end

  def test_unused_definition_does_not_make_a_page_reachable
    files = {
      "README.md" => "[map](docs/README.md)",
      "docs/README.md" => "[history](history.md) [decisions](adr/README.md) [research](research/README.md)\n[unused]: orphan.md\n",
      "docs/history.md" => "# History", "docs/adr/README.md" => "# Decisions",
      "docs/research/README.md" => "# Research", "docs/orphan.md" => "# Orphan"
    }
    with_tree(files) do |root, docs|
      errors = Contract.navigation_errors(docs, root)
      assert_includes errors, "docs/orphan.md: classify in docs/README.md or docs/history.md"
      assert_includes errors, "unreachable documentation: docs/orphan.md"
    end
  end

  def test_missing_references_and_unused_broken_definitions_fail
    with_tree("README.md" => "[missing][absent]\n[unused]: gone.md\n") do |root, docs|
      errors = Contract.link_errors(docs, root)
      assert_equal 2, errors.length
      assert errors.any? { |error| error.include?("undefined link reference: absent") }
      assert errors.any? { |error| error.include?("gone.md") }
    end
  end

  def with_topology
    paths = %w[docs/implementation-architecture.md docs/localization-architecture.md
      docs/continuous-integration.md KitchenMemory.xcodeproj/project.pbxproj
      Configurations/LocalizationContract.json KitchenKit/Persistence/KitchenMemorySchema.swift]
    paths.concat(Dir.glob(File.join(ROOT, "*.xctestplan")).map { |path| path.delete_prefix(ROOT + "/") })
    paths.concat(Dir.glob(File.join(ROOT, "KitchenMemory.xcodeproj/xcshareddata/xcschemes/*.xcscheme")).map { |path| path.delete_prefix(ROOT + "/") })
    files = paths.to_h { |path| [path, File.read(File.join(ROOT, path))] }
    files["docs/history.md"] = "# History\n[record](old.md)"
    files["docs/old.md"] = "# Old record\nKitchenMemoryIOS and KitchenDomain"
    files["docs/adr/0009.md"] = "# Old decision\nKitchenMemoryMacOS"
    with_tree(files) do |root, docs|
      %w[Domain Import Logic Persistence].each { |name| FileUtils.mkdir_p(File.join(root, "KitchenKit", name)) }
      yield root, docs
    end
  end

  def mutate(root, path)
    full = File.join(root, path)
    File.write(full, yield(File.read(full)))
  end

  def test_current_topology_accepts_explicit_history
    with_topology { |root, docs| assert_empty Contract.topology_errors(root, docs) }
  end

  def test_target_and_schema_changes_need_documentation
    with_topology do |root, docs|
      mutate(root, "KitchenMemory.xcodeproj/project.pbxproj") { |text| text.sub("name = KitchenKit;", "name = NewCore;") }
      mutate(root, "KitchenKit/Persistence/KitchenMemorySchema.swift") { |text| text.sub("= KitchenMemorySchemaV7", "= KitchenMemorySchemaV8") }
      errors = Contract.topology_errors(root, docs)
      assert errors.any? { |error| error.start_with?("target inventory") }
      assert_includes errors, "current schema differs from implementation guide"
    end
  end

  def test_new_locale_and_responsibility_need_documentation
    with_topology do |root, docs|
      mutate(root, "Configurations/LocalizationContract.json") do |text|
        value = JSON.parse(text)
        value["locales"] << "ja-JP"
        JSON.generate(value)
      end
      FileUtils.mkdir_p(File.join(root, "KitchenKit/NewBoundary"))
      errors = Contract.topology_errors(root, docs)
      assert errors.any? { |error| error.start_with?("locale inventory") }
      assert errors.any? { |error| error.start_with?("KitchenKit responsibilities") }
    end
  end

  def test_plan_membership_and_scheme_reference_drift_fail
    with_topology do |root, docs|
      mutate(root, "KitchenMemoryCloud.xctestplan") { |text| text.sub('"name": "KitchenMemoryTests"', '"name": "KitchenMemoryUITests"') }
      mutate(root, "KitchenMemory.xcodeproj/xcshareddata/xcschemes/KitchenMemory.xcscheme") { |text| text.sub("container:KitchenMemoryCloud.xctestplan", "container:Other.xctestplan") }
      errors = Contract.topology_errors(root, docs)
      assert errors.any? { |error| error.start_with?("KitchenMemoryCloud.xctestplan test targets") }
      assert_includes errors, "KitchenMemoryCloud.xctestplan: absent from KitchenMemory scheme"
    end
  end

  def test_obsolete_names_in_current_guidance_fail
    with_topology do |root, docs|
      %w[KitchenMemoryIOS KitchenMemoryMacOS KitchenMemoryDomain KitchenMemoryImport KitchenMemoryLogic KitchenMemoryPersistence].each do |name|
        docs[File.join(root, "docs/current.md")] = "Use #{name} for current work."
        assert_includes Contract.topology_errors(root, docs), "docs/current.md: obsolete current-topology wording"
      end
    end
  end
end
