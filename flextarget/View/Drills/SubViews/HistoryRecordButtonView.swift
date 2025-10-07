import SwiftUI

/**
 `HistoryRecordButtonView` is a reusable SwiftUI component that displays a history record button.
 
 This view shows a rounded rectangle button with a red border, containing a clock icon and "History Record" text.
 The button is designed to be tappable and can trigger a custom action when pressed.
 
 ## Features
 - Red bordered rounded rectangle design
 - Clock icon with "History Record" text
 - Customizable action handler
 - Consistent styling matching the app's design system
 */

struct HistoryRecordButtonView: View {
    let action: () -> Void
    
    init(action: @escaping () -> Void = {}) {
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.red, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.clear))
                    .frame(height: 36)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.red)
                                .font(.title3)
                            Text(NSLocalizedString("history_record", comment: "History record button"))
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HistoryRecordButtonView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            HistoryRecordButtonView {
                print("History Record button tapped")
            }
        }
    }
}