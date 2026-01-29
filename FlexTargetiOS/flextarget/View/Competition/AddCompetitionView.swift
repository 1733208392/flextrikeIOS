import SwiftUI
import CoreData

struct AddCompetitionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var venue = ""
    @State private var date = Date()
    @State private var selectedDrillSetup: DrillSetup?
    @State private var showDrillPicker = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Form {
                Section(header: Text(NSLocalizedString("competition_info", comment: "")).foregroundColor(.white)) {
                    TextField(NSLocalizedString("competition_name", comment: ""), text: $name, prompt: Text(NSLocalizedString("competition_name", comment: "")).foregroundColor(.gray))
                        .foregroundColor(.white)
                    TextField(NSLocalizedString("venue", comment: ""), text: $venue, prompt: Text(NSLocalizedString("venue", comment: "")).foregroundColor(.gray))
                        .foregroundColor(.white)
                    DatePicker(NSLocalizedString("date", comment: ""), selection: $date, displayedComponents: .date)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.1))
                
                Section(header: Text(NSLocalizedString("drill_setup", comment: "")).foregroundColor(.white)) {
                    if let drill = selectedDrillSetup {
                        HStack {
                            Text(drill.name ?? "")
                                .foregroundColor(.white)
                            Spacer()
                            Button(NSLocalizedString("change", comment: "")) {
                                showDrillPicker = true
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button(NSLocalizedString("select_drill", comment: "")) {
                            showDrillPicker = true
                        }
                        .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color.white.opacity(0.1))
                
                Section {
                    Button(action: saveCompetition) {
                        Text(NSLocalizedString("create_competition", comment: ""))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                    .listRowBackground(isSaveDisabled ? Color.gray.opacity(0.5) : Color.red)
                    .disabled(isSaveDisabled)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
        }
        .navigationTitle(NSLocalizedString("add_competition", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .tint(.red)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDrillPicker) {
            DrillPickerView(selectedDrill: $selectedDrillSetup)
        }
    }
    
    private var isSaveDisabled: Bool {
        name.isEmpty || venue.isEmpty || selectedDrillSetup == nil
    }
    
    private func saveCompetition() {
        let newCompetition = Competition(context: viewContext)
        newCompetition.id = UUID()
        newCompetition.name = name
        newCompetition.venue = venue
        newCompetition.date = date
        newCompetition.drillSetup = selectedDrillSetup
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving competition: \(error)")
        }
    }
}

struct DrillPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDrill: DrillSetup?
    
    @FetchRequest(
        entity: DrillSetup.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DrillSetup.name, ascending: true)]
    ) private var drills: FetchedResults<DrillSetup>
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List(drills) { drill in
                    Button(action: {
                        selectedDrill = drill
                        dismiss()
                    }) {
                        HStack {
                            Text(drill.name ?? "")
                                .foregroundColor(.white)
                            Spacer()
                            if selectedDrill?.id == drill.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(NSLocalizedString("select_drill", comment: ""))
            .navigationBarItems(trailing: Button(NSLocalizedString("cancel", comment: "")) {
                dismiss()
            }
            .foregroundColor(.red))
            .tint(.red)
        }
    }
}
