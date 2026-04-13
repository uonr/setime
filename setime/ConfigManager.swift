import Foundation
import HotKey
import AppKit
import Carbon

// MARK: - Configuration Models

/// Represents a single input method configuration
struct InputMethodConfig: Codable {
    let id: String
    let keyCode: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case keyCode = "key_code"
    }
}

/// Main configuration structure for the application
struct AppConfig: Codable {
    var inputMethods: [InputMethodConfig]
    var hotKeyModifiers: [String]
    
    enum CodingKeys: String, CodingKey {
        case inputMethods = "input_methods"
        case hotKeyModifiers = "hotkey_modifiers"
    }
}

// MARK: - Configuration Manager

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    static let availableKeyCodes = [
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
    ]
    static let availableModifierCodes = ["command", "shift", "option", "control"]
    
    @Published var config: AppConfig?
    @Published var configurationErrorMessage: String?
    private let configFileName = "setime_config.json"
    
    private init() {
        loadConfiguration()
    }
    
    /// Get configuration file path
    private var configFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(configFileName)
    }
    
    /// Load configuration file
    func loadConfiguration() {
        configurationErrorMessage = nil

        // First try to load from Documents directory
        if FileManager.default.fileExists(atPath: configFileURL.path) {
            loadConfigFromURL(configFileURL)
        } else {
            // If no configuration file is found, create default configuration
            createDefaultConfiguration()
        }
    }
    
    /// Load configuration from specified URL
    private func loadConfigFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.config = try decoder.decode(AppConfig.self, from: data)
            print("Configuration loaded successfully from: \(url.path)")
        } catch {
            print("Failed to load configuration: \(error)")
            configurationErrorMessage = """
            Failed to load configuration file:
            \(url.path)

            \(error.localizedDescription)

            The existing file was left unchanged.
            """
        }
    }
    
    /// Create and save default configuration
    private func createDefaultConfiguration() {
        let availableInputMethods = getAvailableInputMethods()
        
        // Automatically assign hotkeys for the first few input methods
        let keyMappings = ["c", "d", "f", "g", "h", "j", "k", "l"]
        
        let inputMethodConfigs = availableInputMethods.enumerated().map { index, inputMethod in
            let keyCode = index < keyMappings.count ? keyMappings[index] : nil
            return InputMethodConfig(
                id: inputMethod.id,
                keyCode: keyCode
            )
        }
        
        let defaultConfig = AppConfig(
            inputMethods: inputMethodConfigs,
            hotKeyModifiers: ["command", "shift"]
        )
        
        self.config = defaultConfig
        saveConfiguration()
        
        print("Auto-generated configuration with \(inputMethodConfigs.count) input methods")
    }
    
    /// Get list of available input methods from system
    private func getAvailableInputMethods() -> [(id: String, name: String)] {
        let inputSourceNSArray = TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray
        let inputSources = inputSourceNSArray as! [TISInputSource]
        
        let filteredInputSources = inputSources.filter { source in
            guard let cfType = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
                return false
            }
            return Unmanaged<AnyObject>.fromOpaque(cfType).takeUnretainedValue() as! Bool
        }
        
        return filteredInputSources.compactMap { source in
            guard
                let localizedName = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                let inputSourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            else {
                return nil
            }
            
            let name = Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue() as String
            let id = Unmanaged<CFString>.fromOpaque(inputSourceID).takeUnretainedValue() as String
            
            // Only include input methods and keyboard layouts
            if id.contains("inputmethod") || id.contains("keylayout") {
                return (id: id, name: name)
            }
            
            return nil
        }
    }
    
    /// Save current configuration to file
    func saveConfiguration() {
        guard let config = self.config else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configFileURL)
            print("Configuration saved successfully to: \(configFileURL.path)")
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }
    
    /// Get input method list converted to application format
    func getInputMethodList() -> [(String, Key?)] {
        guard let config = self.config else { return [] }
        
        return config.inputMethods.map { inputMethod in
            let key = convertStringToKey(inputMethod.keyCode)
            return (inputMethod.id, key)
        }
    }

    /// Get configured key code string for an input method
    func getInputMethodKeyCode(for id: String) -> String {
        guard let config = self.config else { return "" }
        return config.inputMethods.first(where: { $0.id == id })?.keyCode ?? ""
    }

    /// Get configured modifier key code strings
    func getHotKeyModifierCodes() -> [String] {
        guard let config = self.config else { return ["command", "shift"] }
        return config.hotKeyModifiers
    }
    
    /// Get hotkey modifier keys
    func getModifiers() -> NSEvent.ModifierFlags {
        guard let config = self.config else { return [.command, .shift] }
        
        var modifiers: NSEvent.ModifierFlags = []
        
        for modifier in config.hotKeyModifiers {
            switch modifier.lowercased() {
            case "command", "cmd":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "option", "alt":
                modifiers.insert(.option)
            case "control", "ctrl":
                modifiers.insert(.control)
            default:
                break
            }
        }
        
        return modifiers.isEmpty ? [.command, .shift] : modifiers
    }
    
    /// Convert string to Key enum
    private func convertStringToKey(_ keyString: String?) -> Key? {
        guard let keyString = keyString?.lowercased() else { return nil }
        
        switch keyString {
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "0": return .zero
        default: return nil
        }
    }
    
    /// Get configuration file path (for display to user)
    func getConfigFilePath() -> String {
        return configFileURL.path
    }
    
    /// Get display name by input method ID
    func getInputMethodDisplayName(for id: String) -> String {
        let availableInputMethods = getAvailableInputMethods()
        return availableInputMethods.first(where: { $0.id == id })?.name ?? id
    }
    
    /// Update input method order and save to configuration file
    func updateInputMethodOrder(_ newOrder: [(String, Key?)]) {
        guard var config = self.config else { return }
        
        // Create hotkey mapping dictionary
        let keyMappings = Dictionary(uniqueKeysWithValues: config.inputMethods.map { 
            ($0.id, $0.keyCode) 
        })
        
        // Rebuild input method configuration array based on new order
        let newInputMethodConfigs = newOrder.map { (id, _) in
            InputMethodConfig(
                id: id,
                keyCode: keyMappings[id] ?? nil
            )
        }
        
        // Update configuration
        config.inputMethods = newInputMethodConfigs
        self.config = config
        
        // Save to file
        saveConfiguration()
        
        print("Input method order updated and saved to configuration file")
    }

    /// Update one input method hotkey and save to configuration file
    func updateInputMethodHotKey(id: String, keyCode: String?) {
        guard var config = self.config else { return }

        let normalizedKeyCode = keyCode?.lowercased()
        let nextKeyCode = normalizedKeyCode.flatMap { key in
            Self.availableKeyCodes.contains(key) ? key : nil
        }

        config.inputMethods = config.inputMethods.map { inputMethod in
            if inputMethod.id == id {
                return InputMethodConfig(id: inputMethod.id, keyCode: nextKeyCode)
            }

            if let nextKeyCode, inputMethod.keyCode == nextKeyCode {
                return InputMethodConfig(id: inputMethod.id, keyCode: nil)
            }

            return inputMethod
        }

        self.config = config
        saveConfiguration()
    }

    /// Update global hotkey modifiers and save to configuration file
    func updateHotKeyModifiers(_ modifiers: [String]) {
        guard var config = self.config else { return }

        let normalizedModifiers = Self.availableModifierCodes.filter { modifier in
            modifiers.contains(modifier)
        }

        config.hotKeyModifiers = normalizedModifiers.isEmpty
            ? ["command", "shift"]
            : normalizedModifiers
        self.config = config
        saveConfiguration()
    }
    
    /// Regenerate configuration file (based on current system input methods)
    func regenerateConfiguration() {
        print("Regenerating configuration file...")
        
        // Save current hotkey mappings
        let currentKeyMappings: [String: String?] = config?.inputMethods.reduce(into: [:]) { result, inputMethod in
            result[inputMethod.id] = inputMethod.keyCode
        } ?? [:]
        
        let availableInputMethods = getAvailableInputMethods()
        let keyMappings = ["c", "d", "f", "g", "h", "j", "k", "l"]
        
        let inputMethodConfigs = availableInputMethods.enumerated().map { index, inputMethod in
            // Prefer existing hotkey mappings, otherwise auto-assign
            let keyCode = currentKeyMappings[inputMethod.id] ?? (index < keyMappings.count ? keyMappings[index] : nil)
            return InputMethodConfig(
                id: inputMethod.id,
                keyCode: keyCode
            )
        }
        
        let newConfig = AppConfig(
            inputMethods: inputMethodConfigs,
            hotKeyModifiers: config?.hotKeyModifiers ?? ["command", "shift"]
        )
        
        self.config = newConfig
        saveConfiguration()
        
        print("Regeneration complete with \(inputMethodConfigs.count) input methods")
    }
}
