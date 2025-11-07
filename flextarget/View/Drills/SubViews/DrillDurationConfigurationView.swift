import SwiftUI
import UIKit

/**
 `DrillDurationConfigurationView` is a SwiftUI component for configuring drill duration.

 This view provides:
 - A wheel picker for selecting drill duration in seconds
 - Visual feedback with a clock icon
 - Clean visual design matching app style
 */

struct DrillDurationConfigurationView: View {
    @Binding var drillDuration: Double

    // Duration options from 5 to 30 seconds in 1-second increments
    private let durationOptions: [Double] = Array(stride(from: 5, through: 30, by: 1))

    // State for sheet presentation
    @State private var showDurationPicker: Bool = false

    var body: some View {
        HStack {
            // Clock icon on the left
            Image(systemName: "clock")
                .foregroundColor(.red)
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(
                    Circle().stroke(Color.red, lineWidth: 2)
                )

            // Text label next to icon
            Text(NSLocalizedString("drill_duration_seconds_label", comment: "Drill duration in seconds label"))
                .foregroundColor(.white)

            Spacer()

            // Button to open picker sheet
            Button(action: {
                showDurationPicker = true
            }) {
                HStack {
                    Text("\(Int(drillDuration))")
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
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerView(
                durationOptions: durationOptions,
                selectedDuration: $drillDuration,
                onDone: { showDurationPicker = false }
            )
        }
    }
}

// Custom wheel picker with red text using UIViewRepresentable
struct CustomWheelPicker: UIViewRepresentable {
    @Binding var selection: Double
    let options: [Double]

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        // Set initial selection
        if let index = options.firstIndex(of: selection) {
            picker.selectRow(index, inComponent: 0, animated: false)
        }

        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        // Update selection if it changed externally
        if let index = options.firstIndex(of: selection) {
            uiView.selectRow(index, inComponent: 0, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: CustomWheelPicker

        init(_ parent: CustomWheelPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 1
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return parent.options.count
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = view as? UILabel ?? UILabel()
            label.text = "\(Int(parent.options[row]))s"
            label.textColor = .red // Set text color to red
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            parent.selection = parent.options[row]
        }
    }
}

struct DurationPickerView: View {
    let durationOptions: [Double]
    @Binding var selectedDuration: Double
    var onDone: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(durationOptions, id: \.self) { duration in
                        Button(action: {
                            // set selection and dismiss
                            selectedDuration = duration
                            onDone?()
                        }) {
                            HStack {
                                Text("\(Int(duration))s")
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedDuration == duration {
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
            .navigationTitle(NSLocalizedString("select_duration", comment: "Select Duration navigation title"))
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

struct DrillDurationConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                DrillDurationConfigurationView(
                    drillDuration: .constant(15)
                )
            }
            .padding()
        }
    }
}
