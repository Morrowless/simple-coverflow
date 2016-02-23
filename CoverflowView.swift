//
//  CoverflowView.swift
//  Drydock
//
//  Created by Morrowless on 2/16/16.
//

import Foundation

/*

Simple coverflow-like view presentation inside a square container.
Not scrollable.

*/

enum CoverflowPosition
{
    case Next
    case Previous
}

protocol CoverflowViewDelegate: class
{
    func coverflowViewDidFinishMaximizingContent(atPosition position: CoverflowPosition)
    func coverflowViewDidFinishPresentingNext()

}

class BasicAnimation:CABasicAnimation
{
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    override init()
    {
        super.init()
        
        self.beginTime = CACurrentMediaTime()
        self.fillMode = kCAFillModeForwards
        self.removedOnCompletion = false
        self.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    }
}

class CoverflowView: UIView
{
    // MARK:- constants
    static let side = min(screen_width(), screen_height())
    static let magicNumber: CGFloat = -0.002
    static let presentDuration: NSTimeInterval = 1.2
    static let maximizeDuration: NSTimeInterval = 0.8
    
    // MARK:- private vars
    private var presentNextCalled = false
    private var currentView: UIView!
    private var currentViewContent: UIView!
    private var nextView: UIView!
    private var headingLabel: UILabel!
    private var contentLabel: UILabel!
    private var currentViewDarken: UIView!
    private var nextViewLeader: Leader!

    private var minimizeCurrentInitial: CATransform3D =
    {
        var t = CATransform3DIdentity
        t.m34 = CoverflowView.magicNumber
        return t
    }()
    
    private var minimizeCurrentTerminal: CATransform3D =
    {
        var t = CATransform3DIdentity
        t.m34 = CoverflowView.magicNumber
        t = CATransform3DTranslate(t, side * -0.52, 0, side * -1.7)
        t = CATransform3DRotate(t, radians(45), 0, 1, 0)
        
        return t
    }()
    
    private var dismissCurrentTerminal: CATransform3D =
    {
        var t = CATransform3DIdentity
        t.m34 = CoverflowView.magicNumber
        
        t = CATransform3DTranslate(t, side * -1.4, 0, side * -2.8)
        t = CATransform3DRotate(t, radians(120), 0, 1, 0)
        return t
    }()
    
    private var presentNextInitial: CATransform3D =
    {
        var t = CATransform3DIdentity
        t.m34 = CoverflowView.magicNumber
        t = CATransform3DTranslate(t, side * 1.1, 0, 0)
        t = CATransform3DRotate(t, radians(-45), 0, 1, 0)
        return t
    }()
    
    private var presentNextTerminal: CATransform3D =
    {
        var t = CATransform3DIdentity
        t.m34 = CoverflowView.magicNumber
        t = CATransform3DTranslate(t, side * 0.26, 0, side * -1.0)
        return t
    }()
    
    private var maximizeNextTerminal: CATransform3D =
    {
        var t = CATransform3DIdentity
        t.m34 = CoverflowView.magicNumber
        return t
    }()
    
    private var replayButton: UIButton!
    private var nextButton: UIButton!
    
    // MARK:- public vars
    weak var delegate: CoverflowViewDelegate?
    var headingText: String?
    {
        didSet
        {
            if let headingText = self.headingText
            {
                let side = min(screen_width(), screen_height())
                self.headingLabel = DesignManager.sui.designedLabel(headingText, enFontSize: 32, fontWeight: .Regular, alignment: .Left, width: side, color: UIColor(hex: "ffffff"), numLines: 1)
                self.headingLabel.frame = CGRect(x: 0, y: -self.headingLabel.bounds.size.height - 18, width: self.headingLabel.bounds.size.width, height: self.headingLabel.bounds.size.height)
                self.nextView.addSubview(self.headingLabel)
                
                
            }
        }
    }
    
    var contentText: String?
    {
        didSet
        {
            if let contentText = self.contentText
            {
                let side = min(screen_width(), screen_height())
                self.contentLabel = DesignManager.sui.designedLabel(contentText, enFontSize: 24, fontWeight: .Regular, alignment: .Left, width: side, color: UIColor(hex: "ffffff"), numLines: 3)
                self.contentLabel.frame = CGRect(x: 0, y: side + 20, width: self.contentLabel.bounds.size.width, height: self.contentLabel.bounds.size.height)
                self.nextView.addSubview(self.contentLabel)
            }
        }
    }
    
    
    // set this when next content is fetched and ready to be displayed
    var nextViewContent: UIView?
    {
        didSet
        {
            if let nextViewContent = self.nextViewContent
            {
                nextViewContent.frame = self.bounds
                
                self.nextView.addSubview(nextViewContent)
                self.nextView.bringSubviewToFront(self.nextViewLeader)
                self.nextViewContent = nextViewContent
                
                if self.presentNextCalled
                {
                    self.presentNext_()
                }
            }
        }
    }
    
