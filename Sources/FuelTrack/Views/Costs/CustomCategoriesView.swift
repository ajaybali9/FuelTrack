import SwiftData
import SwiftUI

struct CustomCategoriesView: View {
    let scope: CustomCategoryScope

    @Query(sort: \CustomExpenseCategory.createdAt) private var allCustoms: [CustomExpenseCategory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var newIcon = "tag"
    @State private var message: String?

    private let iconChoices = [
        "tag", "star", "heart", "cart", "house", "car", "bus", "tram",
        "fuelpump", "wrench", "shield", "sterlingsign.circle", "creditcard",
        "bag", "gift", "airplane", "fork.knife", "cup.and.saucer", "cross.case",
        "book", "ticket", "phone", "wifi", "bolt", "leaf", "pawprint",
    ]

    private var customs: [CustomExpenseCategory] {
        allCustoms.filter { $0.scope == scope }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        Form {
            Section {
                Text(scope == .car
                     ? "Custom categories appear alongside built-in car cost types like Road tax and MOT."
                     : "Custom categories appear alongside built-in personal types like Food and Bills.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Add category") {
                TextField("Name", text: $newName)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(iconChoices, id: \.self) { icon in
                            Button {
                                newIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(
                                        newIcon == icon
                                            ? .regular.tint(GlassTheme.accent).interactive()
                                            : .regular.interactive(),
                                        in: .circle
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button("Add category") { add() }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section(customs.isEmpty ? "No custom categories yet" : "Your categories") {
                ForEach(customs) { item in
                    HStack {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(GlassTheme.accent)
                            .frame(width: 28)
                        Text(item.name)
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(item)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(scope == .car ? "Car categories" : "Personal categories")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func add() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if customs.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            message = "That category already exists."
            return
        }
        modelContext.insert(
            CustomExpenseCategory(name: trimmed, systemImage: newIcon, scope: scope)
        )
        try? modelContext.save()
        newName = ""
        newIcon = "tag"
        message = "Added “\(trimmed)”."
    }
}
