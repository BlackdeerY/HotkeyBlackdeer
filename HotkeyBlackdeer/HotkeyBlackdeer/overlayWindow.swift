import Cocoa

class OverlayWindow: NSWindow {
    private let label: NSTextField
    
    private var closeWindowWorkItem: DispatchWorkItem?
    
    init() {
        let frame = NSRect(x: 0, y: 0, width: 260, height: 80)
        self.label = NSTextField(labelWithString: "")
        super.init(contentRect: frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        self.ignoresMouseEvents = true

        // contentView에 배경을 둘 UIView 역할의 NSView 추가
        let backgroundView = NSView(frame: frame)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.masksToBounds = true
        self.contentView = backgroundView

        label.alignment = .center
        label.textColor = .white
        label.frame = backgroundView.bounds
        label.autoresizingMask = [.width, .height]
        
        label.font = NSFont.boldSystemFont(ofSize: 20)
        label.backgroundColor = .clear
        label.isBordered = false
        
//        label.isBezeled = false       // 테두리 없애기
//        label.drawsBackground = false // 배경 없애기
        
        let labelFrame = backgroundView.bounds
        label.frame = NSRect(x: labelFrame.origin.x, y: labelFrame.origin.y - 28, width: labelFrame.width, height: labelFrame.height)
        label.autoresizingMask = [.width, .height]
        
        backgroundView.addSubview(label)
    }
    
    func setMessage(message: String) {
        self.label.stringValue = message
    }
    
    private var isShowing = false
    
    func scheduleWindowClose(seconds: Int) {
        // 이전 작업이 있다면 취소
        closeWindowWorkItem?.cancel()

        // 새로운 작업 생성
        let newWorkItem = DispatchWorkItem { [weak self] in
//            self.orderOut(nil)
            DispatchQueue.main.async {
                self?.orderOut(nil)
                self?.isShowing = false
            }
        }

        // 새 작업을 저장
        closeWindowWorkItem = newWorkItem

        // 일정 시간 후 창 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: newWorkItem)
    }
    
    func showFor(seconds: Int) {
        // 마우스 위치 얻기
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        
        // 마우스가 위치한 스크린 찾기
        var targetScreen: NSScreen?
        for screen in screens {
            if screen.frame.contains(mouseLocation) {
                targetScreen = screen
                break
            }
        }
        
        // 마우스가 위치한 화면이 있다면
        if let screen = targetScreen {
            let screenWidth = screen.frame.size.width
            let screenHeight = screen.frame.size.height
            let windowWidth: CGFloat = self.frame.size.width
            let windowHeight: CGFloat = self.frame.size.height
            
            // 화면 중앙 계산
            let centerX = (screenWidth - windowWidth) / 2 + screen.frame.origin.x
            let centerY = (screenHeight - windowHeight) / 2 + screen.frame.origin.y
            
            // 윈도우 위치 설정
            self.setFrameOrigin(NSPoint(x: centerX, y: centerY))
        }
        
        if (!isShowing) {
            self.orderFrontRegardless()
            isShowing = true
        }
        
        scheduleWindowClose(seconds: seconds)
    }
}
