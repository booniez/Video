//
//  PlayLongViewController.swift
//  RTMP
//
//  Created by JLM on 2019/4/25.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit
import SnapKit

class PlayLongViewController: UIViewController {
    var playerView: PLPlayerView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerView = PLPlayerView()
        playerView.delegate = self
        view.addSubview(playerView)
        playerView.snp.makeConstraints { (make) in
            make.center.size.equalToSuperview()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension PlayLongViewController: PLPlayerViewDelegate {
    func playerViewEnterFullScreen(playerView: PLPlayerView) {
//        guard let superView = UIApplication.shared.windows.first?.rootViewController?.view else { return }
        guard let superView = self.view else { return }
        playerView.removeFromSuperview()
        superView.addSubview(playerView)
        playerView.snp.makeConstraints { (make) in
            make.width.equalTo(superView.snp.height);
            make.height.equalTo(superView.snp.width);
            make.center.equalTo(superView);
        }
        superView.setNeedsUpdateConstraints()
        superView.updateConstraintsIfNeeded()
        UIView.animate(withDuration: 0.25) {
            superView.layoutIfNeeded()
        }
    }
    
    func playerViewExitFullScreen(playerView: PLPlayerView) {
        self.playerView.removeFromSuperview()
        view.addSubview(self.playerView)
        self.playerView.snp.makeConstraints { (make) in
            make.center.size.equalToSuperview()
        }
        view.setNeedsUpdateConstraints()
        view.updateConstraintsIfNeeded()
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    func playerViewWillPlay(playerView: PLPlayerView) {
        
    }
    
    
}
