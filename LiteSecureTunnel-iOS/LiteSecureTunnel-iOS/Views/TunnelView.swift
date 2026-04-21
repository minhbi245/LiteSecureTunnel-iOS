//
//  TunnelView.swift
//  LiteSecureTunnel-iOS
//
//  Created by Leo Nguyen on 20/4/26.
//

import SwiftUI

struct TunnelView: View {
    @StateObject private var vm = TunnelViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: vm.isConnected ? "lock.shield.fill" : "lock.shield")
                .font(.system(size: 72))
                .foregroundStyle(vm.isConnected ? .green : .secondary)

            Text("Lite Secure Tunnel")
                .font(.title2)
                .fontWeight(.semibold)

            Text(vm.statusText)
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle("Connect", isOn: Binding(
                get: { vm.isConnected },
                set: { _ in vm.toggle() }
            ))
            .toggleStyle(.switch)
            .padding(.horizontal, 40)
            .disabled(vm.isSimulator)

            if let err = vm.errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .onAppear { vm.onAppear() }
        .alert("Simulator Detected", isPresented: $vm.showSimulatorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("High-security features are disabled on virtual hardware.")
        }
    }
}

#Preview {
    TunnelView()
}