    // MARK:- init and funcs
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    init(viewContent: UIView)
    {
        super.init(frame: CGRectMake(0, 0, CoverflowView.side, CoverflowView.side))
        
        viewContent.frame = self.bounds
        self.currentViewContent = viewContent
        self.currentViewContent.layer.shouldRasterize = true
        self.currentViewContent.layer.rasterizationScale = UIScreen.mainScreen().scale
        
        self.currentView = UIView()
        self.currentView.frame = self.bounds
        self.currentView.addSubview(self.currentViewContent)
        self.addSubview(self.currentView)
        
        self.nextView = UIView()
        self.nextView.frame = self.bounds
        self.addSubview(self.nextView)
        self.nextView.layer.opacity = 0
        
        self.headingLabel = UILabel()
        self.contentLabel = UILabel()
        
        self.currentViewDarken = UIView()
        self.currentViewDarken.backgroundColor = UIColor(hex: "000000")
        self.currentViewDarken.frame = self.currentView.bounds
        self.currentView.addSubview(self.currentViewDarken)
        self.currentViewDarken.layer.opacity = 0
        
        
        self.replayButton = UIButton(type: .Custom)
        self.replayButton.frame = CGRect(x: CoverflowView.side * 0.06, y: CoverflowView.side * 0.25, width: CoverflowView.side * 0.3, height: CoverflowView.side * 0.5)
        self.replayButton.addTarget(self, action: "replayAction", forControlEvents: .TouchUpInside)
        self.replayButton.backgroundColor = UIColor(hex: "ff000000")
        self.replayButton.enabled = false
        self.addSubview(self.replayButton)
        
        self.nextButton = UIButton(type: .Custom)
        self.nextButton.frame = CGRect(x: CoverflowView.side * 0.35, y: CoverflowView.side * 0.20, width: CoverflowView.side * 0.6, height: CoverflowView.side * 0.6)
        self.nextButton.addTarget(self, action: "nextAction", forControlEvents: .TouchUpInside)
        self.nextButton.backgroundColor = UIColor(hex: "0000ff00")
        self.nextButton.enabled = false
        self.addSubview(self.nextButton)
        
        self.nextViewLeader = Leader(frame: self.bounds)
        self.nextViewLeader.frame = self.nextView.bounds
        self.nextViewLeader.delegate = self
        self.nextView.addSubview(self.nextViewLeader)
        
    }

    func replayAction()
    {
        self.nextViewLeader.cancelCountdown()
        self.maximizeView(atPosition: .Previous)
    }
    
    func nextAction()
    {
        self.nextViewLeader.cancelCountdown()
        self.maximizeView(atPosition: .Next)
    }

    
    // call this when caller is done showing current content (but may or may not be ready to show next)
    func presentNext()
    {
        self.presentNextCalled = true
        
        if let _ = self.nextViewContent
        {
            self.presentNext_()
        }
    }
    
