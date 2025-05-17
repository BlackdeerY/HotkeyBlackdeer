import Cocoa
import CoreAudio
import AudioToolbox
import Foundation

func runAppleScript(appleScript: String) {
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: appleScript) {
        scriptObject.executeAndReturnError(&error)
    }
}

func detectPlayingByAppleScript() -> Bool {
    if let script = NSAppleScript(source: applescriptDetectPlaying) {
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript Error: \(error)")
        } else {
            let resultBool = result.booleanValue
            return resultBool
        }
    } else {
        print("AppleScript Create Fail.")
    }
    return false
}

let applescriptAudioOutputToAirPlay = """
    set nextDeviceName to "홈팟미니" 

    tell application "System Events" to tell process "ControlCenter"
        repeat with menuBarItem in every menu bar item of menu bar 1
            if description of menuBarItem as text is "사운드" then
                set soundMenuBarItem to menuBarItem
                exit repeat
            end if
        end repeat
        
        click soundMenuBarItem
        
        set currentDevice to (first checkbox of scroll area 1 of group 1 of window "제어 센터" whose value is 1)
        set currentDeviceId to (value of attribute "AXIdentifier" of currentDevice)
        set currentDeviceName to text 14 thru -1 of currentDeviceId

        if currentDeviceName is not equal to nextDeviceName then
            delay 0.2
            repeat with currentCheckbox in every checkbox of scroll area 1 of group 1 of window "제어 센터"
                set deviceId to value of attribute "AXIdentifier" of currentCheckbox
                set deviceName to text 14 thru -1 of deviceId
                if deviceName as string is equal to nextDeviceName as string then
                    click currentCheckbox
                    exit repeat
                end if
            end repeat
        end if

        click soundMenuBarItem
        
    end tell
"""

let applescriptDetectPlaying = """
    tell application "System Events" to tell process "ControlCenter"
        repeat with menuBarItem in every menu bar item of menu bar 1
            if description of menuBarItem as text is "지금 재생 중" then
                return true
            end if
        end repeat
    end tell
    return false
"""

//let applescriptAudioOutputToBlackHole16ch = """
//    set nextDeviceName to "BlackHole 16ch" 
//
//    tell application "System Events" to tell process "ControlCenter"
//        repeat with menuBarItem in every menu bar item of menu bar 1
//            if description of menuBarItem as text is "사운드" then
//                set soundMenuBarItem to menuBarItem
//                exit repeat
//            end if
//        end repeat
//        
//        click soundMenuBarItem
//        
//        set currentDevice to (first checkbox of scroll area 1 of group 1 of window "제어 센터" whose value is 1)
//        set currentDeviceId to (value of attribute "AXIdentifier" of currentDevice)
//        set currentDeviceName to text 14 thru -1 of currentDeviceId
//
//        if currentDeviceName is not equal to nextDeviceName then
//            repeat with currentCheckbox in every checkbox of scroll area 1 of group 1 of window "제어 센터"
//                set deviceId to value of attribute "AXIdentifier" of currentCheckbox
//                set deviceName to text 14 thru -1 of deviceId
//                if deviceName as string is equal to nextDeviceName as string then
//                    click currentCheckbox
//                    exit repeat
//                end if
//            end repeat
//        end if
//
//        click soundMenuBarItem
//        
//    end tell
//"""

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

