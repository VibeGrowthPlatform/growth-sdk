import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ExampleViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                Divider()
                ScrollView {
                    VStack(spacing: 12) {
                        buttonSection
                        Divider().padding(.vertical, 8)
                        logSection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Vibe Growth Example")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SDK v2.1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Base URL: http://localhost:8000")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("Auto-purchase tracking: enabled")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: 10) {
            actionButton("Set User ID", systemImage: "person.badge.plus", action: viewModel.setUserId)
            actionButton("Get User ID", systemImage: "person.fill", action: viewModel.getUserId)
            actionButton("Track Purchase", systemImage: "cart.fill", action: viewModel.trackPurchase)
            actionButton("Track Ad Revenue", systemImage: "dollarsign.circle.fill", action: viewModel.trackAdRevenue)
            actionButton("Track Session Start", systemImage: "play.circle.fill", action: viewModel.trackSessionStart)
            actionButton("Get Config", systemImage: "gearshape.fill", action: viewModel.getConfig)

            Button(action: viewModel.clearLog) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Log")
                        .bold()
                }
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemRed).opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 20)
                Text(title)
                    .bold()
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log Output

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Log Output")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.logMessages.count) entries")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if viewModel.logMessages.isEmpty {
                Text("Tap a button above to test SDK features")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.logMessages) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(entry.timestamp)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(entry.message)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal, 8)
            }
        }
    }
}
