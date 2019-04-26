//
//  SwiftPLPlayerView.swift
//  RTMP
//
//  Created by JLM on 2019/4/25.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit
import PLPlayerKit

protocol SwiftPLPlayerViewDelegate: class {
    func playerViewEnterFullScreen(playerView: SwiftPLPlayerView)
    func playerViewExitFullScreen(playerView: SwiftPLPlayerView)
    func playerViewWillPlay(playerView: SwiftPLPlayerView)
}

protocol SwiftPLControlViewDelegate: class {
    func controlViewClose(controlView: SwiftPLControlView)
    func controlView(controlView: SwiftPLControlView, speed: CGFloat)
    func controlView(controlView: SwiftPLControlView, ratio: SwiftPLPlayerRatio)
    func controlView(controlView: SwiftPLControlView, isBackgroundPlay: Bool)
    func controlViewMirror(controlView: SwiftPLControlView)
    func controlViewRotate(controlView: SwiftPLControlView)
    func controlViewCache(controlView: SwiftPLControlView) -> Bool
}

enum SwiftPLPlayerRatio {
    case PLPlayerRatioDefault
    case PLPlayerRatioFullScreen
    case PLPlayerRatio16x9
    case PLPlayerRatio4x3
}

class SwiftPLPlayerView: UIView, UIGestureRecognizerDelegate, SwiftPLControlViewDelegate {
    func controlViewRotate(controlView: SwiftPLControlView) {
        var mode = player.rotationMode.rawValue
        
        mode += 1
        if mode > PLPlayerRotationsMode.rotate180.rawValue {
            mode = PLPlayerRotationsMode.noRotation.rawValue
        }
        player.rotationMode = PLPlayerRotationsMode(rawValue: mode)!
    }
    
    func controlViewCache(controlView: SwiftPLControlView) -> Bool {
        if playerOption.optionValue(forKey: PLPlayerOptionKeyVideoCacheFolderPath) != nil {
            playerOption.setOptionValue(nil, forKey: PLPlayerOptionKeyVideoCacheFolderPath)
            playerOption.setOptionValue(nil, forKey: PLPlayerOptionKeyVideoCacheExtensionName)
            return false
        } else {
            let docPathDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
            playerOption.setOptionValue("\(docPathDir)/PLCache/", forKey: PLPlayerOptionKeyVideoCacheFolderPath)
            playerOption.setOptionValue("mp4", forKey: PLPlayerOptionKeyVideoCacheExtensionName)
            return true
        }
    }
    
