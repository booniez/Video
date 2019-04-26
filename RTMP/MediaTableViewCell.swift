//
//  MediaTableViewCell.swift
//  RTMP
//
//  Created by JLM on 2019/4/26.
//  Copyright © 2019 JLM. All rights reserved.
//

import UIKit

protocol MediaTableViewCellDelegate: class {
    func tableViewWillPlay(cell: MediaTableViewCell)
    func tableViewCellEnterFullScreen(cell: MediaTableViewCell)
    func tableViewCellExitFullScreen(cell: MediaTableViewCell)
}

class MediaTableViewCell: UITableViewCell {
    weak var delegate: MediaTableViewCellDelegate?
    private var headerImageView: UIImageView!
    private var nameLabel: UILabel!
    private var detailDescLabel: UILabel!
    
    private var isNeedReset: Bool!
    private var playerView: PLPlayerView!
    private var playerBgView: UIView!
    
    var media: PLMediaInfo? {
        didSet {
            guard let model = media else { return }
            nameLabel.text = model.endUser
            detailDescLabel.text = model.detailDesc
            headerImageView.image = UIImage(named: model.headerImg ?? "")
            playerView.media = model
        }
    }
    
    deinit {
        stop()
    }
    
    public func stop() {
       playerView.stop()
    }
    
    public func play() {
        playerView.play()
    }
    
    public func configureVideo(enableRender: Bool) {
        playerView.configureVideo(enableRender: enableRender)
    }
    
    override func prepareForReuse() {
        stop()
        super.prepareForReuse()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    func setupUI() {
        isNeedReset = true
        headerImageView = UIImageView()
        headerImageView.layer.cornerRadius = 20.0
        headerImageView.contentMode = .scaleAspectFill
        headerImageView.clipsToBounds = true
        
        nameLabel = UILabel()
        nameLabel.textColor = UIColor.init(white: 0.66, alpha: 1)
        nameLabel.font = UIFont.systemFont(ofSize: 12.0)
        nameLabel.numberOfLines = 0
        
        detailDescLabel = UILabel()
        detailDescLabel.textColor = .black
        detailDescLabel.font = UIFont.systemFont(ofSize: 12.0)
        detailDescLabel.numberOfLines = 0
        
        playerBgView = UIView()
        playerView = PLPlayerView()
        playerView.delegate = self
        
        addSubview(headerImageView)
        addSubview(nameLabel)
        addSubview(detailDescLabel)
        addSubview(playerBgView)
        playerBgView.addSubview(playerView)
        
        playerBgView.snp.makeConstraints { (make) in
            make.height.equalTo(200)
            make.top.left.right.equalToSuperview()
        }
        
        headerImageView.snp.makeConstraints { (make) in
            make.top.equalTo(self.playerBgView.snp.bottom).offset(5)
            make.left.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-5)
            make.size.equalTo(CGSize(width: 40.0, height: 40.0))
        }
        
        detailDescLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.headerImageView.snp.right).offset(10)
            make.bottom.equalTo(self.headerImageView.snp.centerY)
            make.right.equalToSuperview().offset(-10)
        }
        
        nameLabel.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.detailDescLabel)
            make.top.equalTo(self.headerImageView.snp.centerY).offset(2)
        }
        
        playerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}

extension MediaTableViewCell: PLPlayerViewDelegate {
    func playerViewEnterFullScreen(playerView: PLPlayerView) {
        guard let window = UIApplication.shared.delegate?.window, let superView = window?.rootViewController?.view else { return }
        self.playerView.removeFromSuperview()
        superView.addSubview(self.playerView)
        self.playerView.snp.remakeConstraints { (make) in
            make.width.equalTo(superView.snp.height)
            make.height.equalTo(superView.snp.width)
            make.center.equalToSuperview()
        }
        superView.setNeedsUpdateConstraints()
        superView.updateConstraintsIfNeeded()
        UIView.animate(withDuration: 0.25) {
            superView.layoutIfNeeded()
        }
        delegate?.tableViewCellEnterFullScreen(cell: self)
    }
    
    func playerViewExitFullScreen(playerView: PLPlayerView) {
        self.playerView.removeFromSuperview()
        playerBgView.addSubview(self.playerView)
        self.playerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
        delegate?.tableViewCellExitFullScreen(cell: self)
    }
    
    func playerViewWillPlay(playerView: PLPlayerView) {
        delegate?.tableViewWillPlay(cell: self)
    }
    
    
}
