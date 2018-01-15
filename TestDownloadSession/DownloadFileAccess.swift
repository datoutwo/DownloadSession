//
//  DownloadFileAccess.swift
//  TestDownloadSession
//
//  Created by Delan Wang on 15/01/2018.
//  Copyright © 2018 Datoutwo Wang. All rights reserved.
//

import Foundation
import os
struct DownloadFileAccess {
    
    let resumeFileFolderPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] + "/DownloadResumeFile/"
    
    func createResumeFileFolder() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: resumeFileFolderPath) {
            do {
                try fileManager.createDirectory(atPath: resumeFileFolderPath, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                os_log("DownloadFileAccess createFolder Error %@", error.localizedDescription)
            }
        }
    }
    
    func readResumeFile(with fileName: String) -> Data? {
        let filePath = resumeFileFolderPath + fileName
        do {
            return try Data(contentsOf: URL(fileURLWithPath: filePath))
        } catch let error{
            os_log("DownloadFileAccess readResumeData: %@, Error: %@", fileName, error.localizedDescription)
        }
        return nil
    }
    
    func writeResumeFile(with resumeFile: Data, fileName: String) {
        let filePath = resumeFileFolderPath + fileName
        do {
            try resumeFile.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch let error {
            os_log("DownloadFileAccess writeResumeData: %@, Error: %@", fileName, error.localizedDescription)
        }
        
    }
    
    func clearResumeFile(with fileName: String) {
        let filePath = resumeFileFolderPath + fileName
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: filePath))
            } catch let error {
                os_log("DownloadFileAccess clearResumeData: %@, Error: %@", fileName, error.localizedDescription)
            }
        }
    }
    
    func getAllExistFileName() -> [String]? {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: resumeFileFolderPath)
            var fileNameArray = [String]()
            for item in items {
                let fileName = (item as NSString).lastPathComponent
                fileNameArray.append(fileName)
            }
            return fileNameArray
        } catch {
            return nil
        }
    }
}

