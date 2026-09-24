#!/usr/bin/env ruby
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT

require 'open3'
require 'tmpdir'
require 'json'

abort 'Usage: ruby Tools/check-ingredient-authoring-interface.rb <macOS build products>' unless ARGV.length == 1
products = File.expand_path(ARGV.fetch(0))
derived_data = File.expand_path('../../..', products)
numerics_shims = File.join(derived_data, 'SourcePackages/checkouts/swift-numerics/Sources/_NumericsShims/include')
abort "KitchenKit.framework is missing from #{products}" unless File.directory?(File.join(products, 'KitchenKit.framework'))
sdk, status = Open3.capture2('xcrun', '--sdk', 'macosx', '--show-sdk-path')
abort 'Cannot locate the macOS SDK' unless status.success?
target, status = Open3.capture2('xcrun', 'swiftc', '-print-target-info')
abort 'Cannot identify the native Swift target' unless status.success?
architecture = JSON.parse(target).fetch('target').fetch('triple').split('-').first

# Compile as an ordinary consumer, never with @testable or access-control overrides.
allowed = <<~SWIFT
  var copy = draft.session
  copy.title = "Soup"
  draft.updateRecipeDetails(from: copy)
  _ = copy.ingredientSections
  _ = copy.ingredientText?.text
  let input = draft.beginIngredientTextEditing()
  _ = input.document
  input.completeLines()
  input.end()
  if var ingredient = draft.session.ingredientSections.first?.ingredients.first {
    ingredient.note = "Use fine salt"
    draft.updateIngredient(ingredient)
  }
SWIFT

forbidden = {
  'whole session replacement' => 'draft.session = RecipeEditSession()',
  'live ingredient collection' => 'draft.session.ingredientSections = []',
  'copied ingredient collection' => 'var copy = draft.session; copy.ingredientSections = []',
  'copied ingredient text' => 'var copy = draft.session; copy.ingredientText = nil',
  'session text replacement' => 'var copy = draft.session; copy.updateIngredientText(RecipeIngredientTextDraft(sections: []))',
  'session text preparation' => 'var copy = draft.session; copy.prepareIngredientText()',
  'session text completion' => 'var copy = draft.session; copy.finishIngredientText()',
  'session section reordering' => 'var copy = draft.session; copy.moveIngredientSection(at: 0, by: 1)',
  'text replacement' => 'var text = draft.session.ingredientText!; text.replaceCharacters(in: NSRange(location: 0, length: 0), with: "salt")',
  'text interpretation' => 'var text = draft.session.ingredientText!; text.finishEditing()',
  'proposal resolution' => 'var text = draft.session.ingredientText!; text.resolve(RecipeIngredient.ID(), acceptingInterpretation: true)',
  'representation repair' => 'let text = draft.session.ingredientText!; _ = text.incorporating([])',
  'semantic history rebasing' => 'let text = draft.session.ingredientText!; _ = text.preservingAdjustments(from: text, to: text)',
}

Dir.mktmpdir('KitchenMemoryIngredientInterface') do |directory|
  source = File.join(directory, 'Consumer.swift')
  command = ['xcrun', '--sdk', 'macosx', 'swiftc', '-typecheck', '-swift-version', '6',
             '-sdk', sdk.strip, '-target', "#{architecture}-apple-macos26.5", '-F', products, '-I', products,
             '-Xcc', "-fmodule-map-file=#{numerics_shims}/module.modulemap", '-Xcc', "-I#{numerics_shims}",
             '-module-cache-path', File.join(directory, 'Modules'), source]
  compile = lambda do |body|
    File.write(source, "import Foundation\nimport KitchenKit\n@MainActor func consume(_ draft: RecipeEditingDraft) {\n#{body}\n}\n")
    Open3.capture3(*command)
  end
  _, errors, result = compile.call(allowed)
  abort "Supported editing operations did not compile:\n#{errors}" unless result.success?
  forbidden.each do |name, body|
    _, errors, result = compile.call(body)
    abort "Forbidden ingredient ingress compiled: #{name}" if result.success?
    unless errors.match?(/inaccessible|cannot assign|cannot use mutating member/)
      abort "Unexpected compiler failure for #{name}:\n#{errors}"
    end
  end
end
puts "Validated ordinary-consumer ingredient operations and #{forbidden.length} forbidden mutation routes."