func setDefaultOutputDevice(deviceName: String) -> Bool {
    var result = false
    
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size * 32)
    var devices = [AudioDeviceID](repeating: 0, count: 32)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &propertySize,
        &devices
    )

    if status != noErr {
        print("Error getting device list")
        return result
    }

    let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size

    for i in 0..<deviceCount {
        var deviceNameCF: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let nameStatus = AudioObjectGetPropertyData(
            devices[i],
            &nameAddress,
            0,
            nil,
            &size,
            &deviceNameCF
        )

        if nameStatus == noErr, deviceName == (deviceNameCF as String) {
            var defaultOutputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var outputDeviceID = devices[i]
            let setStatus = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultOutputAddress,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &outputDeviceID
            )

            if setStatus != noErr {
                print("Failed to set output device")
            } else {
                result = true
//                print("Output device set to \(deviceName)")
            }

            return result
        }
    }

    print("Device named '\(deviceName)' not found")
    return result
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
        if flags.contains(.maskControl) { modifiers.append("ctrl") }
        if flags.contains(.maskAlternate) { modifiers.append("option") }
        if flags.contains(.maskShift) { modifiers.append("shift") }

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
                            let openKakaoTalkSuccess = try? NSWorkspace.shared.open(appURL)
                            if (openKakaoTalkSuccess == nil) {
                                overlayWindow.setMessage(message: "💬카카오톡 실행 실패⚠️")
                                print("(try? NSWorkspace.shared.open(appURL) try 실패!!)")
                            } else if (openKakaoTalkSuccess!) {
                                overlayWindow.setMessage(message: "💬카카오톡 실행🟢")
                            } else {
                                overlayWindow.setMessage(message: "💬카카오톡 실행 실패⚠️")
                                print("(NSWorkspace.shared.open(appURL) 성공했지만 앱 실행은 실패!!)")
                            }
                        } else {
                            overlayWindow.setMessage(message: "💬카카오톡 설치 필요⚠️")
                        }
                    }
                    DispatchQueue.main.async {
                        overlayWindow.showFor(seconds: 2)
                    }
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
                if (keyCode == 80 || keyCode == 79) {
                    let prevVolume: Float? = getCurrentVolume()
                    if (keyCode == 80) {    // F19
                        HIDPostAuxKey(key: NX_KEYTYPE_SOUND_UP)
                    } else if (keyCode == 79) {    // F18
                        HIDPostAuxKey(key: NX_KEYTYPE_SOUND_DOWN)
                    }
                    if (prevVolume != nil) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: {
                            let newVolume: Float? = getCurrentVolume()
                            if (newVolume != nil) {
                                var messageString: String?
                                if (newVolume! == 1.0) {
                                    messageString = "최대📢"
                                } else if (newVolume! == 0.0) {
                                    messageString = "무음🚫"
                                } else if (newVolume! > prevVolume!) {
                                    messageString = "증가⬆️"
                                } else if (newVolume! < prevVolume!) {
                                    messageString = "감소⬇️"
                                } else {
                                    messageString = "그대로"
                                    print("(볼륨이 최소나 최대가 아닌데도 볼륨을 변경하지 못 했음!!)")
                                }
                                if (messageString != nil) {
                                    overlayWindow.setMessage(message: "🔈볼륨 \(messageString!) \(Int(round(newVolume! * 100)))")
                                    DispatchQueue.main.async {
                                        overlayWindow.showFor(seconds: 2)
                                    }
                                } else {
                                    print("(새 볼륨을 가져오지 못 했음!!)")
                                }
                            }
                        })
                    } else {
                        print("(기존 볼륨을 가져오지 못 했음!!)")
                    }
                } else if (keyCode == 64) {    // F17
                    let isPlaying = detectPlayingByAppleScript()
                    if (isPlaying) {
                        HIDPostAuxKey(key: NX_KEYTYPE_PLAY)
                    }
                }
            } else if (modifierString == "ctrl+option+shift") {
                if (keyCode == 79) {    // F18
                    let isOK = setDefaultOutputDevice(deviceName: "BlackHole 16ch")
                    if (isOK) {
                        overlayWindow.setMessage(message: "🔈사운드 출력: 기본🟢")
                    } else {
                        overlayWindow.setMessage(message: "🔈사운드 출력 변경 실패⚠️")
                    }
                    DispatchQueue.main.async {
                        overlayWindow.showFor(seconds: 2)
                    }
                } else if (keyCode == 80) {    // F19
                    runAppleScript(appleScript: applescriptAudioOutputToAirPlay)
                    overlayWindow.setMessage(message: "🔈사운드 출력: 홈팟미니🛜")
                    DispatchQueue.main.async {
                        overlayWindow.showFor(seconds: 2)
                    }
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
* Ctrl + Option + Shift + F18: Audio Output Device to Default.
* Ctrl + Option + Shift + F19: Audio Output Device to AirPlay.
===================================================================
""")

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)
CFRunLoopRun()
