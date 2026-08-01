import SwiftUI

@available(iOS 26.0, *)
struct NativeDashboardView: View {
  @ObservedObject var store: NativeDashboardStore
  let onAddEntryTypeSelected: (String) -> Void
  let onSettingsRequested: () -> Void
  let onEntrySelected: (String) -> Void

  var body: some View {
    NavigationStack {
      Group {
        if let snapshot = store.snapshot {
          dashboardContent(snapshot)
        } else if let errorMessage = store.errorMessage {
          ContentUnavailableView("Dashboard unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
        } else {
          ProgressView()
        }
      }
      .navigationTitle("Dashboard")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Menu {
            ForEach(NativeAddEntryOption.allCases, id: \.rawValue) { option in
              Button {
                onAddEntryTypeSelected(option.rawValue)
              } label: {
                Label(option.title, systemImage: option.sfSymbolName)
              }
            }
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Add entry")

          Button(action: onSettingsRequested) {
            Image(systemName: "gearshape.fill")
          }
          .accessibilityLabel("Settings")
        }
      }
    }
  }

  @ViewBuilder
  private func dashboardContent(_ snapshot: NativeDashboardSnapshot) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 12) {
          NativeDashboardSummaryCard(
            title: "Total Money Owed To Me",
            amount: snapshot.owedToMeText,
            type: .owedToMe
          )
          NativeDashboardSummaryCard(
            title: "Total Money I Owe",
            amount: snapshot.iOweText,
            type: .owedByMe
          )
        }

        HStack(alignment: .firstTextBaseline) {
          Text("Recent Entries")
            .font(.title2.weight(.bold))
          Spacer()
          Text("\(snapshot.recentCount) \(snapshot.recentCount == 1 ? "item" : "items")")
            .foregroundStyle(.secondary)
        }

        if snapshot.recentEntries.isEmpty {
          ContentUnavailableView("No recent entries yet", systemImage: "wallet.pass")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
        } else {
          VStack(spacing: 0) {
            ForEach(snapshot.recentEntries) { entry in
              Button {
                onEntrySelected(entry.id)
              } label: {
                NativeDashboardEntryRow(entry: entry)
              }
              .buttonStyle(.plain)
              if entry.id != snapshot.recentEntries.last?.id {
                Divider().padding(.leading, 76)
              }
            }
          }
          .padding(.vertical, 4)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 120)
    }
    .scrollIndicators(.hidden)
    .background(Color(uiColor: .systemBackground))
  }
}

@available(iOS 26.0, *)
private enum NativeDashboardCardType {
  case owedToMe
  case owedByMe
}

@available(iOS 26.0, *)
private struct NativeDashboardSummaryCard: View {
  let title: String
  let amount: String
  let type: NativeDashboardCardType

  private var colors: [Color] {
    type == .owedToMe
      ? [Color(red: 0.35, green: 0.62, blue: 0.95), Color(red: 0.08, green: 0.38, blue: 0.82)]
      : [Color(red: 1.0, green: 0.62, blue: 0.28), Color(red: 0.95, green: 0.32, blue: 0.02)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: type == .owedToMe ? "arrow.down.left" : "arrow.up.right")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 48, height: 48)
        .background(.white.opacity(0.18), in: Circle())
      Spacer(minLength: 8)
      Text(title)
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(2)
      Text(amount)
        .font(.system(.title2, design: .rounded).weight(.bold))
        .foregroundStyle(.white)
        .minimumScaleFactor(0.65)
        .lineLimit(1)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
    .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
  }
}

@available(iOS 26.0, *)
private struct NativeDashboardEntryRow: View {
  let entry: NativeDashboardEntry

  private var tint: Color {
    switch entry.type {
    case "owedToMe": return .blue
    case "owedByMe": return .orange
    default: return .indigo
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: entry.symbolName)
        .font(.title3.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 52, height: 52)
        .background(tint.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.title)
          .font(.headline.weight(.semibold))
          .lineLimit(1)
        Text(entry.typeLabel)
          .font(.subheadline)
          .foregroundStyle(tint)
        Label(entry.dateText, systemImage: "calendar")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 4)
      Text(entry.amountText)
        .font(.headline.weight(.bold))
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(entry.title), \(entry.typeLabel), \(entry.amountText)")
  }
}
