//
//  ViewController.swift
//  RTMP
//
//  Created by JLM on 2019/4/24.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit
import PLPlayerKit

class ViewController: UIViewController, PLPlayerDelegate {
    var player: PLPlayer?
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var address: UITextField!
    @IBOutlet weak var bitLabel: UILabel!
    
    @IBAction func touch(_ sender: Any) {
        guard let btn = sender as? UIButton else { return }
//        btn.isSelected = !btn.isSelecte
////        player = nil
//        var option = PLPlayerOption.default()
//        player = PLPlayer(url: URL(string: address.text?.isEmpty ?? true ? "http://demo-videos.qnsdk.com/shortvideo/super.mp4" : address.text ?? ""), option: option)
//        player?.playerView?.contentMode = .scaleAspectFit
//        player?.delegate = self
//        guard let player = player else { return }
//        playerView.addSubview(player.playerView ?? UIView())
//        player.playerView?.frame = CGRect(x: 0, y: 0, width: 375, height: 400)
//        if btn.isSelected {
//            player.play()
//        } else {
//            player.pause()
//        }
//        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] (_) in
//            guard let self = self else { return }
//            self.bitLabel.text = "\(self.player?.bitrate ?? 0.0)kb/s"
//        }
//        let play = PlayLongViewController()
//        self.present(play, animated: true, completion: nil)
        
        navigationController?.pushViewController(VideoListViewController(), animated: true)
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        let play = PlayViewController()
//        // rtmp://rd.ccwcar.com:1935/live/ccw
//        play.url = URL(string: "rtmp://rd.ccwcar.com:1935/live/ccw")
//        self.present(play, animated: true, completion: nil)
        
        
    }

    func player(_ player: PLPlayer, statusDidChange state: PLPlayerStatus) {
//        print(state.rawValue)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }

}

