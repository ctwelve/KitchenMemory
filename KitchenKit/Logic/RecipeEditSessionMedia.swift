// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension RecipeEditSession {
  /// Removes existing hero media and appends a newly identified hero image to the local session.
  public mutating func replaceHeroImage(with data: Data) {
    removeHeroImage()
    media?.append(RecipeMedia(role: .hero, imageData: data))
  }

  /// Removes hero media while retaining gallery order; nil media becomes an empty array.
  public mutating func removeHeroImage() {
    media = (media ?? []).filter { $0.role != .hero }
  }

  /// Appends newly identified gallery media in the supplied image order.
  public mutating func addGalleryImages(_ images: [Data]) {
    media = (media ?? []) + images.map { RecipeMedia(role: .gallery, imageData: $0) }
  }

  /// Removes media with the specified identity; a missing identity leaves the session unchanged.
  public mutating func removeMedia(id: RecipeMedia.ID) {
    media?.removeAll { $0.id == id }
  }

  /// Sets accessibility wording for identified media; an empty string removes the description.
  public mutating func setMediaDescription(_ description: String, for id: RecipeMedia.ID) {
    guard let index = media?.firstIndex(where: { $0.id == id }) else { return }
    media?[index].accessibilityLabel = description.isEmpty ? nil : description
  }

  /// Swaps gallery images by gallery-only index, retaining hero positions.
  /// Invalid indices or an overflowing offset leave the session unchanged.
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