    // called when showNextCalled is true and nextViewContent is non-nil
    private func presentNext_()
    {
        // add shadow to nextView content
        self.nextViewContent!.layer.shadowOpacity = 1
        self.nextViewContent!.layer.shadowOffset = CGSize(width: 0, height: 0)
        self.nextViewContent!.layer.shadowRadius = 20
        self.nextViewContent!.layer.shouldRasterize = true
        self.nextViewContent!.layer.rasterizationScale = UIScreen.mainScreen().scale
        
        // current view animation
        self.currentView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.currentView.layer.opacity = 1

        let currentAnimation = BasicAnimation(keyPath: "transform")
        currentAnimation.duration = CoverflowView.presentDuration
        currentAnimation.fromValue = NSValue(CATransform3D: self.minimizeCurrentInitial)
        currentAnimation.toValue = NSValue(CATransform3D: self.minimizeCurrentTerminal)
        
        self.currentView.layer.addAnimation(currentAnimation, forKey: nil)
        
        // next view animation
        self.nextView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.nextView.layer.opacity = 0
        
        let nextAnimationTransform = BasicAnimation(keyPath: "transform")
        nextAnimationTransform.duration = CoverflowView.presentDuration
        nextAnimationTransform.fromValue = NSValue(CATransform3D: self.presentNextInitial)
        nextAnimationTransform.toValue = NSValue(CATransform3D: self.presentNextTerminal)
        
        let nextAnimationAlpha = BasicAnimation(keyPath: "opacity")
        nextAnimationAlpha.duration = CoverflowView.presentDuration
        nextAnimationAlpha.toValue = 1

        
        self.nextView.layer.addAnimation(nextAnimationTransform, forKey: nil)
        self.nextView.layer.addAnimation(nextAnimationAlpha, forKey: nil)
        
        // darken current view
        let darkenCurrent = BasicAnimation(keyPath: "opacity")
        darkenCurrent.duration = CoverflowView.presentDuration
        darkenCurrent.fromValue = 0
        darkenCurrent.toValue = 0.3
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { () -> Void in
            
            self.nextButton.enabled = true
            self.replayButton.enabled = true
            self.delegate?.coverflowViewDidFinishPresentingNext()
            
            // auto maximize next with delay
            self.nextViewLeader.countDown(3)
        }
        
        self.currentViewDarken.layer.addAnimation(darkenCurrent, forKey: nil)
        CATransaction.commit()
        
        
    }
    
    private func maximizeView(atPosition position: CoverflowPosition)
    {
        self.nextButton.enabled = false
        self.replayButton.enabled = false
        
        if position == .Previous
        {
            // reverse of present next
            let currentAnimation = BasicAnimation(keyPath: "transform")
            currentAnimation.duration = CoverflowView.maximizeDuration
            currentAnimation.fromValue = NSValue(CATransform3D: self.minimizeCurrentTerminal)
            currentAnimation.toValue = NSValue(CATransform3D: self.minimizeCurrentInitial)
            
            let nextAnimation = BasicAnimation(keyPath: "transform")
            nextAnimation.duration = CoverflowView.maximizeDuration
            nextAnimation.fromValue = NSValue(CATransform3D: self.presentNextTerminal)
            nextAnimation.toValue = NSValue(CATransform3D: self.presentNextInitial)
            
            CATransaction.begin()
            CATransaction.setCompletionBlock { () -> Void in
                self.resetContents(fromPosition: position)
                self.delegate?.coverflowViewDidFinishMaximizingContent(atPosition: .Previous)
            }
            self.currentView.layer.addAnimation(currentAnimation, forKey: nil)
            self.nextView.layer.addAnimation(nextAnimation, forKey: nil)
            CATransaction.commit()
            
            // un-darken
            let undarken = BasicAnimation(keyPath: "opacity")
            undarken.duration = CoverflowView.maximizeDuration
            undarken.toValue = 0
            
            
            self.currentViewDarken.layer.addAnimation(undarken, forKey: nil)
            
        }
        else if position == .Next
        {
            // dismiss current
            let currentAnimation = BasicAnimation(keyPath: "transform")
            currentAnimation.duration = CoverflowView.maximizeDuration
            currentAnimation.toValue = NSValue(CATransform3D: self.dismissCurrentTerminal)
            
            let currentAnimationAlpha = BasicAnimation(keyPath: "opacity")
            currentAnimationAlpha.duration = CoverflowView.maximizeDuration
            currentAnimationAlpha.toValue = 0
            
            self.currentView.layer.addAnimation(currentAnimation, forKey: nil)
            self.currentView.layer.addAnimation(currentAnimationAlpha, forKey: nil)
            
            // maximize next
            let nextAnimation = BasicAnimation(keyPath: "transform")
            nextAnimation.duration = CoverflowView.maximizeDuration
            nextAnimation.toValue = NSValue(CATransform3D: self.maximizeNextTerminal)
            
            CATransaction.begin()
            CATransaction.setCompletionBlock { () -> Void in
                self.resetContents(fromPosition: position)
                self.delegate?.coverflowViewDidFinishMaximizingContent(atPosition: .Next)
            }
            self.nextView.layer.addAnimation(nextAnimation, forKey: nil)

            CATransaction.commit()
            
            // fade out current
            let fadeCurrent = BasicAnimation(keyPath: "opacity")
            fadeCurrent.duration = CoverflowView.maximizeDuration
            fadeCurrent.toValue = 0
            self.currentView.layer.addAnimation(fadeCurrent, forKey: nil)
            
            
            // fade out both labels
            let fadeHeading = BasicAnimation(keyPath: "opacity")
            fadeHeading.duration = CoverflowView.maximizeDuration / 2
            fadeHeading.toValue = 0
            
            let fadeContent = BasicAnimation(keyPath: "opacity")
            fadeContent.duration = CoverflowView.maximizeDuration / 2
            fadeContent.toValue = 0
            
            self.headingLabel.layer.addAnimation(fadeContent, forKey: nil)
            self.contentLabel.layer.addAnimation(fadeContent, forKey: nil)
            
            
            
        }
    }
    
