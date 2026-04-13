import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation
import HotKey
import ServiceManagement
import SwiftUI

struct ContentView: View {
    @State private var inputSources:
        [(
            String,
            String
        )] = []
    @State private var inputText = ""
    @StateObject private var configManager = ConfigManager.shared
    @State private var orderedInputSourceIdList:
        [(
            String,
            Key?
        )] = []
    @State private var hotKeyList: [HotKey] = []
    @State private var showAccessibilityPermissionAlert = false
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginRequiresApproval = false
    @State private var launchAtLoginErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("setIME")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Assign shortcuts and switch input methods.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration")
                    .font(.headline)

                HStack {
                    TextField("", text: .constant(configManager.getConfigFilePath()))
                        .font(.caption)
                        .monospaced()
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(configManager.getConfigFilePath(), forType: .string)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy path to clipboard")
                }

                HStack(spacing: 8) {
                    Button("Reload") {
                        configManager.loadConfiguration()
                        refreshConfiguredInputMethods()
                    }

                    Button("Regenerate") {
                        configManager.regenerateConfiguration()
                        refreshConfiguredInputMethods()
                    }
                }

                Toggle("Open at Login", isOn: launchAtLoginBinding())

                if launchAtLoginRequiresApproval {
                    HStack(spacing: 8) {
                        Text("Approve setIME in Login Items to finish enabling this.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Open Login Items") {
                            openLoginItemsSettings()
                        }
                        .font(.caption)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcut Modifiers")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(ConfigManager.availableModifierCodes, id: \.self) { modifier in
                        Toggle(modifierDisplayName(modifier), isOn: modifierBinding(for: modifier))
                    }
                }

