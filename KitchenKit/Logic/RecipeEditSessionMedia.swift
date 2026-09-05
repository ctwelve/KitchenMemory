// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension RecipeEditSession {
  public mutating func replaceHeroImage(with data: Data) {
    removeHeroImage()
    media?.append(RecipeMedia(role: .hero, imageData: data))
  }

  public mutating func removeHeroImage() {
    media = (media ?? []).filter { $0.role != .hero }
  }

  public mutating func addGalleryImages(_ images: [Data]) {
    media = (media ?? []) + images.map { RecipeMedia(role: .gallery, imageData: $0) }
  }

  public mutating func removeMedia(id: RecipeMedia.ID) {
    media?.removeAll { $0.id == id }
  }

  public mutating func setMediaDescription(_ description: String, for id: RecipeMedia.ID) {
    guard let index = media?.firstIndex(where: { $0.id == id }) else { return }
    media?[index].accessibilityLabel = description.isEmpty ? nil : description
  }

  public mutating func moveGalleryImage(at index: Int, by offset: Int) {
    guard var items = media else { return }
    let indices = items.indices.filter { items[$0].role == .gallery }
    guard indices.indices.contains(index) else { return }
    let (destination, overflow) = index.addingReportingOverflow(offset)
    guard !overflow, indices.indices.contains(destination) else { return }
    items.swapAt(indices[index], indices[destination])
    media = items
  }
}