    var isIphoneX: Bool = {
        if #available(iOS 11.0, *), UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0.0 > CGFloat(0.0) {
            return true
        } else {
            // Fallback on earlier versions
            return false
        }
    }()
    weak var delegate: SwiftPLPlayerViewDelegate?
    var media: PLMediaInfo!
    
    var topBarView: UIView!
    var titleLabel: UILabel!
    var moreButton: UIButton!
    var exitfullScreenButton: UIButton!
    
    var bottomBarView: UIView!
    var slider: UISlider!
    var playTimeLabel: UILabel!
    var durationLabel: UILabel!
    var bufferingView: UIProgressView!
    var enterFullScreenButton: UIButton!
    // 在bottomBarView上面的播放暂停按钮，全屏的时候，显示
    
    var playButton: UIButton!
    var pauseButton: UIButton!
    var thumbImageView: UIImageView!
    var deviceOrientation: UIDeviceOrientation!
    
    var player: PLPlayer!
    var playerOption: PLPlayerOption!
    var isNeedSetupPlayer: Bool = true
    
    var playTimer: Timer!
    
    // 在屏幕中间的播放和暂停按钮，全屏的时候，隐藏
    var centerPlayButton: UIButton!
    var centerPauseButton: UIButton!
    
    var snapshotButton: UIButton!
    var lockBtn: UIButton!
    var isLockScreen: Bool = false
    
    var panGesture: UIPanGestureRecognizer!
    var tapGesture: UITapGestureRecognizer!
    
    var controlView: SwiftPLControlView!
    
    // 很多时候调用stop之后，播放器可能还会返回请他状态，导致逻辑混乱，记录一下，只要调用了播放器的 stop 方法，就将 isStop 置为 YES 做标记
    var isStop: Bool!
    
    // 当底部的 bottomBarView 因隐藏的时候，提供两个 progrssview 在最底部，随时能看到播放进度和缓冲进度
    var bottomPlayProgreeeView: UIProgressView!
    var bottomBufferingProgressView: UIProgressView!
    
    /// 适配屏幕
    var edgeSpace: CGFloat!
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTap(gesture:)))
        addGestureRecognizer(tapGesture)
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(panGesture:)))
        addGestureRecognizer(panGesture)
        panGesture.delegate = self
        if isIphoneX {
            edgeSpace = 20
        } else {
            edgeSpace = 5
        }
        initTopBar()
        initBottomBar()
        initOtherUI()
        doStableConstraint()
        hideBottomProgressView()
        bottomBarView.backgroundColor = UIColor.init(white: 0.0, alpha: 0.2)
        topBarView.backgroundColor = UIColor.init(white: 0.0, alpha: 0.2)
        
        deviceOrientation = .unknown
        transformWithOrientation(.portrait)
    }
    
    deinit {
        unsetupPlayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func play() {
        if isNeedSetupPlayer {
            isNeedSetupPlayer = false
            setupPlayer()
        }
        isStop = false
        delegate?.playerViewWillPlay(playerView: self)
        addFullStreenNotify()
        addTimer()
        resetButton(true)
        if player.status == .statusReady || player.status == .statusOpen || player.status == .statusCaching || player.status == .statusPlaying || player.status == .statusPreparing || player.status == .statusUnknow || player.status == .statusStopped {
            player.play()
        }
    }
    
    public func stop() {
        guard let player = player else {
            return
        }
        player.stop()
        removeFullStreenNotify()
        resetUI()
        controlView.resetStatus()
        isStop = true
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    public func pause() {
        player.pause()
        resetButton(false)
    }
    
    public func resume() {
        delegate?.playerViewWillPlay(playerView: self)
        player.resume()
        resetButton(true)
    }
    
    public func configureVideo(enableRender: Bool) {
        player.enableRender = enableRender
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.panGesture {
            let point = gestureRecognizer.location(in: self)
            return !bottomBarView.frame.contains(point)
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == self.panGesture {
            let point = touch.location(in: self)
            return !bottomBarView.frame.contains(point)
        }
        return true
    }
}

extension SwiftPLPlayerView {
    private func initTopBar() {
        topBarView = UIView()
        
        titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 18.0)
        titleLabel.textColor = .white
        
        exitfullScreenButton = UIButton()
        exitfullScreenButton.setImage(UIImage(named: "player_back"), for: .normal)
        exitfullScreenButton.addTarget(self, action: #selector(clickExitFullScreenButton), for: .touchUpInside)
        
        moreButton = UIButton()
        moreButton.setImage(UIImage(named: "more"), for: .normal)
        moreButton.addTarget(self, action: #selector(clickMoreButton), for: .touchUpInside)
        topBarView.addSubview(titleLabel)
        topBarView.addSubview(exitfullScreenButton)
        topBarView.addSubview(moreButton)
        addSubview(topBarView)
    }
    
    private func initBottomBar() {
        bottomBarView = UIView()
        
        playTimeLabel = UILabel()
        playTimeLabel.font = UIFont.systemFont(ofSize: 12.0)
        playTimeLabel.textColor = .white
        playTimeLabel.text = "0:00:00"
        playTimeLabel.sizeToFit()
        
        durationLabel = UILabel()
        durationLabel.font = UIFont.systemFont(ofSize: 12.0)
        durationLabel.textColor = .white
        durationLabel.text = "0:00:00"
        durationLabel.sizeToFit()
        
        slider = UISlider()
        slider.isContinuous = false
        slider.setThumbImage(UIImage(named: "slider_thumb"), for: .normal)
        slider.maximumTrackTintColor = .clear
        slider.minimumTrackTintColor = UIColor.init(displayP3Red: 0.2, green: 0.2, blue: 0.8, alpha: 1)
        slider.addTarget(self, action: #selector(sliderValueChange), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouch), for: .touchDown)
        
        bufferingView = UIProgressView()
        bufferingView.tintColor = UIColor.white.withAlphaComponent(1)
        bufferingView.trackTintColor = UIColor.white.withAlphaComponent(0.33)
        
        enterFullScreenButton = UIButton(type: .custom)
        enterFullScreenButton.tintColor = .white
        enterFullScreenButton.setImage(UIImage(named: "full-screen"), for: .normal)
        enterFullScreenButton.addTarget(self, action: #selector(clickEnterFullScreenButton), for: .touchUpInside)
        
        playButton = UIButton()
        playButton.tintColor = .white
        playButton.setImage(UIImage(named: "player_play"), for: .normal)
        playButton.addTarget(self, action: #selector(clickPlayButton), for: .touchUpInside)
        
        pauseButton = UIButton(type: .custom)
        pauseButton.tintColor = .white
        pauseButton.setImage(UIImage(named: "player_stop"), for: .normal)
        pauseButton.addTarget(self, action: #selector(clickPauseButton), for: .touchUpInside)
        
        addSubview(bottomBarView)
        bottomBarView.addSubview(playButton)
        bottomBarView.addSubview(pauseButton)
        bottomBarView.addSubview(playTimeLabel)
        bottomBarView.addSubview(durationLabel)
        bottomBarView.addSubview(bufferingView)
        bottomBarView.addSubview(slider)
        bottomBarView.addSubview(enterFullScreenButton)
    }
    
    private func initOtherUI() {
//        self.gestureRecognizerShouldBegin(<#T##gestureRecognizer: UIGestureRecognizer##UIGestureRecognizer#>)
        thumbImageView = UIImageView()
        thumbImageView.contentMode = .scaleAspectFill
        clipsToBounds = true
        
        controlView = SwiftPLControlView(frame: self.bounds)
        controlView.isHidden = true
        controlView.delegate = self
        
        centerPlayButton = UIButton(type: .custom)
        centerPlayButton.tintColor = .white
        centerPlayButton.setImage(UIImage(named: "player_play"), for: .normal)
        centerPlayButton.addTarget(self, action: #selector(clickPlayButton), for: .touchUpInside)
        
        centerPauseButton = UIButton(type: .custom)
        centerPauseButton.tintColor = .white
        centerPauseButton.setImage(UIImage(named: "player_stop"), for: .normal)
        centerPauseButton.addTarget(self, action: #selector(clickPauseButton), for: .touchUpInside)
        
        snapshotButton = UIButton(type: .custom)
        snapshotButton.setImage(UIImage(named: "screen-cut"), for: .normal)
        snapshotButton.addTarget(self, action: #selector(clickSnapshotButton), for: .touchUpInside)
        
        lockBtn = UIButton(type: .custom)
        lockBtn.setImage(UIImage(named: "Unlock-nor"), for: .normal)
        lockBtn.setImage(UIImage(named: "Lock-nor"), for: .selected)
        lockBtn.addTarget(self, action: #selector(clickLockButton(_:)), for: .touchUpInside)
        
        bottomPlayProgreeeView = UIProgressView()
        bottomPlayProgreeeView.progressTintColor = UIColor.init(displayP3Red: 0.2, green: 0.2, blue: 0.8, alpha: 1)
        bottomPlayProgreeeView.trackTintColor = .clear
        
        bottomBufferingProgressView = UIProgressView()
        bottomBufferingProgressView.progressTintColor = .white
        bottomBufferingProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.33)
        
        insertSubview(thumbImageView, at: 0)
        addSubview(snapshotButton)
        addSubview(lockBtn)
        addSubview(centerPauseButton)
        addSubview(centerPlayButton)
        addSubview(controlView)
        addSubview(bottomBufferingProgressView)
        addSubview(bottomPlayProgreeeView)
        
        pauseButton.isHidden = true
        centerPauseButton.isHidden = true
    }
    
    private func doStableConstraint() {
        topBarView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(self.snp.top)
            make.height.equalTo(44)
        }
        
        exitfullScreenButton.snp.makeConstraints { (make) in
            make.centerY.equalTo(self.topBarView)
            make.left.equalTo(self.topBarView).offset(self.edgeSpace)
            make.width.equalTo(self.exitfullScreenButton.snp.height)
        }
        
        moreButton.snp.makeConstraints { (make) in
            make.centerY.equalTo(self.topBarView)
            make.right.equalTo(self.topBarView).offset(-self.edgeSpace)
            make.width.equalTo(self.moreButton.snp.height)
        }
        
        titleLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.exitfullScreenButton.snp.right).offset(16)
            make.right.equalTo(self.moreButton.snp.left)
            make.centerY.equalTo(self.topBarView)
        }
        
        bottomBarView.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(self.snp.bottom)
            make.height.equalTo(44)
        }
        
        slider.snp.makeConstraints { (make) in
            make.centerY.equalTo(self.bottomBarView)
            make.left.equalTo(self.playTimeLabel.snp.right).offset(5)
            make.right.equalTo(self.durationLabel.snp.left).offset(-5)
        }
        
        durationLabel.snp.makeConstraints { (make) in
            make.right.equalTo(self.enterFullScreenButton.snp.left)
            make.centerY.equalTo(self.bottomBarView)
            make.size.equalTo(self.durationLabel.bounds.size)
        }
        
        pauseButton.snp.makeConstraints { (make) in
            make.edges.equalTo(self.playButton)
        }
        
        centerPlayButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 64.0, height: 64.0))
        }
        
        centerPauseButton.snp.makeConstraints { (make) in
            make.edges.equalTo(self.centerPlayButton)
        }
        
        bufferingView.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.slider)
            make.centerY.equalTo(self.slider).offset(0.5)
        }
        
        playTimeLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.playButton.snp.right).offset(5)
            make.centerY.equalTo(self.bottomBarView)
            make.width.equalTo(50)
        }
        
        thumbImageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        snapshotButton.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-self.edgeSpace)
            make.size.equalTo(CGSize(width: 60.0, height: 60.0))
        }
        
        lockBtn.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(self.edgeSpace)
            make.size.equalTo(CGSize(width: 60.0, height: 60.0))
        }
        
        bottomBufferingProgressView.snp.makeConstraints { (make) in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(3)
        }
        
        bottomPlayProgreeeView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.bottomBufferingProgressView)
        }
        
        controlView.snp.makeConstraints { (make) in
            make.width.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(290)
        }
        
        controlView.isHidden = true
    }
    
    private func resetUI() {
        bufferingView.progress = 0
        slider.value = 0
        playTimeLabel.text = "0:00:00"
        durationLabel.text = "0:00:00"
        thumbImageView.isHidden = false
        
        resetButton(false)
        hideFullLoading()
        
        hideTopBar()
        hideBottomBar()
        hideBottomProgressView()
        doConstraintAnimation()
    }
    
    private func doConstraintAnimation() {
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }
}

