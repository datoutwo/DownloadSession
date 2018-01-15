//
//  DownloadSessionManager.swift
//  TestDownloadSession
//
//  Created by Delan Wang on 15/01/2018.
//  Copyright © 2018 Datoutwo Wang. All rights reserved.
//

import UIKit
import os


struct DownloadFileStatus {
    var taskStatus: DownloadTaskStatus = .Pausing
    var fileSize: Int64 = 0
}

enum DownloadTaskStatus: Int {
    case Downloading = 0
    case Pausing
    case NoSuchTask
}

protocol DownLoadSessionManagerDelegate: class {
    func downloadFinished(with uniqueDescString: String, didFinishDownloadingTo location: URL)
    func downloadFailed(with uniqueDescString: String, withError: String)
    func downloadSize(with uniqueDescString: String, size: Int64)
}

//Notification user info
let kUserInfoUniqueDescription                  = "kDownloadSessionUniqueDecription"
let kUserInfoFinishedLocation                   = "kDownloadSessionLocation"
let kUserInfoFailedErrorString                  = "kDownloadSessionErrorString"
let kUserInfoDownloadSize                       = "kDownloadSessionDownloadSize"

extension NSNotification.Name {
    static let DownloadSessionFileFinishedNotification = Notification.Name(rawValue: "kDownloadSessionFileFinishedNotification")
    static let DownloadSessionFileFailedNotification = Notification.Name(rawValue: "kDownloadSessionFileFailedNotification")
    static let DownloadSessionFileDownloadSizeNotification = Notification.Name(rawValue: "kDownloadSessionFileDownloadSizeNotification")
}



class DownloadSessionManager: NSObject {
    
    static let shared = DownloadSessionManager()
    weak var delegate: DownLoadSessionManagerDelegate?
    var maxConcurrentOperationCount: Int {
        get {
            return serialQueue.maxConcurrentOperationCount
        }
        set {
            serialQueue.maxConcurrentOperationCount = newValue
        }
    }
    
    
    private let fileAccess = DownloadFileAccess()
    private let serialQueue = OperationQueue()
    private var session: URLSession!
    
