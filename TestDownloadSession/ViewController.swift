//
//  ViewController.swift
//  TestDownloadSession
//
//  Created by Delan Wang on 15/01/2018.
//  Copyright © 2018 Datoutwo Wang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tenCancelButton: UIButton!
    @IBOutlet weak var tenPauseButton: UIButton!
    @IBOutlet weak var tenResumeButton: UIButton!
    @IBOutlet weak var tenStartButton: UIButton!
    @IBOutlet weak var tenProgressView: UIProgressView!
    
    @IBOutlet weak var twentyCancelButton: UIButton!
    @IBOutlet weak var twentyPauseButton: UIButton!
    @IBOutlet weak var twentyResumeButton: UIButton!
    @IBOutlet weak var twentyStartButton: UIButton!
    @IBOutlet weak var twentyProgressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DownloadSessionManager.shared.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.buttonNoSuchTask(with: "10MB")
        self.buttonNoSuchTask(with: "20MB")
        DownloadSessionManager.shared.getAllDownloadFileStatus { (DownloadFileStatus) in
            let keys = Array(DownloadFileStatus.keys)
            for key in keys {
                let taskStatus = DownloadFileStatus[key]?.taskStatus
                if taskStatus == .NoSuchTask {
                    self.buttonNoSuchTask(with: key)
                }
                else if taskStatus == .Downloading {
                    self.buttonDownloading(with: key)
                }
                else if taskStatus == .Pausing {
                    self.buttonPausing(with: key)
                }
                let size = DownloadFileStatus[key]?.fileSize
                DispatchQueue.main.async {
                    if key == "10MB" {
                        self.tenProgressView.progress = Float(size!) / 10000000
                    }
                    else if key == "20MB" {
                        self.twentyProgressView.progress = Float(size!) / 20000000
                    }
                   
                }
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onCancelClick(_ sender: UIButton) {
        var descripString = "10MB"
        if sender == tenCancelButton{
            DownloadSessionManager.shared.cancelDownload(with: descripString)
        }
        else if sender == twentyCancelButton{
            descripString = "20MB"
            DownloadSessionManager.shared.cancelDownload(with: descripString)
        }
        buttonNoSuchTask(with: descripString)
    }
    @IBAction func onPauseClick(_ sender: UIButton) {
        var descripString = "10MB"
        if sender == tenPauseButton {
            DownloadSessionManager.shared.pauseDownLoad(with: descripString)
        }
        else if sender == twentyPauseButton {
            descripString = "20MB"
            DownloadSessionManager.shared.pauseDownLoad(with: descripString)
        }
        buttonPausing(with: descripString)
    }
    @IBAction func onResumeClick(_ sender: UIButton) {
        var descripString = "10MB"
        if sender == tenResumeButton {
            DownloadSessionManager.shared.resumeDownload(with: descripString)
        }
        else if sender == twentyResumeButton {
            descripString = "20MB"
            DownloadSessionManager.shared.resumeDownload(with: descripString)
        }
        buttonDownloading(with: descripString)
    }
    @IBAction func onStartClick(_ sender: UIButton) {
        var descripString = "10MB"
        if sender == tenStartButton{
            DownloadSessionManager.shared.startDownload(with: descripString ,urlString: "http://ipv4.download.thinkbroadband.com/10MB.zip")
        }
        else if sender == twentyStartButton {
            descripString = "20MB"
            DownloadSessionManager.shared.startDownload(with: descripString ,urlString: "http://ipv4.download.thinkbroadband.com/20MB.zip")
        }
        buttonDownloading(with: descripString)
    }
    
    private func buttonNoSuchTask(with uniqueDescString: String) {
        
        DispatchQueue.main.async {
            if uniqueDescString == "10MB" {
                self.tenStartButton.isHidden = false
                self.tenPauseButton.isHidden = true
                self.tenCancelButton.isHidden = true
                self.tenResumeButton.isHidden = true
                self.tenProgressView.isHidden = true
            }
            else if uniqueDescString == "20MB" {
                self.twentyStartButton.isHidden = false
                self.twentyPauseButton.isHidden = true
                self.twentyCancelButton.isHidden = true
                self.twentyResumeButton.isHidden = true
                self.twentyProgressView.isHidden = true
            }
        }
    }
    
    private func buttonDownloading(with uniqueDescString: String) {
        DispatchQueue.main.async {
            if uniqueDescString == "10MB" {
                self.tenStartButton.isHidden = true
                self.tenPauseButton.isHidden = false
                self.tenCancelButton.isHidden = false
                self.tenResumeButton.isHidden = true
                self.tenProgressView.isHidden = false
            }
            else if uniqueDescString == "20MB" {
                self.twentyStartButton.isHidden = true
                self.twentyPauseButton.isHidden = false
                self.twentyCancelButton.isHidden = false
                self.twentyResumeButton.isHidden = true
                self.twentyProgressView.isHidden = false
            }
            
        }
    }
    
    private func buttonPausing(with uniqueDescString: String) {
        
        DispatchQueue.main.async {
            if uniqueDescString == "10MB" {
                self.tenStartButton.isHidden = true
                self.tenPauseButton.isHidden = true
                self.tenCancelButton.isHidden = false
                self.tenResumeButton.isHidden = false
                self.tenProgressView.isHidden = false
            }
            else if uniqueDescString == "20MB" {
                self.twentyStartButton.isHidden = true
                self.twentyPauseButton.isHidden = true
                self.twentyCancelButton.isHidden = false
                self.twentyResumeButton.isHidden = false
                self.twentyProgressView.isHidden = false
            }
        }
    }
}

extension ViewController: DownLoadSessionManagerDelegate{
    func downloadFinished(with uniqueDescString: String, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async {
            self.buttonNoSuchTask(with: uniqueDescString)
        }
    }
    
    func downloadSize(with uniqueDescString: String, size: Int64) {
        
        DispatchQueue.main.async {
            if uniqueDescString == "10MB" {
                self.tenProgressView.progress = Float(size) / 10000000
            }
            else if uniqueDescString == "20MB" {
                self.twentyProgressView.progress = Float(size) / 20000000
            }
        }
    }
    
    func downloadFailed(with uniqueDescString: String, withError: String) {
        DispatchQueue.main.async {
            self.buttonNoSuchTask(with: uniqueDescString)
        }
    }
    
}