extension SwiftPLPlayerView {
    private func unsetupPlayer() {
        stop()
        if player == nil {
            return
        }
        if player.playerView?.superview != nil {
            player.playerView?.removeFromSuperview()
        }
    }
    
    private func addTimer() {
        removeTimer()
        playTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
    }
    
    private func removeTimer() {
        guard let playTimer = playTimer else { return }
        playTimer.invalidate()
        self.playTimer = nil
    }
    
    private func resetButton(_ isPlaying: Bool) {
        playButton.isHidden = isPlaying
        pauseButton.isHidden = !isPlaying
        if isPlaying {
            centerPauseButton.isHidden = false
            centerPlayButton.isHidden = true
        } else {
            centerPauseButton.isHidden = true
            centerPlayButton.show()
        }
    }
    
    func setMedia(media: PLMediaInfo) {
        self.media = media
        titleLabel.text = media.detailDesc ?? ""
//        setupPlayer()
        isNeedSetupPlayer = true
    }
    
    func setupPlayer() {
        playerOption = PLPlayerOption.default()
        var format = kPLPLAY_FORMAT_UnKnown
//        let media = PLMediaInfo()
//        media.detailDesc = "视频"
        titleLabel.text = "感动中国"
//        let urlString = "rtmp://ossrs.net/live/123456"
        let urlString = media.videoURL ?? "" //"http://demo-videos.qnsdk.com/movies/apple.mp4"
        thumbImageView.isHidden = false
//        guard let urlString = media.videoURL else { return }
        if urlString.hasSuffix("mp4") {
            format = kPLPLAY_FORMAT_MP4
        } else if urlString.hasSuffix(".mp3") {
            format = kPLPLAY_FORMAT_MP3
        } else if urlString.hasPrefix("rtmp:") {
            format = kPLPLAY_FORMAT_FLV
        } else if urlString.hasSuffix(".m3u8") {
            format = kPLPLAY_FORMAT_M3U8
        }
        controlView.format = format
        playerOption.setOptionValue(format.rawValue, forKey: PLPlayerOptionKeyVideoPreferFormat)
        playerOption.setOptionValue(kPLLogNone.rawValue, forKey: PLPlayerOptionKeyLogLevel)
        guard let url = URL(string: urlString) else { return }
        player = PLPlayer(url: url, option: playerOption)
        guard let playerView = player.playerView else { return }
        insertSubview(playerView, at: 0)
        playerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        player.delegateQueue = DispatchQueue.main
        player.playerView?.contentMode = .scaleAspectFit
        player.loopPlay = true
        player.delegate = self
        
    }
    
