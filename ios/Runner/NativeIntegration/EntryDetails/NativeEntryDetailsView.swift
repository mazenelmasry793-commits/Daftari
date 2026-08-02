import SwiftUI

@available(iOS 26.0, *)
struct NativeEntryDetailsView: View {
  let bridge: NativeEntryDetailsBridge
  @ObservedObject private var store: NativeEntryDetailsStore
  let onBack: () -> Void
  let onEdit: (NativeEntryDetailsSnapshot) -> Void

  init(
    bridge: NativeEntryDetailsBridge,
    onBack: @escaping () -> Void,
    onEdit: @escaping (NativeEntryDetailsSnapshot) -> Void
  ) {
    self.bridge = bridge
    self.onBack = onBack
    self.onEdit = onEdit
    _store = ObservedObject(wrappedValue: bridge.store)
  }

  var body: some View {
    NavigationStack {
      Group {
        if let snapshot = store.snapshot {
          detailsContent(snapshot)
        } else if store.isLoading {
          ProgressView()
        } else {
          ContentUnavailableView(
            "Entry not found",
            systemImage: "doc.text.magnifyingglass",
            description: Text("This item may have been permanently deleted.")
          )
        }
      }
      .background(Color(uiColor: .systemBackground))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: onBack) {
            Image(systemName: "chevron.left")
          }
          .accessibilityLabel("Back")
        }
        ToolbarItem(placement: .principal) {
          if let snapshot = store.snapshot {
            VStack(spacing: 1) {
              Text(snapshot.title)
                .font(.headline)
                .lineLimit(1)
              Label(snapshot.dateText, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          if let snapshot = store.snapshot {
            Menu {
              entryActions(snapshot)
            } label: {
              Label("Entry actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .frame(width: 56, height: 56)
            .accessibilityLabel("Entry actions")
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder
  private func entryActions(_ snapshot: NativeEntryDetailsSnapshot) -> some View {
    if snapshot.isDeleted {
      Button {
        bridge.perform(action: .restore, id: snapshot.id)
      } label: {
        Label("Restore", systemImage: "arrow.uturn.backward")
      }
      Button(role: .destructive) {
        bridge.perform(action: .delete, id: snapshot.id)
      } label: {
        Label("Delete Forever", systemImage: "trash")
      }
    } else {
      Button {
        onEdit(snapshot)
      } label: {
        Label("Edit", systemImage: "pencil")
      }
      if !snapshot.isCompleted {
        Button {
          bridge.perform(action: .markCompleted, id: snapshot.id)
        } label: {
          Label("Mark Completed", systemImage: "checkmark.circle")
        }
      }
      Button(role: .destructive) {
        bridge.perform(action: .delete, id: snapshot.id)
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  @ViewBuilder
  private func detailsContent(_ snapshot: NativeEntryDetailsSnapshot) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        NativeEntryDetailsBalanceCard(snapshot: snapshot)

        HStack(alignment: .firstTextBaseline) {
          Text("Payments")
            .font(.title2.weight(.bold))
          Spacer()
          if !snapshot.isDeleted {
            Button {
              bridge.perform(action: .addPayment, id: snapshot.id)
            } label: {
              Label("Add Payment", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
          }
        }

        if snapshot.payments.isEmpty {
          NativeEntryDetailsEmptyPayments()
          .opacity(snapshot.isDeleted ? 0.65 : 1)
          .allowsHitTesting(!snapshot.isDeleted)
        } else {
          NativeEntryDetailsPayments(
            payments: snapshot.payments,
            canDelete: !snapshot.isDeleted,
            onDelete: { paymentID in
              bridge.perform(action: .deletePayment, id: snapshot.id, paymentID: paymentID)
            }
          )
        }

        Button {
          if !snapshot.isDeleted { onEdit(snapshot) }
        } label: {
          NativeEntryDetailsNoteCard(note: snapshot.note, isEnabled: !snapshot.isDeleted)
        }
        .buttonStyle(.plain)
        .disabled(snapshot.isDeleted)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
  }
}

@available(iOS 26.0, *)
private struct NativeEntryDetailsBalanceCard: View {
  let snapshot: NativeEntryDetailsSnapshot

  private var colors: [Color] {
    if snapshot.isCompleted { return [Color.green.opacity(0.78), Color.green.opacity(0.98)] }
    return snapshot.isOwedToMe
      ? [Color(red: 0.36, green: 0.63, blue: 0.96), Color(red: 0.08, green: 0.39, blue: 0.84)]
      : [Color(red: 1.0, green: 0.63, blue: 0.28), Color(red: 0.96, green: 0.31, blue: 0.03)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(snapshot.isDeleted ? "Deleted" : snapshot.isCompleted ? "Completed" : snapshot.isOwedToMe ? "You are owed" : "You owe")
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.18), in: Capsule())
      Text("Remaining")
        .foregroundStyle(.white.opacity(0.92))
      Text(snapshot.remainingText)
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .layoutPriority(1)
      Divider().overlay(.white.opacity(0.34))
      HStack {
        metric("Original", snapshot.originalText)
        Rectangle().fill(.white.opacity(0.24)).frame(width: 1, height: 42)
        metric("Paid", snapshot.paidText)
      }
      Divider().overlay(.white.opacity(0.34))
      HStack {
        Text("Paid").foregroundStyle(.white.opacity(0.92))
        Spacer()
        Text("\(Int(snapshot.progress * 100))%")
          .fontWeight(.semibold)
          .foregroundStyle(.white)
      }
      ProgressView(value: snapshot.progress)
        .progressViewStyle(.linear)
        .tint(.white)
        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
        .background(.white.opacity(0.28), in: Capsule())
        .clipShape(Capsule())
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    )
    .shadow(color: colors[1].opacity(0.18), radius: 12, y: 6)
  }

  @ViewBuilder
  private func metric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.78))
      Text(value)
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@available(iOS 26.0, *)
private struct NativeEntryDetailsEmptyPayments: View {
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "wallet.pass")
        .font(.largeTitle)
        .foregroundStyle(.indigo)
        .padding(14)
        .background(.indigo.opacity(0.1), in: Circle())
      Text("No payments yet").font(.headline)
      Text("Add the first payment to track the remaining balance.")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(28)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

@available(iOS 26.0, *)
private struct NativeEntryDetailsPayments: View {
  let payments: [NativeEntryDetailsPayment]
  let canDelete: Bool
  let onDelete: (Int) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
        HStack(spacing: 12) {
          Image(systemName: "arrow.downward.circle.fill")
            .font(.title2)
            .foregroundStyle(.green)
          VStack(alignment: .leading, spacing: 3) {
            Text(payment.amountText).font(.headline.weight(.semibold)).foregroundStyle(.green)
            Text(payment.dateText).font(.caption).foregroundStyle(.secondary)
            if !payment.note.isEmpty { Text(payment.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
          }
          Spacer()
          if canDelete {
            Menu {
              Button(role: .destructive) { onDelete(payment.id) } label: {
                Label("Delete", systemImage: "trash")
              }
            } label: {
              Image(systemName: "ellipsis")
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .accessibilityLabel("Payment actions")
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        if index < payments.count - 1 { Divider().padding(.leading, 54) }
      }
    }
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

@available(iOS 26.0, *)
private struct NativeEntryDetailsNoteCard: View {
  let note: String
  let isEnabled: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "note.text")
        .font(.title2)
        .foregroundStyle(.indigo)
        .frame(width: 48, height: 48)
        .background(.indigo.opacity(0.1), in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text("Notes").font(.headline)
        Text(note.isEmpty ? "No notes added" : note)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      if isEnabled { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
    }
    .padding(16)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}
