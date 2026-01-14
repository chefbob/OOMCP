import SwiftUI

/// Visual indicator for server and connection status.
struct StatusIndicator: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(appState.statusColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(appState.connectionStatus?.proRequired == true ? .red : .primary)

                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundColor(appState.connectionStatus?.proRequired == true ? .red : .secondary)

                if let proMessage = appState.proRequirementMessage {
                    Text(proMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusTitle: String {
        switch appState.serverStatus {
        case .running:
            if appState.connectionStatus?.connected == true {
                return "Connected"
            } else if appState.connectionStatus?.proRequired == true {
                return "Pro Required"
            } else {
                return "Waiting"
            }
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting..."
        case .stopping:
            return "Stopping..."
        case .error:
            return "Error"
        }
    }
}

// MARK: - Compact Status Indicator

/// Compact version for tight spaces.
struct CompactStatusIndicator: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.statusColor)
                .frame(width: 8, height: 8)

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Status Badge

/// Badge-style indicator for menu bar.
struct StatusBadge: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StatusIndicator()

        Divider()

        CompactStatusIndicator()

        Divider()

        HStack {
            StatusBadge(color: .green)
            StatusBadge(color: .yellow)
            StatusBadge(color: .red)
        }
    }
    .padding()
    .environmentObject(AppState())
}