    private func loo() {
        
    }
    
    private func transformWithOrientation(_ or: UIDeviceOrientation) {
        if or == self.deviceOrientation {
            return
        }
        
        if !(or == UIDeviceOrientation.portrait || UIDeviceOrientation.landscapeLeft == or || UIDeviceOrientation.landscapeRight == or) {
            return
        }
        
        let isFirst = UIDeviceOrientation.unknown == self.deviceOrientation
        if or == UIDeviceOrientation.portrait {
            removeGestureRecognizer(panGesture)
            snapshotButton.isHidden = true
            lockBtn.isHidden = true
            playButton.snp.remakeConstraints { (make) in
                make.centerY.equalTo(self.bottomBarView)
                make.left.equalTo(bottomBarView).offset(5)
                make.width.equalTo(0)
            }
            
            enterFullScreenButton.snp.remakeConstraints { (make) in
                make.right.equalTo(self.bottomBarView).offset(-5)
                make.centerY.equalTo(self.durationLabel)
            }
            
            centerPlayButton.snp.remakeConstraints { (make) in
                make.center.equalTo(self);
                make.size.equalTo(CGSize(width: 44.0, height: 44.0));
            }
            
            if !isFirst {
                hideTopBar()
                hideControlView()
                doConstraintAnimation()
                delegate?.playerViewExitFullScreen(playerView: self)
                if !(gestureRecognizers?.contains(tapGesture) ?? false) {
                    addGestureRecognizer(tapGesture)
                }
            }
            
            UIView.animate(withDuration: 0.25) {
                self.transform = CGAffineTransform(rotationAngle: 0)
            }
        } else {
            if !(gestureRecognizers?.contains(panGesture) ?? false) {
                addGestureRecognizer(panGesture)
            }
            var duration = 0.5
            if !(self.deviceOrientation == UIDeviceOrientation.landscapeLeft || self.deviceOrientation == UIDeviceOrientation.landscapeRight) {
                duration = 0.3
                playButton.snp.remakeConstraints { (make) in
                    make.centerY.equalTo(self.bottomBarView)
                    make.left.equalTo(self.bottomBarView).offset(self.edgeSpace)
                    make.width.equalTo(self.playButton.snp.height)
                }
                
                enterFullScreenButton.snp.remakeConstraints { (make) in
                    make.bottom.equalTo(self.bottomBarView)
                    make.right.equalTo(self.bottomBarView).offset(-self.edgeSpace)
                    make.width.equalTo(0)
                }
                
                centerPlayButton.snp.remakeConstraints { (make) in
                    make.center.equalTo(self)
                    make.size.equalTo(CGSize(width: 0.0, height: 0.0))
                }
                doConstraintAnimation()
            }
            UIView.animate(withDuration: duration) {
                self.transform = UIDeviceOrientation.landscapeLeft == or ? CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2.0)) : CGAffineTransform(rotationAngle: CGFloat(3.0 * Double.pi / 2.0))
            }
            if UIDeviceOrientation.unknown != self.deviceOrientation {
                delegate?.playerViewEnterFullScreen(playerView: self)
            }
        }
        self.deviceOrientation = or
    }
    
    private func addFullStreenNotify() {
        removeFullStreenNotify()
        NotificationCenter.default.addObserver(self, selector: #selector(recvDeviceOrientationChangeNotify(info:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    private func removeFullStreenNotify() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func recvDeviceOrientationChangeNotify(info: Notification) {
        let or = UIDevice.current.orientation
        if !isLockScreen {
            transformWithOrientation(or)
        }
    }
    
    private func isFullScreen() -> Bool {
        return UIDeviceOrientation.portrait != self.deviceOrientation
    }
}

// MARK: - 避免 pan 手势将 slider 手势给屏蔽掉
extension SwiftPLPlayerView {
    
}

extension SwiftPLPlayerView {
    func controlViewClose(controlView: SwiftPLControlView) {
        hideControlView()
        if !(self.gestureRecognizers?.contains(panGesture) ?? false) {
            addGestureRecognizer(panGesture)
        }
        
        if !(self.gestureRecognizers?.contains(tapGesture) ?? false) {
            addGestureRecognizer(tapGesture)
        }
    }
    
    func controlView(controlView: SwiftPLControlView, speed: CGFloat) {
        player.playSpeed = Double(speed)
    }
    
