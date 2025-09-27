import SwiftUI

/**
 `DrillNameSectionView` is a reusable SwiftUI component for editing drill names.
 
 This view provides:
 - An editable text field with a 30-character limit
 - Visual feedback when editing (red underline)
 - A pencil/close button to toggle edit mode
 - Placeholder text when empty
 - Focus state management
 
 ## Features
 - Tap to edit functionality
 - Character limit enforcement
 - Visual editing state indicators
 - Keyboard management with done button
 */

struct DrillNameSectionView: View {
    @Binding var drillName: String
    @State private var isEditingName = false
    @FocusState private var isDrillNameFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                ZStack(alignment: .leading) {
                    TextField("Drill Name", text: Binding(
                        get: { String(drillName.prefix(30)) },
                        set: { newValue in
                            drillName = String(newValue.prefix(30))
                        }
                    ), onEditingChanged: { editing in
                        isEditingName = editing
                    })
                    .focused($isDrillNameFocused)
                    .foregroundColor(.white)
                    .opacity(isEditingName ? 1 : 0.01) // Hide when not editing, but keep tappable
                    .font(.title3)
                    .padding(.vertical, 4)
                    .background(Color.clear)
                    .submitLabel(.done)
                    
                    if !isEditingName {
                        Text(drillName.isEmpty ? "Drill Name" : drillName)
                            .foregroundColor(.white)
                            .font(.title3)
                            .padding(.vertical, 4)
                            .onTapGesture {
                                isEditingName = true
                                isDrillNameFocused = true
                            }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if isEditingName {
                        isEditingName = false
                        isDrillNameFocused = false
                    } else {
                        isEditingName = true
                        isDrillNameFocused = true
                    }
                }) {
                    Image(systemName: isEditingName ? "xmark" : "pencil")
                        .foregroundColor(.red)
                }
            }
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(isEditingName ? .red : Color.gray.opacity(0.5))
                .animation(.easeInOut, value: isEditingName)
        }
    }
}

struct DrillNameSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                DrillNameSectionView(drillName: .constant("Sample Drill Name"))
                    .padding()
                DrillNameSectionView(drillName: .constant(""))
                    .padding()
            }
        }
    }
}