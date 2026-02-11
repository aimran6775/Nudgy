//
//  RemindersImportView.swift
//  Nudge
//
//  Sheet that lets users pick which Reminders lists to import.
//  Presented from Settings / You tab.
//

import SwiftUI

struct RemindersImportView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var service = RemindersImportService.shared
    @State private var selectedListIDs: Set<String> = []
    @State private var importResult: ImportResult?
    @State private var showResult: Bool = false
    
    enum ImportResult {
        case success(Int)
        case noItems
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if !service.isAuthorized {
                    permissionView
                } else if service.availableLists.isEmpty {
                    emptyStateView
                } else {
                    listSelectionView
                }
            }
            .navigationTitle(String(localized: "Import Reminders"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .alert(String(localized: "Import Complete"), isPresented: $showResult) {
                Button(String(localized: "Done")) { dismiss() }
            } message: {
                switch importResult {
                case .success(let count):
                    Text("Imported \(count) task\(count == 1 ? "" : "s") from Reminders.")
                case .noItems:
                    Text("No new tasks to import. Items already in Nudge were skipped.")
                case .none:
                    Text("")
                }
            }
        }
    }
    
    // MARK: - Permission
    
    private var permissionView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("Access Reminders")
                .font(AppTheme.title2)
            
            Text("Nudge can import your incomplete reminders as tasks. Your reminders won't be modified.")
                .font(AppTheme.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacingXL)
            
            Button {
                Task {
                    _ = await service.requestAccess()
                }
            } label: {
                Text("Allow Access")
                    .font(AppTheme.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, DesignTokens.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty
    
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("No Reminders Lists")
                .font(AppTheme.title2)
            
            Text("You don't have any reminders lists with incomplete items.")
                .font(AppTheme.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List Selection
    
    private var listSelectionView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(service.availableLists) { list in
                        Button {
                            toggleSelection(list.id)
                        } label: {
                            HStack(spacing: DesignTokens.spacingSM) {
                                Circle()
                                    .fill(Color(hex: list.color))
                                    .frame(width: 12, height: 12)
                                
                                Text(list.title)
                                    .font(AppTheme.body)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text("\(list.count)")
                                    .font(AppTheme.caption)
                                    .foregroundStyle(.secondary)
                                
                                Image(systemName: selectedListIDs.contains(list.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedListIDs.contains(list.id) ? Color.accentColor : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("Select lists to import")
                } footer: {
                    Text("Duplicate tasks will be skipped automatically.")
                }
            }
            
            // Import button
            VStack(spacing: DesignTokens.spacingSM) {
                Button {
                    importSelected()
                } label: {
                    HStack {
                        if service.isImporting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(service.isImporting ? String(localized: "Importing…") : String(localized: "Import Selected"))
                            .font(AppTheme.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.spacingSM)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedListIDs.isEmpty || service.isImporting)
            }
            .padding(DesignTokens.spacingMD)
        }
        .onAppear {
            service.fetchLists()
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ id: String) {
        if selectedListIDs.contains(id) {
            selectedListIDs.remove(id)
        } else {
            selectedListIDs.insert(id)
        }
        HapticService.shared.prepare()
    }
    
    private func importSelected() {
        Task {
            var totalImported = 0
            for listID in selectedListIDs {
                let count = await service.importList(listID, into: modelContext)
                totalImported += count
            }
            
            HapticService.shared.swipeDone()
            
            if totalImported > 0 {
                importResult = .success(totalImported)
            } else {
                importResult = .noItems
            }
            showResult = true
        }
    }
}