    func controlView(controlView: SwiftPLControlView, ratio: SwiftPLPlayerRatio) {
        var rc = CGRect(x: 0, y: 0, width: CGFloat(player.width), height: CGFloat(player.height))
        if ratio == .PLPlayerRatioDefault {
            player.videoClipFrame = .zero
        } else if ratio == .PLPlayerRatioFullScreen {
            player.videoClipFrame = rc
        } else if ratio == .PLPlayerRatio16x9 {
            var width: CGFloat = 0.0
            var height: CGFloat = 0.0
            if (rc.size.width / rc.size.height > 16.0 / 9.0) {
                height = rc.size.height
                width = rc.size.height * 16.0 / 9.0
                rc.origin.x = (rc.size.width - width ) / 2.0
            } else {
                width = rc.size.width
                height = rc.size.width * 9.0 / 16.0
                rc.origin.y = (rc.size.height - height ) / 2.0
            }
            rc.size.width = width
            rc.size.height = height
            player.videoClipFrame = rc
        } else if ratio == .PLPlayerRatio4x3 {
            var width: CGFloat = 0.0
            var height: CGFloat = 0.0
            if (rc.size.width / rc.size.height > 4.0 / 3.0) {
                height = rc.size.height
                width = rc.size.height * 4.0 / 3.0
                rc.origin.x = (rc.size.width - width ) / 2.0
            } else {
                width = rc.size.width
                height = rc.size.width * 3.0 / 4.0
                rc.origin.y = (rc.size.height - height ) / 2.0
            }
            rc.size.width = width
            rc.size.height = height
            player.videoClipFrame = rc
        }
        
    }
    
    func controlView(controlView: SwiftPLControlView, isBackgroundPlay: Bool) {
        player.isBackgroundPlayEnable = isBackgroundPlay
    }
    
    func controlViewMirror(controlView: SwiftPLControlView) {
        if player.rotationMode != .flipHorizonal {
            player.rotationMode = .flipHorizonal
        } else {
            player.rotationMode = .noRotation
        }
    }
}

// MARK: - configure UI State
extension SwiftPLPlayerView {
    private func showTopBar() {
        topBarView.snp.remakeConstraints { (make) in
            make.left.top.right.equalTo(self)
            make.height.equalTo(44)
        }
        snapshotButton.isHidden = false
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideBar), object: nil)
        perform(#selector(hideBar), with: nil, afterDelay: 3.0)
        
    }
    
    private func showBottomProgressView() {
//        bottomBufferingProgressView.isHidden = false
//        bottomPlayProgreeeView.isHidden = false
    }
    
    private func hideBottomProgressView() {
        bottomBufferingProgressView.isHidden = true
        bottomPlayProgreeeView.isHidden = true
    }
    
    private func showBottomBar() {
        bottomBarView.snp.remakeConstraints { (make) in
            make.left.bottom.right.equalTo(self)
            make.height.equalTo(44)
        }
        hideBottomProgressView()
    }
    
    private func hideBottomBar() {
        bottomBarView.snp.remakeConstraints { (make) in
            make.left.right.equalTo(self)
            make.top.equalTo(self.snp.bottom)
            make.height.equalTo(44)
        }
        
        snapshotButton.isHidden = true
        lockBtn.isHidden = true
        if player.status == .statusPlaying || player.status == .statusPaused || player.status == .statusCaching {
            showBottomProgressView()
        }
    }
    
    @objc private func hideBar() {
        guard let player = player else {
            print("hideBar 遇到nil播放器")
            return
        }
        if player.status != .statusPlaying {
            return
        }
        hideLockBtn()
        hideTopBar()
        hideBottomBar()
        centerPauseButton.isHidden = true
        doConstraintAnimation()
    }
    
    private func showBar() {
        if !isLockScreen {
            showBottomBar()
            centerPauseButton.isHidden = false
            if isFullScreen() {
                showTopBar()
            }
        }
        showLockBtn()
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideBar), object: nil)
        perform(#selector(hideBar), with: nil, afterDelay: 3.0)
    }
    
    private func hideLockBtn() {
        lockBtn.isHidden = true
    }
    
    private func showLockBtn() {
        lockBtn.isHidden = false
    }
    
    private func hideTopBar() {
        topBarView.snp.remakeConstraints { (make) in
            make.left.right.equalTo(self)
            make.bottom.equalTo(self.snp.top)
            make.height.equalTo(44)
        }
    }
    
    private func showControlView() {
        hideBar()
        hideTopBar()
        centerPauseButton.isHidden = true
        centerPlayButton.isHidden = true
        controlView.isHidden = false
        controlView.snp.remakeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        doConstraintAnimation()
    }
    
    private func hideControlView() {
        controlView.snp.remakeConstraints { (make) in
            make.width.top.bottom.equalTo(self)
            make.left.equalTo(self).offset(290)
        }
        
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        UIView.animate(withDuration: 0.25, animations: {
            self.layoutIfNeeded()
        }) { (_) in
            self.controlView.isHidden = true
        }
    }
}

extension SwiftPLPlayerView: PLPlayerDelegate {
    func playerWillBeginBackgroundTask(_ player: PLPlayer) {
        
    }
    
    func playerWillEndBackgroundTask(_ player: PLPlayer) {
        
    }
    
