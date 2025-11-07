import SwiftUI

/**
 `DelayConfigurationView` is a SwiftUI component for configuring drill start delays.
 
 This view provides:
 - Toggle between fixed and random delay modes
 - Visual feedback for the selected mode
 - Different UI controls based on the delay type
 - Fixed mode: Shows "2...4" text indicating random range
 - Random mode: Provides a picker for selecting specific delay values
 
 ## Features
 - Animated toggle button with shuffle icon
 - Mode-specific UI controls
 - Clean visual design matching app style
 - Automatic value updates when switching modes
 */

struct RepeatsConfigView: View {
    // DelayType removed - this view now only supports random delay mode
    @Binding var repeatsValue: Int

    // Repeats options from 1 to 100
    private let repeatsOptions: [Int] = Array(1...100)

    // State for sheet presentation
    @State private var showRepeatsPicker: Bool = false

    var body: some View {
        HStack {
            // Icon on the left
            Image(systemName: "shuffle")
                .foregroundColor(.red)
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(
                    Circle().stroke(Color.red, lineWidth: 2)
                )

            // Text label next to icon
            Text(NSLocalizedString("num_repeats_label", comment: "Number of repeats label"))
                .foregroundColor(.white)

            Spacer()

            // Button to open picker sheet
            Button(action: {
                showRepeatsPicker = true
            }) {
                HStack {
                    Text("\(repeatsValue)")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                    Image(systemName: "chevron.down")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
        .sheet(isPresented: $showRepeatsPicker) {
            RepeatsPickerView(
                repeatsOptions: repeatsOptions,
                selectedRepeats: $repeatsValue,
                onDone: { showRepeatsPicker = false }
            )
        }
    }
}

struct RepeatsPickerView: View {
    let repeatsOptions: [Int]
    @Binding var selectedRepeats: Int
    var onDone: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(repeatsOptions, id: \.self) { repeats in
                        Button(action: {
                            // set selection and dismiss
                            selectedRepeats = repeats
                            onDone?()
                        }) {
                            HStack {
                                Text("\(repeats)")
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedRepeats == repeats {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(Color.gray.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackgroundHidden()
            }
            .navigationTitle(NSLocalizedString("select_repeats", comment: "Select Repeats navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        onDone?()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct DelayConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                RepeatsConfigView(
                    repeatsValue: .constant(3)
                )
            }
            .padding()
        }
    }
}