                Text("At least one modifier is required. Changes are saved immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Test Input")
                    .font(.headline)
                TextField("Type here to test the current input method", text: $inputText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Input Methods")
                        .font(.headline)
                    Spacer()
                    Text("Drag to match the macOS menu order.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                List {
                    ForEach(
                        Array(orderedInputSourceIdList.enumerated()),
                        id: \.element.0
                    ) { _, element in
                        let (id, key) = element

                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(configManager.getInputMethodDisplayName(for: id))
                                    .fontWeight(.medium)
                                Text(verbatim: id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(verbatim: hotKeyDescription(for: id, key: key))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Picker("Shortcut", selection: hotKeyBinding(for: id)) {
                                Text("None").tag("")
                                ForEach(ConfigManager.availableKeyCodes, id: \.self) { keyCode in
                                    Text(keyCode.uppercased()).tag(keyCode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 96)

                            Button("Switch Now") {
                                setInputSource(targetInputSourceId: id)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                    .onMove(perform: moveInputMethods)
                }
                .listStyle(.plain)
                .frame(minHeight: 220, maxHeight: 380)
            }
        }
        .padding(18)
        .frame(minWidth: 640, minHeight: 620)
        .onAppear {
            inputSources = getInputMethods()
            print(
                inputSources.map({
                    ($0.1, nil) as (String, String?)
                })
            )
            // Load input method list from configuration manager
            orderedInputSourceIdList = configManager.getInputMethodList()
            registerHotKeys()
            
            // Print configuration file path for user reference
            print("Configuration file path: \(configManager.getConfigFilePath())")

            checkAccessibilityPermission()
            refreshLaunchAtLoginState()
        }
        .alert(
            "Configuration Error",
            isPresented: Binding(
                get: {
                    configManager.configurationErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        configManager.configurationErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(configManager.configurationErrorMessage ?? "")
        }
        .alert("Accessibility Permission Required", isPresented: $showAccessibilityPermissionAlert) {
            Button("Open System Settings") {
                requestAccessibilityPermission()
                openAccessibilitySettings()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("setIME needs Accessibility permission to send the keyboard events used for switching input methods.")
        }
        .alert(
            "Login Item Error",
            isPresented: Binding(
                get: {
                    launchAtLoginErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        launchAtLoginErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchAtLoginErrorMessage ?? "")
        }
    }

    func launchAtLoginBinding() -> Binding<Bool> {
        Binding(
            get: {
                launchAtLoginEnabled
            },
            set: { isEnabled in
                updateLaunchAtLogin(isEnabled: isEnabled)
            }
        )
    }

    func refreshLaunchAtLoginState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginRequiresApproval = false
        case .requiresApproval:
            launchAtLoginEnabled = false
            launchAtLoginRequiresApproval = true
        default:
            launchAtLoginEnabled = false
            launchAtLoginRequiresApproval = false
        }
    }

    func updateLaunchAtLogin(isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }

        refreshLaunchAtLoginState()
    }

    func openLoginItemsSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
            )
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func checkAccessibilityPermission() {
        showAccessibilityPermissionAlert = !AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func refreshConfiguredInputMethods() {
        orderedInputSourceIdList = configManager.getInputMethodList()
        registerHotKeys()
    }

    func hotKeyBinding(for id: String) -> Binding<String> {
        Binding(
            get: {
                configManager.getInputMethodKeyCode(for: id)
            },
            set: { keyCode in
                configManager.updateInputMethodHotKey(
                    id: id,
                    keyCode: keyCode.isEmpty ? nil : keyCode
                )
                refreshConfiguredInputMethods()
            }
        )
    }

    func modifierBinding(for modifier: String) -> Binding<Bool> {
        Binding(
            get: {
                configManager.getHotKeyModifierCodes().contains(modifier)
            },
            set: { isEnabled in
                var modifiers = configManager.getHotKeyModifierCodes()

                if isEnabled {
                    if !modifiers.contains(modifier) {
                        modifiers.append(modifier)
                    }
                } else {
                    guard modifiers.count > 1 else {
                        return
                    }
                    modifiers.removeAll(where: { $0 == modifier })
                }

                configManager.updateHotKeyModifiers(modifiers)
                registerHotKeys()
            }
        )
    }

    func modifierDisplayName(_ modifier: String) -> String {
        switch modifier {
        case "command":
            return "Command"
        case "shift":
            return "Shift"
        case "option":
            return "Option"
        case "control":
            return "Control"
        default:
            return modifier.capitalized
        }
    }

    func hotKeyDescription(for id: String, key: Key?) -> String {
        guard key != nil else {
            return "Shortcut: not assigned"
        }

        let modifiers = configManager.getHotKeyModifierCodes()
            .map(modifierDisplayName)
            .joined(separator: " + ")
        let keyCode = configManager.getInputMethodKeyCode(for: id).uppercased()

        return "Shortcut: \(modifiers) + \(keyCode)"
    }
    
    func registerHotKeys() {
        let modifiers = configManager.getModifiers()

        hotKeyList = orderedInputSourceIdList.compactMap {
            (
                id,
                maybeKey
            ) in
            guard let key = maybeKey else {
                return nil
            }
            let hotKey = HotKey(
                key: key,
                modifiers: modifiers
            )
            hotKey.keyDownHandler = {
                setInputSource(
                    targetInputSourceId: id
                )
            }
            return hotKey
        }

        print("Registered \(hotKeyList.count) hotkeys with modifiers: \(modifiers)")
    }

    // Drag to reorder input methods
    func moveInputMethods(from source: IndexSet, to destination: Int) {
        orderedInputSourceIdList.move(fromOffsets: source, toOffset: destination)
        
        // Sync update to configuration manager
        configManager.updateInputMethodOrder(orderedInputSourceIdList)
    }
    
    func setInputSource(
        targetInputSourceId: String
    ) {
        let inputSourceIdList = orderedInputSourceIdList.map({
            $0.0
        })
        let currentInputMode = getCurrentInputMethodId()
        guard
            let currentPosition = inputSourceIdList.firstIndex(
                of: currentInputMode
            )
        else {
            print(
                "Unknown current"
            )
            return
        }
        guard
            let targetPosition = inputSourceIdList.firstIndex(
                of: targetInputSourceId
            )
        else {
            print(
                "Unknown target"
            )
            return
        }
        if currentPosition == targetPosition {
            return
        } else if currentPosition < targetPosition {
            let spaceCount = targetPosition - currentPosition
            print("Switching IME from \(currentInputMode) to \(targetInputSourceId); simulated Ctrl+Option+Space count: \(spaceCount)")
            simulateKeyPress(spaceCount: spaceCount)
        } else {
            let spaceCount = inputSourceIdList.count - currentPosition
                + targetPosition
            print("Switching IME from \(currentInputMode) to \(targetInputSourceId); simulated Ctrl+Option+Space count: \(spaceCount)")
            simulateKeyPress(spaceCount: spaceCount)
        }
    }

    func simulateKeyPress(
        spaceCount: Int = 1
    ) {
        let wait = { () -> Void in
            usleep(
                16000
            )
        }
        let source = CGEventSource(
            stateID: .hidSystemState
        )

        let optionKeyCode: CGKeyCode = 0x3A
        let controlKeyCode: CGKeyCode = 0x3B
        let spaceKeyCode: CGKeyCode = 0x31

        let optionKeyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: optionKeyCode,
            keyDown: true
        )
        let controlKeyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: controlKeyCode,
            keyDown: true
        )
        let spaceKeyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: spaceKeyCode,
            keyDown: true
        )
        let spaceKeyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x31,
            keyDown: false
        )
        let flags: CGEventFlags = [
            .maskAlternate,
            .maskControl,
        ]
        spaceKeyDown?.flags = flags
        spaceKeyUp?.flags = flags
        let controlKeyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: controlKeyCode,
            keyDown: false
        )
        let optionKeyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: optionKeyCode,
            keyDown: false
        )

        optionKeyDown?.post(
            tap: .cghidEventTap
        )
        controlKeyDown?.post(
            tap: .cghidEventTap
        )
        for _ in 0..<spaceCount {
            spaceKeyDown?.post(
                tap: .cghidEventTap
            )

            wait()
            spaceKeyUp?.post(
                tap: .cghidEventTap
            )
        }
        wait()

        controlKeyUp?.post(
            tap: .cghidEventTap
        )
        optionKeyUp?.post(
            tap: .cghidEventTap
        )
    }

    func getCurrentInputMethodId() -> String {
        let kbdType = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        if let id = TISGetInputSourceProperty(
            kbdType,
            kTISPropertyInputSourceID
        ) {
            return Unmanaged<CFString>.fromOpaque(
                id
            ).takeUnretainedValue() as String
        }
        return "Unknown"
    }

    func getInputMethods() -> [(
        String,
        String
    )] {
        let inputSourceNSArray =
            TISCreateInputSourceList(
                nil,
                false
            ).takeRetainedValue() as NSArray
        let inputSources = inputSourceNSArray as! [TISInputSource]
        let filteredInputSources = inputSources.filter({
            guard
                let cfType = TISGetInputSourceProperty(
                    $0,
                    kTISPropertyInputSourceIsSelectCapable
                )
            else {
                return false
            }
            return Unmanaged<AnyObject>.fromOpaque(
                cfType
            ).takeUnretainedValue() as! Bool
        })
        return filteredInputSources.compactMap { source in
            guard
                let localizedName = Unmanaged<CFString>.fromOpaque(
                    TISGetInputSourceProperty(
                        source,
                        kTISPropertyLocalizedName
                    )
                ).takeUnretainedValue() as String?,
                let inputSourceID = Unmanaged<CFString>.fromOpaque(
                    TISGetInputSourceProperty(
                        source,
                        kTISPropertyInputSourceID
                    )
                ).takeUnretainedValue() as String?
            else {
                return nil
            }
            if !inputSourceID.contains(
                "inputmethod"
            )
                && !inputSourceID.contains(
                    "keylayout"
                )
            {
                return nil
            }
            return (
                localizedName,
                inputSourceID
            )
        }
    }
}

#Preview {
    ContentView()
}