    private override init() {
        serialQueue.name = "downloadSessionMgr"
        serialQueue.maxConcurrentOperationCount = 3
        fileAccess.createResumeFileFolder()
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).backgroundDownload")
        config.isDiscretionary = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: serialQueue)
    }
    
    func getAllDownloadFileStatus(statusDictionary: @escaping (([String: DownloadFileStatus]) -> ())) {
        var downloadStatusDic = [String: DownloadFileStatus]()
        
        if let existFileNameArray = fileAccess.getAllExistFileName() {
            for existFileName in existFileNameArray {
                let fileSize = getSizeFromResumeFile(with: existFileName)
                let fileStatus = DownloadFileStatus(taskStatus: .Pausing, fileSize: fileSize)
                downloadStatusDic[existFileName] = fileStatus
            }
        }
        session!.getTasksWithCompletionHandler { [weak self] (_, _, downloadTasks) in
            for task in downloadTasks {
                var currentStatus: DownloadTaskStatus = .Downloading
                if let status = self?.getDownloadTaskStatus(byTaskState: task.state) {
                    currentStatus = status
                }
                let fileStatus = DownloadFileStatus(taskStatus: currentStatus, fileSize: task.countOfBytesReceived)
                downloadStatusDic[task.taskDescription!] = fileStatus
            }
            statusDictionary(downloadStatusDic)
        }
    }
    
    func getOneDownloadFileStatus(with uniqueDescString: String, statusClosure: @escaping ((DownloadFileStatus) -> ())) {
        getAllDownloadFileStatus { (downloadStatusDic) in
            if downloadStatusDic[uniqueDescString] != nil {
                let fileStatus = DownloadFileStatus(taskStatus: (downloadStatusDic[uniqueDescString]?.taskStatus)!, fileSize: (downloadStatusDic[uniqueDescString]?.fileSize)!)
                statusClosure(fileStatus)
            }
        }
    }
    
    func startDownload(with uniqueDescString: String, urlString: String) {
        getCurrentTask(with: uniqueDescString) { [weak self] (currentDownloadTask) in
            if currentDownloadTask == nil {
                let downloadUrl = URL(string: urlString)!
                let newDownloadTask = (self?.session!.downloadTask(with: downloadUrl))!
                newDownloadTask.taskDescription = uniqueDescString
                newDownloadTask.resume()
            }
        }
    }
    
    func pauseDownLoad(with uniqueDescString: String) {
        getCurrentTask(with: uniqueDescString) { (currentDownloadTask) in
            if currentDownloadTask != nil {
                currentDownloadTask!.cancel(byProducingResumeData: { (resumeData) in
                })
            }
        }
    }
    
    func resumeDownload(with uniqueDescString: String) {
        getCurrentTask(with: uniqueDescString) { [weak self] (currentDownloadTask) in
            if currentDownloadTask == nil {
                if let resumeFile = self?.fileAccess.readResumeFile(with: uniqueDescString) {
                    let newDownloadTask = (self?.session!.downloadTask(withResumeData: resumeFile))!
                    newDownloadTask.taskDescription = uniqueDescString
                    newDownloadTask.resume()
                    self?.fileAccess.clearResumeFile(with: uniqueDescString) //open thread?
                }
            }
        }
    }
    
    func cancelDownload(with uniqueDescString: String) {
        getCurrentTask(with: uniqueDescString) { [weak self] (currentDownloadTask) in
            self?.fileAccess.clearResumeFile(with: uniqueDescString) //open thread?
            currentDownloadTask?.cancel()
            self?.downloadSize(with: uniqueDescString, size: 0)
        }
    }
    
    private func getDownloadTaskStatus(byTaskState state: URLSessionTask.State) -> DownloadTaskStatus {
        switch state {
        case .running:
            return .Downloading
        case .canceling:
            return .NoSuchTask
        case .suspended, .completed: //completed also means task being close by user swipe
            return .Pausing
        }
    }
    
    //MARK: file access
    
    private func saveResumeFile(with uniqueDescString: String, resumeFile: Data) {
        fileAccess.writeResumeFile(with: resumeFile, fileName: uniqueDescString) //open thread?
    }
    
    private func getCurrentTask(with uniqueDescString: String, completionClosure : @escaping ((URLSessionDownloadTask?) -> ())) {
        var currentTask: URLSessionDownloadTask?
        session!.getTasksWithCompletionHandler { (_, _, downloadTasks) in
            for task in downloadTasks {
                if uniqueDescString == task.taskDescription {
                    currentTask = task
                    
                    break
                }
            }
            completionClosure(currentTask)
        }
    }
    
    private func getSizeFromResumeFile(with uniqueDescString: String) -> Int64 {
        var fileSize: Int64 = 0
        if let resumeFile = fileAccess.readResumeFile(with: uniqueDescString) { //open thread ?
            fileSize = getSizeOf(downloadFile: resumeFile)
        }
        return fileSize
    }
    
    private func getSizeOf(downloadFile: Data) -> Int64 {
        if let resumeDictionary = try? PropertyListSerialization.propertyList(from: downloadFile, options: PropertyListSerialization.MutabilityOptions.mutableContainersAndLeaves, format: nil), let plist = resumeDictionary as? [String: Any] {
            if let resumeFileSize = plist["NSURLSessionResumeBytesReceived"] as? Int64 {
                return resumeFileSize
            }
        }
        return 0
    }
    
    //MARK: Notifi & delegate
    private func downloadFinished(with uniqueDescString: String, didFinishDownloadingTo location: URL) {
        let notification = Notification(name: .DownloadSessionFileFinishedNotification, object: nil, userInfo: [kUserInfoUniqueDescription:uniqueDescString, kUserInfoFinishedLocation:location])
        NotificationCenter.default.post(notification)
        self.delegate?.downloadFinished(with: uniqueDescString, didFinishDownloadingTo: location)
    }
    
    private func downloadFailed(with uniqueDescString: String, errorMSG: String) {
        
        let notification = Notification(name: .DownloadSessionFileFailedNotification, object: nil, userInfo: [kUserInfoUniqueDescription:uniqueDescString, kUserInfoFailedErrorString:errorMSG])
        NotificationCenter.default.post(notification)
        self.delegate?.downloadFailed(with: uniqueDescString, withError: errorMSG)
    }
    
    private func downloadSize(with uniqueDescString: String, size: Int64) {
        
        let notification = Notification(name: .DownloadSessionFileDownloadSizeNotification, object: nil, userInfo: [kUserInfoUniqueDescription:uniqueDescString, kUserInfoDownloadSize:size])
        NotificationCenter.default.post(notification)
        self.delegate?.downloadSize(with: uniqueDescString, size: size)
        
    }
}

extension DownloadSessionManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!);
        completionHandler(.useCredential, credential);
        os_log("DownloadSessionManager - Session download need chanllage")
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        os_log("DownloadSessionManager - Session download urlSessionDidFinishEvents")
        
    }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        os_log("DownloadSessionManager - Session download didBecomeInvalidWithError")
    }
}

extension DownloadSessionManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("fail:\(task)")
        if error != nil {
            let err = error! as NSError
            if let resumeData = err.userInfo[NSURLSessionDownloadTaskResumeData] {
                saveResumeFile(with: task.taskDescription!, resumeFile: resumeData as! Data)
            }
            else {
                downloadFailed(with: task.taskDescription!, errorMSG: err.localizedDescription)
            }
        }
    }
}
extension DownloadSessionManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard (downloadTask.taskDescription != nil) else {
            downloadTask.cancel()
            os_log("DownloadSessionManager - received unknow dowloadtask")
            return
        }
        
        if totalBytesExpectedToWrite > 0 {
            downloadSize(with: downloadTask.taskDescription!, size: totalBytesWritten)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard (downloadTask.taskDescription != nil) else {
            downloadTask.cancel()
            os_log("DownloadSessionManager - received unknow dowloadtask")
            return
        }
        guard let httpResponse = downloadTask.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
                downloadFailed(with: downloadTask.taskDescription!, errorMSG: "server error")
                return
        }
        
        downloadFinished(with: downloadTask.taskDescription!, didFinishDownloadingTo: location)
        fileAccess.clearResumeFile(with: downloadTask.taskDescription!) //open thread?
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        os_log("DownloadSessionManager - restart fileOffset++ %d", fileOffset)
        os_log("DownloadSessionManager - restart fileOffset++ %d", expectedTotalBytes)
    }
}

