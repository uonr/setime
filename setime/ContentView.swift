import AppKit
import Carbon
import CoreGraphics
import Foundation
import HotKey
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

    var body: some View {
        VStack {
            Image(
                systemName: "globe"
            )
            .imageScale(
                .large
            )
            .foregroundStyle(
                .tint
            )
            
            // Configuration file information
            VStack(alignment: .leading, spacing: 4) {
                Text("Configuration file path:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("", text: .constant(configManager.getConfigFilePath()))
                        .font(.caption)
                        .monospaced()
                        .textFieldStyle(.plain)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(configManager.getConfigFilePath(), forType: .string)
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Copy path to clipboard")
                }
                
                HStack(spacing: 8) {
                    Button("Reload Configuration") {
                        configManager.loadConfiguration()
                        orderedInputSourceIdList = configManager.getInputMethodList()
                        registerHotKeys()
                    }
                    
                    Button("Regenerate Configuration") {
                        configManager.regenerateConfiguration()
                        orderedInputSourceIdList = configManager.getInputMethodList()
                        registerHotKeys()
                    }
                }
                .font(.caption)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
            
            TextField(
                "Test Input Field",
                text: $inputText
            )
            HStack(spacing: 8) {
                
                Text("Due to system limitations, the input method order cannot be obtained. Please manually edit the list below and keep the order consistent with the order in the system tray on the top right.")
            }
                
            List {
                ForEach(
                    Array(orderedInputSourceIdList.enumerated()),
                    id: \.element.0
                ) { index, element in
                    let (id, key) = element
                    
                    HStack {
                        // Drag handle icon
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                        
                        Button(action: {
                            setInputSource(
                                targetInputSourceId: id
                            )
                        }) {
                            HStack {
                                Text("Set To")
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(configManager.getInputMethodDisplayName(for: id))
                                        .padding(6)
                                        .monospaced()
                                    if let key = key {
                                        Text(verbatim: "Hotkey: \(configManager.getModifiers().description) + \(key)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .onMove(perform: moveInputMethods)
            }
            .listStyle(.plain)
            .frame(height: CGFloat(orderedInputSourceIdList.count * 60 + 20))
        }
        .padding()
        .frame(maxWidth: 500)
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