    private func resetContents(fromPosition position: CoverflowPosition)
    {
        self.presentNextCalled = false
        
        self.nextViewContent!.removeFromSuperview()
        self.currentViewContent.removeFromSuperview()
        if position == .Next
        {
            self.currentViewContent = self.nextViewContent!
        }
        self.currentView.addSubview(self.currentViewContent)
        self.currentView.bringSubviewToFront(self.currentViewDarken)
        self.nextViewContent = nil
        
        self.nextView.layer.opacity = 0
        self.currentViewDarken.layer.removeAllAnimations()
        
        self.currentView.layer.removeAllAnimations()
        self.nextView.layer.removeAllAnimations()
        self.currentView.layer.transform = CATransform3DIdentity
        self.nextView.layer.transform = CATransform3DIdentity
        self.currentView.layer.opacity = 1
        
        self.currentViewContent.frame = self.currentView.bounds
        self.currentViewContent.backgroundColor = UIColor.redColor()

        self.contentLabel.layer.removeAllAnimations()
        self.headingLabel.layer.removeAllAnimations()
        
    }
}

extension CoverflowView: LeaderDelegate
{
    func countDownFinished() {
        
        self.maximizeView(atPosition: .Next)
    }
}

protocol LeaderDelegate: class
{
    func countDownFinished()
}

private class Leader: UIView
{
    weak var delegate: LeaderDelegate?
    
    private var cancelled = false
    private var countLabel: UILabel?
    private var pieShape: CAShapeLayer!
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let radius = self.bounds.size.width
        
        self.pieShape = CAShapeLayer()
        self.pieShape.frame = self.bounds
        self.pieShape.path = UIBezierPath(roundedRect: CGRect(x: -self.bounds.size.width / 2, y: -self.bounds.size.height / 2, width: self.bounds.size.width * 2, height: self.bounds.size.height * 2), cornerRadius: radius).CGPath
        self.pieShape.fillColor = UIColor.clearColor().CGColor
        self.pieShape.strokeColor = UIColor(hex: "ffffff80").CGColor
        self.pieShape.lineWidth = self.bounds.size.width * 2
        self.pieShape.strokeStart = 0
        self.pieShape.strokeEnd = 0
        
        self.clipsToBounds = true
        self.layer.addSublayer(self.pieShape)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cancelCountdown()
    {
        self.cancelled = true
        UIView.animateWithDuration(0.2, animations: { () -> Void in
            
            self.pieShape.opacity = 0
            self.countLabel!.layer.opacity = 0
            
            }) { (finished) -> Void in
                
                self.pieShape.removeAllAnimations()
                
        }
    }
    
    func countDown(from: Int)
    {
        self.pieShape.opacity = 1
        self.cancelled = false
        
        self.countLabel?.removeFromSuperview()
        self.countLabel = DesignManager.sui.designedLabel("\(from)", enFontSize: 220, fontWeight: .UltraLight, alignment: .Center, width: CGFloat.max, color: UIColor(hex: "ffffff"), numLines: 1)
        self.countLabel!.frame = CGRect(x: 0, y: 0, width: self.countLabel!.bounds.size.width, height: self.countLabel!.bounds.size.height)
        self.countLabel!.center = self.center
        self.addSubview(self.countLabel!)
        
        
        let countDown = BasicAnimation()
        countDown.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        countDown.keyPath = "strokeEnd"
        countDown.repeatCount = 1
        countDown.duration = 1
        countDown.fromValue = 0
        countDown.toValue = 1
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { () -> Void in
            
            if self.cancelled { return }
            
            if from <= 1
            {
                self.delegate?.countDownFinished()
            
                UIView.animateWithDuration(0.2) { () -> Void in
                    self.pieShape.opacity = 0
                    self.countLabel!.layer.opacity = 0
                }
            }
            else
            {
                self.countDown(from - 1)
            }
        }
        self.pieShape.addAnimation(countDown, forKey: nil)
        
        CATransaction.commit()

    }

}