    func player(_ player: PLPlayer, statusDidChange state: PLPlayerStatus) {
        if isStop {
            if state == .statusPlaying || state == .statusPaused || state == .statusStopped || state == .statusError || state == .statusUnknow || state == .statusCompleted || state == .statusPreparing || state == .statusReady || state == .statusOpen {
                stop()
            }
        }
        if state == .statusPlaying || state == .statusPaused || state == .statusStopped || state == .statusError || state == .statusUnknow || state == .statusCompleted {
            hideFullLoading()
        } else if state == .statusPreparing || state == .statusReady || state == .statusCaching {
            showFullLoading()
            centerPauseButton.isHidden = true
        } else if state == .stateAutoReconnecting {
            showFullLoading()
            centerPauseButton.isHidden = true
        }
        
        if state == .statusPlaying {
            if self.bottomBarView.frame.origin.y >= self.bounds.size.height {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideBar), object: nil)
                perform(#selector(hideBar), with: nil, afterDelay: 3.0)
            }
        }
    }
    
    func player(_ player: PLPlayer, stoppedWithError error: Error?) {
//        hideWaiting()
        stop()
        print("发生错误被迫停止")
    }
    
    func player(_ player: PLPlayer, willRenderFrame frame: CVPixelBuffer?, pts: Int64, sarNumerator: Int32, sarDenominator: Int32) {
        DispatchQueue.main.async {
            if !UIApplication.shared.isIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }
    
    func player(_ player: PLPlayer, willAudioRenderBuffer audioBufferList: UnsafeMutablePointer<AudioBufferList>, asbd audioStreamDescription: AudioStreamBasicDescription, pts: Int64, sampleFormat: PLPlayerAVSampleFormat) -> UnsafeMutablePointer<AudioBufferList> {
        return audioBufferList
    }
    
    func player(_ player: PLPlayer, firstRender firstRenderType: PLPlayerFirstRenderType) {
        if firstRenderType == .video {
            thumbImageView.isHidden = true
        }
        slider.maximumValue = Float(CMTimeGetSeconds(self.player.totalDuration))
        slider.minimumValue = 0.0
        let fduration = CMTimeGetSeconds(self.player.totalDuration)
        let duration = Int(fduration + 0.5)
        let hour = duration / 3600
        let min = (duration % 3600) / 60
        let sec = duration % 60
        durationLabel.text = String(format: "%d:%02d:%02d", hour, min, sec)
    }
    
    func player(_ player: PLPlayer, loadedTimeRange timeRange: CMTime) {
        /*
         float startSeconds = 0;
         float durationSeconds = CMTimeGetSeconds(timeRange);
         CGFloat totalDuration = CMTimeGetSeconds(self.player.totalDuration);
         self.bufferingView.progress = (durationSeconds - startSeconds) / totalDuration;
         self.bottomBufferingProgressView.progress = self.bufferingView.progress;
         */
    }
}

extension SwiftPLPlayerView {
    @objc private func clickExitFullScreenButton() {
        transformWithOrientation(UIDeviceOrientation.portrait)
    }
    
    @objc private func clickMoreButton() {
        removeGestureRecognizer(panGesture)
        removeGestureRecognizer(tapGesture)
        showControlView()
    }
    
    @objc private func sliderValueChange() {
        player.seek(to: CMTime(value: CMTimeValue(slider.value * 1000), timescale: 1000))
    }
    
    @objc private func sliderTouch() {
        print("点击slider")
    }
    
    @objc private func clickEnterFullScreenButton() {
        if UIDeviceOrientation.landscapeRight == UIDevice.current.orientation {
            transformWithOrientation(.landscapeRight)
        } else {
            transformWithOrientation(.landscapeLeft)
        }
    }
    
    @objc private func clickPlayButton() {
        guard let player = player else {
            play()
            return
        }
        if player.status == .statusPaused {
            resume()
        } else {
            play()
        }
    }
    
    @objc private func clickPauseButton() {
        pause()
    }
    
    @objc private func clickSnapshotButton() {
        NSObject.haveAlbumAccess { [weak self] (isAuth) in
            guard let self = self else { return }
            if !isAuth {
                return
            }
            self.player.getScreenShot(completionHandler: { (image) in
                guard let image = image else { return }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            })
        }
    }
    
    @objc private func clickLockButton(_ sender: Any) {
        guard let btn = sender as? UIButton else { return }
        btn.isSelected = !btn.isSelected
        isLockScreen = btn.isSelected
    }
    
    @objc private func timerAction() {
        if ((player?.totalDuration) != nil) && player?.totalDuration.seconds != 0.0 {
            let totalDuration = player.totalDuration.seconds
            slider.value = Float(CMTimeGetSeconds(self.player.currentTime))
            
            let duration = Int(slider.value + 0.5)
            let hour = duration / 3600
            let min = (duration % 3600) / 60
            let sec = duration % 60
            playTimeLabel.text = String(format: "%d:%02d:%02d", hour, min, sec)
            bottomPlayProgreeeView.progress = Float(Double(slider.value) / totalDuration)
        }
        
    }
    
    @objc private func singleTap(gesture: UIGestureRecognizer) {
        guard let player = player else {
            play()
            return
        }
        if isNeedSetupPlayer || player.status == .statusStopped {
            play()
            return
        }
        
        if player.status == .statusPaused {
            resume()
            return
        }
        
        if player.status == .statusPlaying {
            if self.bottomBarView.frame.origin.y >= self.bounds.size.height {
                showBar()
            } else {
                hideBar()
            }
        }
    }
    
