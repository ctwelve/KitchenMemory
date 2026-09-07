#!/usr/bin/ruby
# frozen_string_literal: true

# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require "json"
require "pathname"
require "set"
require "uri"
require "rexml/document"
require "rexml/xpath"

module KitchenMemory
  # A bounded Markdown contract, not a renderer or a network link checker.
  module DocumentationContract
    OBSOLETE_TOPOLOGY = /\b(?:KitchenMemoryIOS|KitchenMemoryMacOS|KitchenDomain|KitchenImport|KitchenLogic|KitchenPersistence)\b|both app targets|both platform application-test targets|all three locales/
    module_function

    def prose(text)
      # Fenced examples may deliberately contain non-links and old topology.
      fence = nil
      text.lines.map do |line|
        marker = line[/\A\s*(`{3,}|~{3,})/, 1]
        if marker && !fence
          fence = marker
          nil
        elsif fence
          fence = nil if marker && marker[0] == fence[0] && marker.length >= fence.length
          nil
        else
          line
        end
      end.compact.join.gsub(/<!--.*?-->/m, "")
    end

    def links(text)
      text = prose(text)
      # Inline code, including DocC symbol links, is not a Markdown destination.
      text = text.gsub(/(`+).*?\1/m, "")
      definitions = text.scan(/^\s*\[([^\]]+)\]:\s*(<[^>]+>|\S+)/).to_h.transform_keys(&:downcase)
      inline = text.scan(/!?\[[^\]\n]*\]\(\s*(<[^>]+>|(?:[^\s()]|\([^()]*\))+)\s*(?:"[^"]*"\s*)?\)/).flatten
      references = text.scan(/\[([^\]\n]+)\]\[([^\]\n]*)\]/).map do |label, key|
        definitions[(key.empty? ? label : key).downcase]
      end
      # Definitions are checked too, even when no longer referenced.
      (inline + references.compact + definitions.values).map { |link| link.delete_prefix("<").delete_suffix(">") }.uniq
    end

    def destination(source, link)
      return if link.match?(/\A(?:[a-z][a-z0-9+.-]*:|\/\/)/i)
      path, fragment = link.split("#", 2)
      path = URI::DEFAULT_PARSER.unescape(path.split("?", 2).first.to_s)
      resolved = path.empty? ? source : File.expand_path(path, File.dirname(source))
      [resolved, fragment && URI::DEFAULT_PARSER.unescape(fragment)]
    end

    def anchors(text)
      used = Set.new
      result = prose(text).lines.map do |line|
        heading = line[/\A\s{0,3}\#{1,6}\s+(.+?)\s*\#*\s*$/, 1]
        next unless heading
        heading = heading.gsub(/\[([^\]]+)\]\([^)]*\)/, '\1').gsub(/<[^>]*>/, "")
        slug = heading.downcase.gsub(/[^\p{L}\p{M}\p{N}_\-\s]/, "").gsub(/\s/, "-")
        candidate = slug
        suffix = 0
        while used.include?(candidate)
          suffix += 1
          candidate = "#{slug}-#{suffix}"
        end
        used << candidate
        candidate
      end
      result.compact + prose(text).scan(/<(?:a|h[1-6])\b[^>]*\b(?:id|name)=["']([^"']+)["']/).flatten
    end

    def link_errors(documents, root)
      documents.flat_map do |source, contents|
        links(contents).map do |link|
          target, fragment = destination(source, link)
          next unless target
          label = Pathname.new(source).relative_path_from(Pathname.new(root))
          if !target.start_with?(root + "/") || !File.exist?(target)
            "#{label}: missing or outside-repository link: #{link}"
          elsif fragment && !fragment.empty? && File.extname(target) == ".md" && !anchors(File.read(target)).include?(fragment)
            "#{label}: missing heading: #{link}"
          end
        end.compact
      end
    end

    def linked_paths(documents, source)
      links(documents.fetch(source)).map { |link| destination(source, link)&.first }.compact
    end

    def navigation_errors(documents, root)
      entry = File.join(root, "docs/README.md")
      indexes = %w[docs/README.md docs/history.md docs/adr/README.md docs/research/README.md]
      missing = indexes.reject { |path| documents.key?(File.join(root, path)) }
      return missing.map { |path| "missing navigation index: #{path}" } unless missing.empty?
      current = linked_paths(documents, entry)
      historical = linked_paths(documents, File.join(root, "docs/history.md"))
      errors = []
      documents.each_key do |path|
        relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
        owner = case relative
                when %r{\Adocs/adr/(?!README\.md)[^/]+\.md\z} then "docs/adr/README.md"
                when %r{\Adocs/research/(?!README\.md)[^/]+\.md\z} then "docs/research/README.md"
                end
        if owner && !linked_paths(documents, File.join(root, owner)).include?(path)
          errors << "#{relative}: absent from #{owner}"
        elsif relative.match?(%r{\Adocs/[^/]+\.md\z}) && path != entry && !current.include?(path) && !historical.include?(path)
          errors << "#{relative}: classify in docs/README.md or docs/history.md"
        end
      end
      seen = Set.new
      pending = [File.join(root, "README.md")]
      until pending.empty?
        path = pending.pop
        next unless documents.key?(path) && seen.add?(path)
        pending.concat(linked_paths(documents, path))
      end
      (documents.keys - seen.to_a).each do |path|
        errors << "unreachable documentation: #{Pathname.new(path).relative_path_from(Pathname.new(root))}"
      end
      errors
    end

    def table_values(text, heading)
      section = text.split(/^\#{1,6} #{Regexp.escape(heading)}\s*$/, 2)[1].to_s.split(/^\#{1,6} /, 2).first.to_s
      section.lines.map { |line| line[/\A\| `([^`]+)` \|/, 1] }.compact
    end

    def compare(label, actual, expected)
      actual.sort == expected.sort ? [] : ["#{label}: documented #{actual.sort.inspect}, source #{expected.sort.inspect}"]
    end

    def topology_errors(root, documents)
      read = ->(path) { File.read(File.join(root, path)) }
      architecture = read.call("docs/implementation-architecture.md")
      localization = read.call("docs/localization-architecture.md")
      project = read.call("KitchenMemory.xcodeproj/project.pbxproj")
      native_section = project.split("/* Begin PBXNativeTarget section */", 2).fetch(1).split("/* End PBXNativeTarget section */", 2).first
      targets = native_section.scan(/^\s*name = ([\w]+);/).flatten
      errors = compare("target inventory", table_values(architecture, "Target organization"), targets)
      locales = JSON.parse(read.call("Configurations/LocalizationContract.json")).fetch("locales")
      errors.concat(compare("locale inventory", table_values(localization, "Supported locales"), locales))
      responsibilities = Dir.children(File.join(root, "KitchenKit")).select { |name| File.directory?(File.join(root, "KitchenKit", name)) && !name.end_with?(".docc") }
      errors.concat(compare("KitchenKit responsibilities", table_values(architecture, "KitchenKit responsibilities"), responsibilities))
      schema = read.call("KitchenKit/Persistence/KitchenMemorySchema.swift")[/typealias CurrentKitchenMemorySchema = (\w+)/, 1]
      errors << "current schema differs from implementation guide" unless schema && architecture.include?("The store's current schema is `#{schema}`")
      ci = read.call("docs/continuous-integration.md")
      plans = Dir.glob(File.join(root, "*.xctestplan"))
      rows = ci.lines.select { |line| line.start_with?("| `") }
      errors.concat(compare("test plan inventory", rows.map { |line| line[/with `([^`]+\.xctestplan)`/, 1] }.compact, plans.map { |path| File.basename(path) }))
      plans.each do |path|
        name = File.basename(path)
        row = rows.find { |line| line.include?("with `#{name}`") }.to_s
        cells = row.split("|")
        expected = JSON.parse(File.read(path)).fetch("testTargets").map { |test| test.fetch("target").fetch("name") }
        errors.concat(compare("#{name} test targets", cells.fetch(3, "").scan(/`([^`]+)`/).flatten, expected))
        scheme = cells.fetch(1, "")[/`([^`]+)`/, 1]
        scheme_path = File.join(root, "KitchenMemory.xcodeproj/xcshareddata/xcschemes/#{scheme}.xcscheme")
        if File.file?(scheme_path)
          xml = REXML::Document.new(File.read(scheme_path))
          references = REXML::XPath.match(xml, "//TestPlanReference").map { |node| node.attributes["reference"] }
          errors << "#{name}: absent from #{scheme} scheme" unless references.include?("container:#{name}")
        else
          errors << "#{name}: missing documented scheme #{scheme}"
        end
      end
      history = linked_paths(documents, File.join(root, "docs/history.md"))
      documents.each do |path, contents|
        relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
        next unless relative.start_with?("docs/") && !relative.match?(%r{\Adocs/(adr|research)/}) && !history.include?(path)
        # Link destinations can legitimately name retained historical files.
        visible = prose(contents).gsub(/\]\([^)]*\)/, "]")
        errors << "#{relative}: obsolete current-topology wording" if visible.match?(OBSOLETE_TOPOLOGY)
      end
      errors
    end

    def validate(root)
      root = File.expand_path(root)
      patterns = %w[*.md docs/**/*.md Tools/**/*.md KitchenKit/**/*.docc/*.md KitchenMemory/**/*.docc/*.md]
      documents = patterns.flat_map { |pattern| Dir.glob(File.join(root, pattern)) }.uniq.to_h { |path| [path, File.read(path)] }
      errors = link_errors(documents, root) + navigation_errors(documents, root)
      return errors unless errors.empty?
      errors.concat(topology_errors(root, documents))
      alias_path = File.join(root, "skills")
      errors << "skills must remain a compatibility symlink to .agents/skills" unless File.symlink?(alias_path) && File.readlink(alias_path) == ".agents/skills" && File.directory?(alias_path)
      errors
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    errors = KitchenMemory::DocumentationContract.validate(File.expand_path("..", __dir__))
    abort errors.join("\n") unless errors.empty?
    puts "Validated documentation links, navigation, current topology, and the single skill library."
  rescue JSON::ParserError, KeyError, IndexError, Errno::ENOENT, REXML::ParseException => error
    abort "Documentation contract error: #{error.message}"
  end
end
