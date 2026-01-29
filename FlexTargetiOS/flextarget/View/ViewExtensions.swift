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
    
    /// Constrains content width to match mobile phone layout on iPad
    /// This ensures iPad displays content with the same proportions as mobile phones
    /// by limiting the maximum width and centering the content
    @ViewBuilder
    func mobilePhoneLayout() -> some View {
        // Get the current size class to detect iPad vs iPhone
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIpad {
            // For iPad, constrain to mobile phone width (approximately iPhone Max width)
            self
                .frame(maxWidth: 430)
                .frame(maxHeight: .infinity)
        } else {
            // For iPhone, use natural layout
            self
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