    @objc func panGesture(panGesture: UIPanGestureRecognizer) {
        //        if UIGestureRecognizerStateChanged
        if panGesture.state == UIGestureRecognizer.State.changed {
            let location = panGesture.location(in: panGesture.view)
            let translation = panGesture.translation(in: panGesture.view)
            panGesture.setTranslation(.zero, in: panGesture.view)
            let FULL_VALUE: CGFloat = 200.0
            let percent = translation.y / FULL_VALUE
            if location.x > self.bounds.width / 2 { // 调节音量
                var volume = player.getVolume()
                volume -= Float(percent)
                if volume < 0.01 {
                    volume = 0.01
                } else if volume > 3 {
                    volume = 3
                }
                player.setVolume(volume)
            } else { // 调节亮度
                var currentBrightness = UIScreen.main.brightness
                currentBrightness -= percent
                if currentBrightness < 0.1 {
                    currentBrightness = 0.1
                } else if currentBrightness > 1 {
                    currentBrightness = 1
                }
                UIScreen.main.brightness = currentBrightness
            }
            
        }
    }
}

let speedString: [String] = ["0.5", "0.75", "1.0", "1.25", "1.5"]
class SwiftPLControlView: UIView {
    var format: PLPlayFormat?
    var isIphoneX: Bool = {
        if #available(iOS 11.0, *), UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0.0 > CGFloat(0.0) {
            return true
        } else {
            // Fallback on earlier versions
            return false
        }
    }()
    weak var delegate: SwiftPLControlViewDelegate?
    var scrollView: UIScrollView!
    var speedControl: UISegmentedControl!
    var ratioControl: UISegmentedControl!
    var speedValueLabel: UILabel!
    var speedTitleLabel: UILabel!
    var playBackgroundButton: UIButton!
    var mirrorButton: UIButton!
    var rotateButton: UIButton!
    var cacheButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let bgView = UIView()
        bgView.backgroundColor = UIColor.init(white: 0, alpha: 0.5)
        addSubview(bgView)
        bgView.snp.makeConstraints { (make) in
            make.right.bottom.top.equalToSuperview()
            make.width.equalTo(290)
        }
        
        let dismissButton = UIButton(type: .custom)
        dismissButton.addTarget(self, action: #selector(clickCloseButton), for: .touchUpInside)
        addSubview(dismissButton)
        dismissButton.snp.makeConstraints { (make) in
            make.left.top.bottom.equalTo(self);
            make.right.equalTo(bgView.snp.left);
        }
        
        scrollView = UIScrollView()
        let contentView = UIView()
        let barView = UIView()
        barView.backgroundColor = UIColor.init(white: 0, alpha: 0.5)
        
        let title = UILabel()
        title.textAlignment = .center
        title.font = UIFont.systemFont(ofSize: 18.0)
        title.textColor = .white
        title.text = "播放设置"
        
        let closeButton = UIButton(type: .custom)
        closeButton.tintColor = .white
        closeButton.setImage(UIImage(named: "player_close"), for: .normal)
        closeButton.addTarget(self, action: #selector(clickCloseButton), for: .touchUpInside)
        
        bgView.addSubview(barView)
        bgView.addSubview(scrollView)
        bgView.addSubview(title)
        bgView.addSubview(closeButton)
        scrollView.addSubview(contentView)
        barView.snp.makeConstraints { (make) in
            make.left.right.top.equalTo(bgView)
            make.height.equalTo(50)
        }
        
        title.snp.makeConstraints { (make) in
            make.edges.equalTo(barView)
        }
        closeButton.snp.makeConstraints { (make) in
            make.top.bottom.equalTo(barView)
            make.right.equalTo(barView).offset(isIphoneX ? -20 : -5)
            make.width.equalTo(closeButton.snp.height)
        }
        scrollView.snp.makeConstraints { (make) in
            make.left.bottom.right.equalTo(bgView)
            make.top.equalTo(barView.snp.bottom)
        }
        contentView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.scrollView)
            make.width.equalTo(bgView)
        }
        speedTitleLabel = UILabel()
        speedTitleLabel.font = UIFont.systemFont(ofSize: 12.0)
        speedTitleLabel.textColor = UIColor(displayP3Red: 0.33, green: 0.66, blue: 1, alpha: 1)
        speedTitleLabel.sizeToFit()
        
        speedValueLabel = UILabel()
        speedValueLabel.font = UIFont.systemFont(ofSize: 12.0)
        speedValueLabel.textColor = UIColor(displayP3Red: 0.33, green: 0.66, blue: 1, alpha: 1)
        speedValueLabel.text = "1.0"
        let dic = [NSAttributedString.Key.foregroundColor : UIColor.init(white: 1, alpha: 0.5), NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12.0)]
        let dicS = [NSAttributedString.Key.foregroundColor : UIColor(displayP3Red: 0.33, green: 0.66, blue: 1, alpha: 1), NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12.0)]
        
        speedControl = UISegmentedControl(items: speedString)
        speedControl.addTarget(self, action: #selector(speedControlChange(control:)), for: .valueChanged)
        speedControl.setTitleTextAttributes(dicS, for: .selected)
        speedControl.setTitleTextAttributes(dic, for: .normal)
        speedControl.tintColor = .clear
        
        ratioControl = UISegmentedControl(items: ["默认", "全屏", "16:9", "4:3"])
        ratioControl.addTarget(self, action: #selector(ratioControlChange(control:)), for: .valueChanged)
        ratioControl.setTitleTextAttributes(dicS, for: .selected)
        ratioControl.setTitleTextAttributes(dic, for: .normal)
        ratioControl.tintColor = .clear
        
        var buttons: [UIButton] = [UIButton]()
        var buttonTitles: [String] = ["后台播放", "镜像反转", "旋转", "本地缓存"]
        var buttonImages: [String] = ["background_play", "mirror_swtich", "rotate", "save"]
        for i in [0, 1, 2, 3] {
            let btn = UIButton()
            btn.setImage(UIImage(named: buttonImages[i]), for: .normal)
            btn.setTitle(buttonTitles[i], for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0)
            buttons.append(btn)
        }
        
        playBackgroundButton = buttons[0]
        playBackgroundButton.addTarget(self, action: #selector(clickPlayBackgroundButton), for: .touchUpInside)
        mirrorButton = buttons[1]
        mirrorButton.addTarget(self, action: #selector(clickMirrorButton), for: .touchUpInside)
        rotateButton = buttons[2]
        rotateButton.addTarget(self, action: #selector(clickRotateButton), for: .touchUpInside)
        cacheButton = buttons[3]
        cacheButton.addTarget(self, action: #selector(clickCacheButton), for: .touchUpInside)
        
        contentView.addSubview(speedTitleLabel)
        contentView.addSubview(speedValueLabel)
        contentView.addSubview(speedControl)
        contentView.addSubview(ratioControl)
        contentView.addSubview(playBackgroundButton)
        contentView.addSubview(mirrorButton)
        contentView.addSubview(rotateButton)
        contentView.addSubview(cacheButton)
        
        playBackgroundButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: -10)
        mirrorButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: -10)
        cacheButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: -10)
        rotateButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 0)
        rotateButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -30, bottom: 0, right: 0)
        cacheButton.setTitle("缓存已开", for: .selected)
        speedTitleLabel.snp.makeConstraints { (make) in
            make.top.left.equalTo(contentView).offset(20)
            make.width.equalTo(self.speedTitleLabel.bounds.size.width)
        }
        
        speedValueLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.speedTitleLabel.snp.right).offset(5)
            make.centerY.equalTo(self.speedTitleLabel)
        }
        
        speedControl.snp.makeConstraints { (make) in
            make.left.equalTo(self.speedTitleLabel)
            make.right.equalTo(contentView).offset(-20)
            make.top.equalTo(self.speedTitleLabel.snp.bottom).offset(10)
            make.height.equalTo(44)
        }
        
        ratioControl.snp.makeConstraints { (make) in
            make.height.left.right.equalTo(self.speedControl)
            make.top.equalTo(self.speedControl.snp.bottom).offset(20)
        }
        
        playBackgroundButton.snp.makeConstraints { (make) in
            make.left.equalTo(self.speedControl)
            make.right.equalTo(contentView.snp.centerX)
            make.top.equalTo(self.ratioControl.snp.bottom).offset(20)
            make.height.equalTo(50)
        }
        
        mirrorButton.snp.makeConstraints { (make) in
            make.left.equalTo(self.playBackgroundButton.snp.right)
            make.size.centerY.equalTo(self.playBackgroundButton);
        }
        
        rotateButton.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.playBackgroundButton)
            make.top.equalTo(self.playBackgroundButton.snp.bottom).offset(20)
        }
        
        cacheButton.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.mirrorButton)
            make.height.equalTo(self.mirrorButton);
            make.centerY.equalTo(self.rotateButton);
            make.bottom.equalTo(contentView).offset(-20)
        }
        
        resetStatus()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func resetStatus() {
        speedControl.selectedSegmentIndex = 2
        ratioControl.selectedSegmentIndex = 0
        playBackgroundButton.isSelected = false
        cacheButton.isSelected = false
        speedValueLabel.text =  speedString[speedControl.selectedSegmentIndex]
    }
}

