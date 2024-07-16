import SwiftUI
import Carbon
import CoreGraphics

struct ContentView: View {
    @State private var inputSources: [(String, String)] = []
    @State private var inputText = ""

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
            TextField(
                "Input",
                text: $inputText
            )
            Button(
                "Set To Hiragana"
            ) {
                let inputSourceIdList = inputSources.map({ $0.1 })
                let currentInputMode = getCurrentInputMethodId()
                let currentPosition = inputSourceIdList.firstIndex(of: currentInputMode)
                print(currentPosition ?? "Unknown current")
                let targetPosition = inputSourceIdList.firstIndex(of: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
                print(targetPosition ?? "Unknown target")
                
                simulateKeyPress(
                    spaceCount: 2
                )
                print(getCurrentInputMethodId())
            }
        }
        .padding()
        .onAppear {inputSources = getInputMethods()
            print(
                inputSources
            )
        }
    }
    
    func simulateKeyPress(
        spaceCount: Int = 1
    ) {
        let wait = {() -> Void in
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
            .maskControl
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
        
        // 释放按键
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
        let inputSourceNSArray = TISCreateInputSourceList(
            nil,
            false
        ).takeRetainedValue() as NSArray
        let inputSources = inputSourceNSArray as! [TISInputSource]
        let filteredInputSources = inputSources.filter({
            guard let cfType = TISGetInputSourceProperty(
                $0,
                kTISPropertyInputSourceIsSelectCapable
            ) else {
                return false
            }
            return Unmanaged<AnyObject>.fromOpaque(
                cfType
            ).takeUnretainedValue() as! Bool
        })
        return filteredInputSources.compactMap { source in
            guard let localizedName = Unmanaged<CFString>.fromOpaque(
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
            if !inputSourceID.contains("inputmethod") && !inputSourceID.contains("keylayout")  {
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
