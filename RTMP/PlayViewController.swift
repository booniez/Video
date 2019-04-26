//
//  PlayViewController.swift
//  RTMP
//
//  Created by JLM on 2019/4/25.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit
import PLPlayerKit
import SnapKit

class PlayViewController: PlayBaseViewController, PLPlayerDelegate {
    var player: PLPlayer!
    var playButton: UIButton!
    var thumbImageView: UIImageView!
    var closeButton: UIButton!
    var url: URL?
    var thumbImage: UIImage?
    var thumbImageURL: URL?
    var enableGesture: Bool? = true
    
    var effectView: UIVisualEffectView!
    var isDisapper: Bool?
    var panGesture: UIPanGestureRecognizer!
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        closeButton = UIButton(type: .custom)
        closeButton.tintColor = .white
        closeButton.setImage(UIImage(named: "close"), for: .normal)
        closeButton.addTarget(self, action: #selector(clickCloseButton), for: .touchUpInside)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 22.0
        thumbImageView = UIImageView(image: UIImage(named: "icon-1024"))
        thumbImageView.clipsToBounds = true
        thumbImageView.contentMode = .scaleAspectFill
        /*
         if (self.thumbImageURL) {
         [self.thumbImageView sd_setImageWithURL:self.thumbImageURL placeholderImage:self.thumbImageView.image];
         }
         if (self.thumbImage) {
         self.thumbImageView.image = self.thumbImage;
         }
         */
        
        view.addSubview(thumbImageView)
        thumbImageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        playButton = UIButton()
        playButton.isHidden = true
        playButton.addTarget(self, action: #selector(clickPlayButton), for: .touchUpInside)
        playButton.setImage(UIImage(named: "player_play"), for: .selected)
        playButton.setImage(UIImage(named: "player_stop"), for: .normal)
        playButton.tintColor = .white
        view.addSubview(playButton)
        playButton.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 60.0, height: 60.0))
        }
        
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { (make) in
            make.bottom.right.equalToSuperview().offset(-10)
            make.size.equalTo(CGSize(width: 44.0, height: 44.0))
        }
        
        let effect = UIBlurEffect(style: .light)
        effectView = UIVisualEffectView(effect: effect)
        thumbImageView.addSubview(effectView)
        effectView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapAction(gesture:)))
        view.addGestureRecognizer(singleTap)
        setupPlayer()
        enableGesture = true
        setEnableGesture(enable: true)
        
    }
    
    func setupPlayer() {
        let option = PLPlayerOption.default()
        var format = kPLPLAY_FORMAT_UnKnown
        guard let urlString = url?.absoluteString.lowercased() else { return }
        if urlString.hasSuffix("mp4") {
            format = kPLPLAY_FORMAT_MP4
        } else if urlString.hasSuffix(".mp3") {
            format = kPLPLAY_FORMAT_MP3
        } else if urlString.hasPrefix("rtmp:") {
            format = kPLPLAY_FORMAT_FLV
        } else if urlString.hasSuffix(".m3u8") {
            format = kPLPLAY_FORMAT_M3U8
        }
        option.setOptionValue(format.rawValue, forKey: PLPlayerOptionKeyVideoPreferFormat)
        option.setOptionValue(kPLLogNone.rawValue, forKey: PLPlayerOptionKeyLogLevel)
        player = PLPlayer(url: url, option: option)
        guard let playerView = player.playerView else { return }
        view.insertSubview(playerView, at: 0)
        playerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        player.delegateQueue = DispatchQueue.main
        player.playerView?.contentMode = .scaleAspectFit
        player.loopPlay = true
        player.delegate = self
        
    }
    
    @objc func clickCloseButton() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func clickPlayButton() {
        player.resume()
    }
    
    @objc func singleTapAction(gesture: UITapGestureRecognizer) {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    
    func playerWillBeginBackgroundTask(_ player: PLPlayer) {
        
    }
    
    func playerWillEndBackgroundTask(_ player: PLPlayer) {
        
    }
    
    func player(_ player: PLPlayer, statusDidChange state: PLPlayerStatus) {
        if isDisapper ?? false {
            stop()
            hideWaiting()
            return
        }
        if state == .statusPlaying || state == .statusPaused || state == .statusStopped || state == .statusError || state == .statusUnknow || state == .statusCompleted {
            hideWaiting()
        } else if state == .statusPreparing || state == .statusReady || state == .statusCaching {
            showWaiting()
        } else if state == .stateAutoReconnecting {
            showWaiting()
        }
    }
    
    func player(_ player: PLPlayer, stoppedWithError error: Error?) {
        hideWaiting()
//        guard let info = error.userInfo["NSLocalizedDescription"] as? String else {
//            return
//        }
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
    }
}

extension PlayViewController {
    func stop() {
        player.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func showWaiting() {
        playButton.isHidden = true
        // 展示占位图
        view.bringSubviewToFront(closeButton)
    }
    
    func hideWaiting() {
        // [self.view hideFullLoading];
        if PLPlayerStatus.statusPlaying != player.status {
            playButton.isHidden = false
        }
    }
    
    func setEnableGesture(enable: Bool) {
        if enableGesture ?? false == enable {
            return
        }
        enableGesture = enable
        if panGesture == nil {
            panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(panGesture:)))
        }
        if enableGesture ?? false {
            if !(view.gestureRecognizers?.contains(panGesture) ?? false) {
                view.addGestureRecognizer(panGesture)
            }
        } else {
            view.removeGestureRecognizer(panGesture)
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
            if location.x > view.bounds.width / 2 { // 调节音量
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
