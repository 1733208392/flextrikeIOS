//
//  ViewExtensions.swift
//  flextarget
//
//  Created for iOS 16 compatibility
//

import SwiftUI

extension View {
    /// Conditionally applies scrollContentBackground modifier for iOS 16.1+
    /// For iOS 16.0, the modifier is unavailable, so this does nothing
    @ViewBuilder
    func scrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.1, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
