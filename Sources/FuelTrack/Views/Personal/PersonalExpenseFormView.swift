import SwiftData
import SwiftUI

struct PersonalExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExpenseCategory.createdAt) private var customs: [CustomExpenseCategory]
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode = CurrencyCode.gbp.rawValue

    let expense: PersonalExpense?

    @State private var title = ""
    @State private var date = Date.now
    @State private var amountText = ""
    @State private var currency: CurrencyCode = .gbp
    @State private var categoryKey = PersonalExpenseCategory.other.rawValue
    @State private var note = ""
    @State private var paymentMethod = ""
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @State private var showingSavedAlert = false
    @State private var showingCategories = false

    private var isEditing: Bool { expense != nil }

    private var categoryOptions: [ResolvedSpendCategory] {
        SpendCategoryCatalog.all(scope: .personal, customs: customs)
    }

    var body: some View {
        Form {
            Section("Expense") {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Category", selection: $categoryKey) {
                    ForEach(categoryOptions) { item in
                        Label(item.name, systemImage: item.systemImage).tag(item.id)
                    }
                }
                Button("Manage categories") { showingCategories = true }
            }

            Section("Amount") {
                Picker("Currency", selection: $currency) {
                    ForEach(CurrencyCode.allCases) { code in
                        Text(code.displayName).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
            }

            Section("Details") {
                TextField("Payment method (optional)", text: $paymentMethod)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            if isEditing {
                Section {
                    Button("Delete expense", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit expense" : "Add expense")
        .navigationBarTitleDisplayMode(.inline)
        .fuelTrackForm()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .sheet(isPresented: $showingCategories) {
            NavigationStack {
                CustomCategoriesView(scope: .personal)
            }
        }
        .confirmationDialog("Delete this expense?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteExpense() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Expense saved", isPresented: $showingSavedAlert) {
            Button("OK") {
                if !isEditing { dismiss() }
            }
        } message: {
            Text(isEditing ? "Your changes are saved." : "Added to personal expenses.")
        }
        .onAppear(perform: load)
    }

    private func load() {
        if let expense {
            title = expense.title
            date = expense.date
            amountText = String(expense.amount)
            currency = expense.currencyCode
            categoryKey = expense.categoryKey
            note = expense.note
            paymentMethod = expense.paymentMethod
        } else {
            currency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .gbp
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a title."
            return
        }
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            errorMessage = "Enter a valid amount."
            return
        }

        if let expense {
            expense.title = trimmed
            expense.date = date
            expense.amount = amount
            expense.currencyCode = currency
            expense.categoryKey = categoryKey
            expense.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            expense.paymentMethod = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let item = PersonalExpense(
                title: trimmed,
                date: date,
                amount: amount,
                currencyCode: currency,
                category: .other,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                paymentMethod: paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            item.categoryKey = categoryKey
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            errorMessage = nil
            showingSavedAlert = true
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func deleteExpense() {
        guard let expense else { return }
        modelContext.delete(expense)
        try? modelContext.save()
        dismiss()
    }
}
