import Cocoa
import CoreAudio
import AudioToolbox

//func runAppleScript(appleScript: String) {
//    var error: NSDictionary?
//    if let scriptObject = NSAppleScript(source: appleScript) {
//        scriptObject.executeAndReturnError(&error)
//    }
//}

let kakaoTalkAppBundleIdentifier = "com.kakao.KakaoTalkMac"

let volumeStep: Float = 0.1
let floatPrecision: Float = 0.0000001

let overlayWindow = OverlayWindow()

func getCurrentOutputDeviceID() -> AudioObjectID? {
    var deviceID: AudioObjectID = AudioObjectID(kAudioObjectSystemObject)
    var propertySize: UInt32 = UInt32(MemoryLayout<AudioObjectID>.size)
    
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,  // Default 출력 장치가 아니라 실제로 현재 출력 중인 장치
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    let result = AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &propertySize,
        &deviceID
    )
    
    if result == noErr {
        return deviceID
    } else {
        print("Error getting current output device ID. Error code: \(result)")
        return nil
    }
}

func getCurrentVolume() -> Float? {
    guard let deviceID = getCurrentOutputDeviceID() else {
        print("Unable to get current output device ID.")
        return nil
    }

    var volume: Float = 0.0
    var dataSize = UInt32(MemoryLayout.size(ofValue: volume))
    
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    let result = AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &volume
    )
    
    if result == noErr {
        return volume
    } else {
        print("Error getting volume from current output device: \(result)")
        return nil
    }
}

func setVolume(volume: Float) {
    guard let deviceID = getCurrentOutputDeviceID() else {
        print("Unable to get current output device ID.")
        return
    }

    var newVolume = volume
    if newVolume < 0.0 {
        newVolume = 0.0
    } else if newVolume > 1.0 {
        newVolume = 1.0
    }
    
    let dataSize = UInt32(MemoryLayout.size(ofValue: newVolume))
    
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    let result = AudioObjectSetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        dataSize,
        &newVolume
    )
    
    if result == noErr {
//        print("Volume set to \(newVolume * 100)%")
    } else {
        print("Error setting volume: \(result)")
    }
}

let NX_KEYTYPE_SOUND_UP: UInt32 = 0
let NX_KEYTYPE_SOUND_DOWN: UInt32 = 1
let NX_KEYTYPE_PLAY: UInt32 = 16
let NX_KEYTYPE_NEXT: UInt32 = 17
let NX_KEYTYPE_PREVIOUS: UInt32 = 18
let NX_KEYTYPE_FAST: UInt32 = 19
let NX_KEYTYPE_REWIND: UInt32 = 20

func HIDPostAuxKey(key: UInt32) {
    func doKey(down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: (down ? 0xa00 : 0xb00))
        let data1 = Int((key<<16) | (down ? 0xa00 : 0xb00))

        let ev = NSEvent.otherEvent(with: NSEvent.EventType.systemDefined,
                                    location: NSPoint(x:0,y:0),
                                    modifierFlags: flags,
                                    timestamp: 0,
                                    windowNumber: 0,
                                    context: nil,
                                    subtype: 8,
                                    data1: data1,
                                    data2: -1
                                    )
        let cev = ev?.cgEvent
        cev?.post(tap: CGEventTapLocation.cghidEventTap)
    }
    doKey(down: true)
    doKey(down: false)
}

let eventMask = (1 << CGEventType.keyDown.rawValue)

guard let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { _, _, event, _ in
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        var modifiers: [String] = []
        if flags.contains(.maskCommand) { modifiers.append("cmd") }
        if flags.contains(.maskAlternate) { modifiers.append("option") }
        if flags.contains(.maskShift) { modifiers.append("shift") }
        if flags.contains(.maskControl) { modifiers.append("ctrl") }

        let modifierString = modifiers.joined(separator: "+")
        if modifierString.isEmpty {
//            print("Key down: \(keyCode)")
        } else {
            if (modifierString == "option") {
                if (keyCode == 111) {   // F12
                    let runningApps = NSWorkspace.shared.runningApplications
                    if let app = runningApps.first(where: { $0.bundleIdentifier == kakaoTalkAppBundleIdentifier }) {
                        app.terminate()
                        overlayWindow.setMessage(message: "💬카카오톡 종료❌")
                    } else {
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: kakaoTalkAppBundleIdentifier) {
                            try? NSWorkspace.shared.open(appURL)
                            overlayWindow.setMessage(message: "💬카카오톡 실행🟢")
                        } else {
                            overlayWindow.setMessage(message: "💬카카오톡 필요⚠️")
                        }
                    }
                    overlayWindow.showFor(seconds: 2)
                }
//            } else if (modifierString == "option+shift") {
//                if (keyCode == 103 || keyCode == 111) {    // F11, F12
//                    if let currentVolume = getCurrentVolume() {
//                        //                        print("Current Volume: \(currentVolume)%")
//                        //                        let adjustedVolume: Float = floor((round(currentVolume * 10) / 10) / volumeStep) * volumeStep
//                        //                        let adjustedVolume: Float = floor(currentVolume / volumeStep) * volumeStep
//                        //                        var newVolume = adjustedVolume
//                        var newVolume: Float = floor(currentVolume / volumeStep) * volumeStep
//                        var messageString: String
//                        var willChange = false
//                        if (keyCode == 103) {    // F11
//                            if (currentVolume == 0.0) {
//                                messageString = "무음🚫"
//                            } else {
//                                messageString = "감소⬇️"
//                                if ((currentVolume - newVolume) < floatPrecision) {
//                                    newVolume -= volumeStep
//                                }
//                                willChange = true
//                            }
//                        } else {
//                            if (currentVolume == 1.0) {
//                                messageString = "최대📢"
//                            } else {
//                                messageString = "증가⬆️"
//                                newVolume += volumeStep
//                                if ((newVolume - currentVolume) < floatPrecision) {
//                                    newVolume += volumeStep
//                                }
//                                willChange = true
//                            }
//                        }
//                        if (newVolume > 1.0) {
//                            newVolume = 1.0
//                        } else if (newVolume < 0.0) {
//                            newVolume = 0.0
//                        }
//                        //                        print("\(currentVolume) -> \(adjustedVolume) -> \(newVolume)")
//                        if (willChange) {
//                            setVolume(volume: newVolume)
//                        }
//                        overlayWindow.setMessage(message: "🔈볼륨 \(messageString) \(Int(round(newVolume * 100)))")
//                        overlayWindow.showFor(seconds: 2)
//                    }
//                }
            } else if (modifierString == "shift") {
                if (keyCode == 80) {    // F19
                    HIDPostAuxKey(key: NX_KEYTYPE_SOUND_UP)
                } else if (keyCode == 79) {    // F18
                    HIDPostAuxKey(key: NX_KEYTYPE_SOUND_DOWN)
                } else if (keyCode == 64) {    // F17
                    HIDPostAuxKey(key: NX_KEYTYPE_PLAY)
                }
            }
//            print("Key down: \(modifierString)+\(keyCode)")
        }
        return Unmanaged.passRetained(event)
    },
    userInfo: nil
) else {
    print("❌ Failed to create event tap. Check accessibility permissions.")
    exit(1)
}

print("""
===================================================================
  HotkeyBlackdeer - https://github.com/BlackdeerY/HotkeyBlackdeer
-------------------------------------------------------------------
* Option + F12: Run/Quit KakaoTalk.
* Shift + F17: Play/Stop Media.
* Shift + F18: Decrease Volume.
* Shift + F19: Increase Volume.
===================================================================
""")

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)
CFRunLoopRun()
