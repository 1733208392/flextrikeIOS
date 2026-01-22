import SwiftUI

/**
 `DrillNameSectionView` is a reusable SwiftUI component for editing drill names.
 */

struct DrillNameSectionView: View {
    @Binding var drillName: String
    @State private var isEditingName = false
    @FocusState private var isDrillNameFocused: Bool
    var disabled: Bool = false
    
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
                    .disabled(disabled)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.words)
                    
                    if !isEditingName {
                        Text(drillName.isEmpty ? "Drill Name" : drillName)
                            .foregroundColor(disabled ? .gray : .white)
                            .font(.title3)
                            .padding(.vertical, 4)
                            .onTapGesture {
                                if !disabled {
                                    isEditingName = true
                                    isDrillNameFocused = true
                                }
                            }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if disabled {
                        return // Do nothing if disabled
                    }
                    if isEditingName {
                        drillName = "" // Clear the text when xmark is tapped
                        isEditingName = false
                        isDrillNameFocused = false
                    } else {
                        isEditingName = true
                        isDrillNameFocused = true
                    }
                }) {
                    Image(systemName: isEditingName ? "xmark" : "pencil")
                        .foregroundColor(disabled ? .gray : .red)
                }
                .disabled(disabled)
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
                DrillNameSectionView(drillName: .constant(""))
                    .padding()
            }
        }
    }
}
