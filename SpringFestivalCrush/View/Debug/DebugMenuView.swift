#if DEBUG
import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var settingModel: SettingModel
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Access") {
                    Toggle(isOn: $settingModel.unlockAllLevels) {
                        Label("Unlock All Zodiacs & Levels", systemImage: "lock.open.fill")
                    }
                    .tint(.orange)

                    Button {
                        gameModel.debugUnlockAll()
                        dismiss()
                    } label: {
                        Label("Grant 1 Star to All Levels", systemImage: "star.fill")
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset All Progress", systemImage: "trash")
                    }
                }

                Section("Info") {
                    LabeledContent("Zodiacs", value: "\(gameModel.zodiacRecords.count)")
                    LabeledContent("Unlocked Zodiacs", value: "\(gameModel.zodiacRecords.filter { $0.isUnlocked }.count)")
                    LabeledContent(
                        "Total Levels",
                        value: "\(gameModel.zodiacRecords.flatMap { $0.levelRecords }.count)"
                    )
                    LabeledContent(
                        "Completed Levels",
                        value: "\(gameModel.zodiacRecords.flatMap { $0.levelRecords }.filter { $0.isComplete }.count)"
                    )
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset All Progress?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    settingModel.unlockAllLevels = false
                    gameModel.debugResetAll()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All stars, completions, and unlocks will be wiped. This cannot be undone.")
            }
        }
    }
}

#Preview {
    DebugMenuView()
        .environmentObject(GameModel())
        .environmentObject(SettingModel())
}
#endif
