//
//  VideoLIstViewController.swift
//  RTMP
//
//  Created by JLM on 2019/4/26.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit

class VideoListViewController: UIViewController {
    private var tableView: UITableView!
    private var playingCell: MediaTableViewCell!
    private var mediaArray: [PLMediaInfo]?
    private var isFullScreen: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "基于7牛二次封装"
        loadData()
        configureUI()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stop()
    }
    
    private func loadData() {
        guard let classPath = Bundle.main.path(forResource: "Video", ofType: "json"), let classData = try? Data.init(contentsOf: URL.init(fileURLWithPath: classPath)), let json = try? JSONSerialization.jsonObject(with: classData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any], let data = json["data"] as? [String: Any] else { return }
        if let row = data["rows"] as? [[String: Any]] {
            guard let dataString = try? JSONSerialization.data(withJSONObject: row, options: []) else { return }
            guard let model = try? JSONDecoder().decode([PLMediaInfo].self, from: dataString) else { return }
            mediaArray = model
            perform(#selector(playTopCell), with: nil, afterDelay: 0.5)
        }
    }
    
    private func configureUI() {
        tableView = UITableView(frame: CGRect.zero, style: .grouped)
        tableView.separatorColor = .clear
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 44.0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(MediaTableViewCell.self, forCellReuseIdentifier: "MediaTableViewCell")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.left.bottom.right.equalToSuperview()
        }
        
    }
    
    private func stop() {
        let visibleCells = tableView.visibleCells
        for item in visibleCells {
            guard let cell = item as? MediaTableViewCell else { return }
            cell.stop()
        }
    }
    
    @objc private func playTopCell() {
        if (playingCell != nil) {
            return
        }
        let visibleCells = tableView.visibleCells
        var cell: MediaTableViewCell?
        var minOriginY = view.bounds.size.height
        let navigationBarHeight = 20.0 + (navigationController?.navigationBar.bounds.size.height ?? 0.0)
        for item in visibleCells {
            guard let mediaTableViewCell = item as? MediaTableViewCell else { return }
            var rc = tableView.convert(mediaTableViewCell.frame, to: self.view)
            rc.size.height -= 60
            if (rc.origin.y > navigationBarHeight && rc.origin.y + rc.size.height < self.view.bounds.size.height) {
                if (rc.origin.y < minOriginY) {
                    minOriginY = rc.origin.y
                    cell = mediaTableViewCell
                }
                break
            }
        }
        playingCell = cell
        playingCell.play()
//        playingCell.playerView.configureVideo(true)
    }
    
    public func onUIApplication(active: Bool) {
        if playingCell != nil {
            playingCell.configureVideo(enableRender: active)
        }
    }
}

extension VideoListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mediaArray?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MediaTableViewCell", for: indexPath) as! MediaTableViewCell
        cell.selectionStyle = .none        
        cell.delegate = self
        cell.media = mediaArray?[indexPath.row]
//        cell.playerView.player = nil
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        if playingCell != nil {
            playTopCell()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if playingCell == nil {
            playTopCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MediaTableViewCell {
            if cell == self.playingCell {
                self.playingCell.stop()
                self.playingCell = nil
            }
        }
    }
}

extension VideoListViewController: MediaTableViewCellDelegate {
    func tableViewWillPlay(cell: MediaTableViewCell) {
        if cell == playingCell {
            return
        }
        for item in tableView.visibleCells {
            guard let visibleCell = item as? MediaTableViewCell else { return }
            if cell != visibleCell {
                visibleCell.stop()
            }
        }
        playingCell = cell
        playingCell.play()
    }
    
    func tableViewCellEnterFullScreen(cell: MediaTableViewCell) {
        isFullScreen = true
        setNeedsStatusBarAppearanceUpdate()
    }
    
    func tableViewCellExitFullScreen(cell: MediaTableViewCell) {
        isFullScreen = false
        setNeedsStatusBarAppearanceUpdate()
    }
}