extension SwiftPLControlView {
    @objc private func clickCloseButton() {
        delegate?.controlViewClose(controlView: self)
    }
    
    @objc private func speedControlChange(control: UISegmentedControl) {
        if format != PLPlayFormat.init(2) {
            print("暂不支持操作")
            return
        }
        speedValueLabel.text = speedString[control.selectedSegmentIndex]
        let speed = speedString[control.selectedSegmentIndex]
        delegate?.controlView(controlView: self, speed: CGFloat(Double(speed) ?? 0.0))
    }
    
    @objc private func ratioControlChange(control: UISegmentedControl) {
        if format != PLPlayFormat.init(2) {
            print("暂不支持操作")
            return
        }
        var ratio: SwiftPLPlayerRatio?
        if control.selectedSegmentIndex == 0 {
            ratio = .PLPlayerRatioDefault
        } else if control.selectedSegmentIndex == 1 {
            ratio = .PLPlayerRatioFullScreen
        } else if control.selectedSegmentIndex == 2 {
            ratio = .PLPlayerRatio16x9
        } else if control.selectedSegmentIndex == 3 {
            ratio = .PLPlayerRatio4x3
        }
        delegate?.controlView(controlView: self, ratio: ratio ?? .PLPlayerRatioDefault)
    }
    
    @objc private func clickPlayBackgroundButton() {
        playBackgroundButton.isSelected = !playBackgroundButton.isSelected
        delegate?.controlView(controlView: self, isBackgroundPlay: playBackgroundButton.isSelected)
    }
    
    @objc private func clickMirrorButton() {
        delegate?.controlViewMirror(controlView: self)
    }
    
    @objc private func clickRotateButton() {
        delegate?.controlViewRotate(controlView: self)
    }
    
    @objc private func clickCacheButton() {
        cacheButton.isSelected = delegate?.controlViewCache(controlView: self) ?? false
    }
}
