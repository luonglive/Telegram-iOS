import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import ShareController

class ChatScheduleTimeControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASImageNode
    private let titleNode: ASTextNode
    private let separatorNode: ASDisplayNode
    private let cancelButton: HighlightableButtonNode
    private let doneButton: SolidRoundedButtonNode
    
    private let pickerView: UIDatePicker
    private let dateFormatter: DateFormatter
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var completion: ((Int32) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        let roundedBackground = generateStretchableFilledCircleImage(radius: 16.0, color: self.presentationData.theme.actionSheet.opaqueItemBackgroundColor)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false
        self.contentContainerNode.clipsToBounds = true
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.displaysAsynchronously = false
        self.contentBackgroundNode.displayWithoutProcessing = true
        self.contentBackgroundNode.image = roundedBackground
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.Conversation_ScheduleMessage_Title, font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
        
        self.separatorNode = ASDisplayNode()
        //self.separatorNode.backgroundColor = self.theme.controlColor
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setTitle(self.presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
        
        self.doneButton = SolidRoundedButtonNode(theme: self.presentationData.theme, height: 52.0, cornerRadius: 11.0, gloss: false)
        
        self.pickerView = UIDatePicker()
        self.pickerView.timeZone = TimeZone(secondsFromGMT: 0)
        self.pickerView.datePickerMode = .dateAndTime
        self.pickerView.date = Date() //Date(timeIntervalSince1970: Double(roundDateToDays(currentValue)))
        self.pickerView.locale = localeWithStrings(self.presentationData.strings)
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.timeStyle = .none
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeZone = TimeZone.current
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.cancelButton)
        self.contentContainerNode.addSubnode(self.doneButton)
        
        self.pickerView.timeZone = TimeZone.current
        self.pickerView.minuteInterval = 5
        self.pickerView.minimumDate = Date()
        self.pickerView.maximumDate = Date(timeIntervalSince1970: Double(Int32.max - 1))
        
        self.pickerView.setValue(self.presentationData.theme.actionSheet.primaryTextColor, forKey: "textColor")
        
        self.contentContainerNode.view.addSubview(self.pickerView)
        self.pickerView.addTarget(self, action: #selector(self.datePickerUpdated), for: .valueChanged)
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.completion?(Int32(strongSelf.pickerView.date.timeIntervalSince1970))
            }
        }
        
        self.updateButtonTitle()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    private func updateButtonTitle() {
        let calendar = Calendar.current
        let date = self.pickerView.date
        
        let time = stringForMessageTimestamp(timestamp: Int32(date.timeIntervalSince1970), dateTimeFormat: self.presentationData.dateTimeFormat)
        if calendar.isDateInToday(date) {
            self.doneButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendToday(time).0
        } else {
            self.doneButton.title = self.presentationData.strings.Conversation_ScheduleMessage_SendOn(self.dateFormatter.string(from: date), time).0
        }
    }
    
    @objc private func datePickerUpdated() {
        self.updateButtonTitle()
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleAreaHeight: CGFloat = 54.0
        let contentHeight = titleAreaHeight + bottomInset + 285.0
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleAreaHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 16.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let cancelSize = self.cancelButton.measure(CGSize(width: width, height: titleAreaHeight))
        let cancelFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
        
        let buttonInset: CGFloat = 16.0
        let buttonHeight = self.doneButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.doneButton, frame: CGRect(x: buttonInset, y: contentHeight - buttonHeight - insets.bottom - 10.0, width: contentFrame.width, height: buttonHeight))
        
        self.pickerView.frame = CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: contentFrame.width, height: 216.0))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: titleAreaHeight), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
    }
}
