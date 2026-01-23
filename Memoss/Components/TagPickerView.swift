//
//  TagPickerView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import SwiftData
import SwiftUI

struct TagPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var selectedTags: [Tag]

    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var selectedColorIndex = 0

    private var unselectedTags: [Tag] {
        allTags.filter { tag in
            !selectedTags.contains { $0.id == tag.id }
        }
    }

    private var animationValue: Animation? {
        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Tags")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(MemossColors.textSecondary)

            // Selected tags
            if !selectedTags.isEmpty {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(selectedTags, id: \.id) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: true,
                            onRemove: { removeTag(tag) }
                        )
                    }
                }
            }

            // Available tags + New button
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(unselectedTags, id: \.id) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: false,
                        onTap: { addTag(tag) }
                    )
                }

                addTagButton
            }

            // Inline creation form
            if isCreatingTag {
                tagCreationForm
            }
        }
        .padding(20)
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
    }

    // MARK: - Subviews

    private var addTagButton: some View {
        Button {
            withAnimation(animationValue) {
                isCreatingTag = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("New")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .foregroundStyle(MemossColors.textSecondary.opacity(0.4))
            )
            .foregroundStyle(MemossColors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create new tag")
    }

    private var tagCreationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name input
            HStack {
                TextField("Tag name", text: $newTagName)
                    .font(.system(size: 16, design: .rounded))
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit(createTag)

                Button { cancelCreation() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MemossColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(MemossColors.backgroundStart)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Color picker
            HStack(spacing: 12) {
                Text("Color")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)

                HStack(spacing: 8) {
                    ForEach(Array(MemossColors.tagColors.enumerated()), id: \.offset) { index, color in
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                                    .opacity(selectedColorIndex == index ? 1 : 0)
                            )
                            .shadow(color: selectedColorIndex == index ? color.opacity(0.4) : .clear, radius: 4)
                            .onTapGesture {
                                selectedColorIndex = index
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    }
                }
            }

            // Preview + Create
            HStack {
                if !newTagName.isEmpty {
                    let previewColor = MemossColors.tagColors[selectedColorIndex]
                    TagChip(
                        tag: Tag(name: newTagName, colorHex: previewColor.toHex() ?? "#22C55E"),
                        isSelected: true
                    )
                }

                Spacer()

                Button(action: createTag) {
                    Text("Create")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(newTagName.isEmpty ? MemossColors.textSecondary : MemossColors.brandPrimary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(newTagName.isEmpty)
            }
        }
        .padding(12)
        .background(MemossColors.backgroundStart.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Computed Properties

    private var selectedColor: Color {
        MemossColors.tagColors[selectedColorIndex]
    }

    // MARK: - Actions

    private func addTag(_ tag: Tag) {
        withAnimation(animationValue) {
            selectedTags.append(tag)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeTag(_ tag: Tag) {
        withAnimation(animationValue) {
            selectedTags.removeAll { $0.id == tag.id }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func createTag() {
        guard !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let tag = Tag(
            name: newTagName.trimmingCharacters(in: .whitespaces),
            colorHex: selectedColor.toHex() ?? "#22C55E"
        )
        modelContext.insert(tag)
        selectedTags.append(tag)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        cancelCreation()
    }

    private func cancelCreation() {
        withAnimation(animationValue) {
            isCreatingTag = false
            newTagName = ""
            selectedColorIndex = 0
        }
    }
}

#Preview {
    TagPickerView(selectedTags: .constant([]))
        .padding()
        .modelContainer(for: [Tag.self, Reminder.self], inMemory: true)
}
