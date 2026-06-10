import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceViewModel()
    @State private var activeSheet: MainSheet?
    @State private var unlockOverlay: UnlockOverlayState?

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    if viewModel.devices.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.open")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("暂无门禁设备")
                                .font(.headline)
                            Text("点右上角添加设备")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 42)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.devices) { device in
                            DeviceCard(device: device, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                if let unlockOverlay = unlockOverlay {
                    UnlockOverlayView(state: unlockOverlay)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: 96)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .navigationTitle("白云通")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        #if DEBUG
                        Button(action: { activeSheet = .debugLog }) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.body.weight(.medium))
                        }
                        #endif
                        Button(action: { activeSheet = .manage }) {
                            Image(systemName: "gearshape")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
            .sheet(item: $activeSheet, onDismiss: viewModel.loadDevices) { sheet in
                switch sheet {
                case .manage:
                    DeviceManageView(viewModel: viewModel)
                case .debugLog:
                    DebugLogView()
                }
            }
            .onReceive(viewModel.$isUnlocking) { isUnlocking in
                if isUnlocking {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        unlockOverlay = .opening
                    }
                }
            }
            .onReceive(viewModel.$bluetoothStatus) { status in
                guard !status.isEmpty, !status.contains("正在") else { return }
                showUnlockResult(status)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func showUnlockResult(_ message: String) {
        let isSuccess = message.contains("已发送")
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            unlockOverlay = isSuccess ? .success(message) : .failure(message)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            guard !viewModel.isUnlocking else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                unlockOverlay = nil
            }
        }
    }
}

enum MainSheet: String, Identifiable {
    case manage
    case debugLog

    var id: String { rawValue }
}

enum UnlockOverlayState: Equatable {
    case opening
    case success(String)
    case failure(String)
}

struct UnlockOverlayView: View {
    let state: UnlockOverlayState

    private var title: String {
        switch state {
        case .opening:
            return "开门中"
        case .success:
            return "已发送"
        case .failure:
            return "未开门"
        }
    }

    private var message: String? {
        switch state {
        case .opening:
            return nil
        case .success(let message), .failure(let message):
            return message
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            icon
                .frame(width: 70, height: 70)

            Text(title)
                .font(.headline.weight(.semibold))

            if let message = message, message != title {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 176, height: 148)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 22, x: 0, y: 10)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .opening:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.75)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.red)
        }
    }
}

struct DeviceCard: View {
    let device: Device
    @ObservedObject var viewModel: DeviceViewModel
    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(device.mac)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if viewModel.devices.count > 1,
               let idx = viewModel.devices.firstIndex(where: { $0.id == device.id }) {
                HStack(spacing: 6) {
                    Button { viewModel.moveUp(device.id) } label: {
                        Image(systemName: "chevron.up")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .disabled(idx == 0 || viewModel.isUnlocking)

                    Button { viewModel.moveDown(device.id) } label: {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .disabled(idx == viewModel.devices.count - 1 || viewModel.isUnlocking)
                }
                .buttonStyle(.borderless)
            }

            Button(action: { viewModel.unlock(device) }) {
                HStack(spacing: 5) {
                    Image(systemName: "lock.open")
                        .font(.callout.weight(.semibold))
                    Text("开门")
                        .font(.callout.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isUnlocking)
            .opacity(viewModel.isUnlocking ? 0.55 : 1)
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button("编辑") { showEdit = true }
            Button("删除") { viewModel.deleteDevice(device.id) }
        }
        .sheet(isPresented: $showEdit, onDismiss: viewModel.loadDevices) {
            DeviceEditView(device: device, viewModel: viewModel)
        }
    }
}
