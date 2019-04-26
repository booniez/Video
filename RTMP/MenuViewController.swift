//
//  MenuViewController.swift
//  RTMP
//
//  Created by JLM on 2019/4/26.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit

class MenuViewController: UIViewController {
    var tableView: UITableView!
    let dataSource: [String] = ["头条样式", "直播样式"]
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "demo"
        tableView = UITableView()
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        }
        self.automaticallyAdjustsScrollViewInsets = false
        tableView.separatorColor = .clear
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.equalTo(topLayoutGuide.snp.bottom)
            make.left.bottom.right.equalToSuperview()
        }
    }
}

extension MenuViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        cell.textLabel?.text = dataSource[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            navigationController?.pushViewController(VideoListViewController(), animated: true)
        default:
            let controller = PlayViewController()
            controller.url = URL(string: "http://tb-video.bdstatic.com/tieba-smallvideo-transcode/3830561_5acdf9a52e60062c2ccf1244d302a47f_0.mp4")
            self.present(controller, animated: true, completion: nil)
        }
    }
    
}
