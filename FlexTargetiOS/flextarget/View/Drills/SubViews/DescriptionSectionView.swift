import SwiftUI

// MARK: - Custom TextEditor with Gray Background
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var foregroundColor: UIColor = .white
    var backgroundColor: UIColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.2)
    var disabled: Bool = false
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = foregroundColor
        textView.backgroundColor = backgroundColor
        textView.text = text
        textView.isScrollEnabled = true
        textView.isEditable = !disabled
        textView.isSelectable = !disabled
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEditable = !disabled
        uiView.isSelectable = !disabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator($text)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        
        init(_ text: Binding<String>) {
            _text = text
        }
        
        func textViewDidChange(_ textView: UITextView) {
            _text.wrappedValue = textView.text
        }
    }
}

/**
 `DescriptionSectionView` is a SwiftUI component that handles drill description editing.
 
 This view provides:
 - Description text editor with placeholder
 */

struct DescriptionSectionView: View {
    @Binding var description: String
    var disabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("description", comment: "Description label"))
                .foregroundColor(.white)
                .font(.body)
            
            ZStack(alignment: .topLeading) {
                CustomTextEditor(text: $description, foregroundColor: .white, backgroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.2), disabled: disabled)
                    .frame(height: 120) // Fixed height for 5 lines
                    .disableAutocorrection(true)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                
                if description.isEmpty {
                    Text(NSLocalizedString("enter_description_placeholder", comment: "Enter description placeholder"))
                        .font(.footnote)
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
            }
        }
    }
}

struct DescriptionSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                DescriptionSectionView(
                    description: .constant("Sample description")
                )
                .padding()
            }
        }
    }
}
