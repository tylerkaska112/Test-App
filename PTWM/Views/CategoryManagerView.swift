import SwiftUI

struct CategoryManagerView: View {
    @AppStorage("tripCategories") private var tripCategoriesData: String = ""
    @AppStorage("defaultTripCategory") private var defaultTripCategory: String = "Business"
    private let defaultCategories = ["Business", "Personal", "Vacation", "Photography", "DoorDash", "Uber"]
    private let fixedCategories = ["Other"]
    @State private var categories: [String] = []
    private func saveCategories(_ newCategories: [String]) {
        if let data = try? JSONEncoder().encode(newCategories) {
            tripCategoriesData = String(data: data, encoding: .utf8) ?? tripCategoriesData
        }
    }
    @State private var newCategory = ""
    @State private var editingCategory: String? = nil
    @State private var renameValue: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Trip Categories")) {
                        ForEach(Array(categories.enumerated()), id: \.1) { index, category in
                            if editingCategory == category {
                                HStack {
                                    TextField("Rename Category", text: $renameValue)
                                    Button("Save") {
                                        renameCategory()
                                    }
                                    .disabled(renameValue.trimmingCharacters(in: .whitespaces).isEmpty || categories.contains(where: { $0.caseInsensitiveCompare(renameValue) == .orderedSame && $0 != editingCategory }))
                                    Button("Cancel") {
                                        editingCategory = nil
                                    }
                                }
                            } else {
                                HStack {
                                    Text(category)
                                    Spacer()
                                    if editMode?.wrappedValue.isEditing == true && category != "Other" {
                                        Button("Edit") {
                                            editingCategory = category
                                            renameValue = category
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if category != "Other" && editingCategory == nil {
                                        Button(role: .destructive) {
                                            if let idx = categories.firstIndex(of: category) {
                                                deleteCategory(at: IndexSet(integer: idx))
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if category != "Other" && editingCategory == nil {
                                        Button {
                                            editingCategory = category
                                            renameValue = category
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            let filteredOffsets = offsets.filter { !fixedCategories.contains(categories[$0]) }
                            deleteCategory(at: IndexSet(filteredOffsets))
                        }
                        .onMove { indices, newOffset in
                            // Prevent moving "Other"
                            let otherIndex = categories.firstIndex(of: "Other")
                            guard let otherPos = otherIndex else { return }
                            // Indices to move must not contain "Other"
                            if indices.contains(otherPos) {
                                return
                            }
                            // newOffset must not be after "Other"
                            let maxOffset = otherPos
                            let limitedOffset = min(newOffset, maxOffset)
                            categories.move(fromOffsets: indices, toOffset: limitedOffset)
                            saveCategories(categories)
                        }
                    }
                    Section(header: Text("Add New Category")) {
                        HStack {
                            TextField("New Category", text: $newCategory)
                            Button("Add") {
                                addCategory(newCategory)
                            }
                            .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty || categories.contains(where: { $0.caseInsensitiveCompare(newCategory) == .orderedSame }))
                        }
                    }
                }
                VStack {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Swipe from **Right to Left** to **Delete** a category and swipe from **Left to Right** to **Rename** a category.")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("The 'Other' category cannot be edited or deleted.")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
            }
            .navigationTitle("Manage Categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                // Load categories from storage or default
                var decoded = (try? JSONDecoder().decode([String].self, from: Data(tripCategoriesData.utf8))) ?? defaultCategories
                if !decoded.contains("Other") {
                    decoded.append("Other")
                }
                // Remove duplicates of "Other"
                decoded = decoded.filterDuplicates()
                // Move "Other" to the end
                if let idx = decoded.firstIndex(of: "Other") {
                    decoded.remove(at: idx)
                    decoded.append("Other")
                }
                categories = decoded
            }
        }
    }
    private func addCategory(_ cat: String) {
        let trimmed = cat.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        var updated = categories
        // Insert before "Other"
        if let otherIndex = updated.firstIndex(of: "Other") {
            updated.insert(trimmed, at: otherIndex)
        } else {
            updated.append(trimmed)
        }
        categories = updated
        saveCategories(updated)
        newCategory = ""
    }
    private func removeCategory(_ category: String) {
        guard !fixedCategories.contains(category) else { return }
        var updated = categories
        updated.removeAll(where: { $0 == category })
        categories = updated
        saveCategories(updated)
        // If default category removed, switch to another
        if defaultTripCategory == category {
            if updated.contains("Business") {
                defaultTripCategory = "Business"
            } else if let first = updated.first(where: { !fixedCategories.contains($0) }) {
                defaultTripCategory = first
            } else {
                defaultTripCategory = "Other"
            }
        }
    }
    private func deleteCategory(at offsets: IndexSet) {
        let toDelete = offsets.compactMap { idx in
            let cat = categories[idx]
            return fixedCategories.contains(cat) ? nil : cat
        }
        for cat in toDelete {
            removeCategory(cat)
        }
    }
    private func renameCategory() {
        let trimmed = renameValue.trimmingCharacters(in: .whitespaces)
        guard let old = editingCategory, !trimmed.isEmpty, !categories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame && $0 != old }) else { return }
        var updated = categories
        if let idx = updated.firstIndex(of: old) {
            updated[idx] = trimmed
            categories = updated
            saveCategories(updated)
            // If default category was renamed, update it
            if defaultTripCategory == old {
                defaultTripCategory = trimmed
            }
        }
        editingCategory = nil
    }
}

private extension Array where Element: Hashable {
    func filterDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { element in
            if seen.contains(element) {
                return false
            } else {
                seen.insert(element)
                return true
            }
        }
    }
}

#Preview {
    CategoryManagerView()
}
