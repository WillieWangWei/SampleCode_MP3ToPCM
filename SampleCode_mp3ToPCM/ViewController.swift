//
//  ViewController.swift
//  SampleCode_mp3ToPCM
//
//  Created by 王炜 on 2017/2/2.
//  Copyright © 2017年 Jenova. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        // MARK: 通用逻辑
        
        // 1.创建AVAsset实例
        guard let asset = self.readMp3File() else { return }
        
        // 2.创建AVAssetReader实例
        guard let assetReader = self.initAssetReader(asset: asset) else { return }
        
        // 3.配置转码参数
        
        var channelLayout = AudioChannelLayout()
        memset(&channelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        
        let outputSettings = [
            AVFormatIDKey : kAudioFormatLinearPCM,    // 音频格式
            AVSampleRateKey : 44100.0,    // 采样率
            AVNumberOfChannelsKey : 2,    // 通道数 1 || 2
            AVChannelLayoutKey : Data.init(bytes: &channelLayout, count: MemoryLayout<AudioChannelLayout>.size),  // 声音效果（立体声）
            AVLinearPCMBitDepthKey : 16,  // 音频的每个样点的位数
            AVLinearPCMIsNonInterleaved : false,  // 音频采样是否非交错
            AVLinearPCMIsFloatKey : false,    // 采样信号是否浮点数
            AVLinearPCMIsBigEndianKey : false // 音频采用高位优先的记录格式
            ] as [String : Any]
        
        // 4.创建AVAssetReaderAudioMixOutput实例并绑定到assetReader上
        
        let readerAudioMixOutput = AVAssetReaderAudioMixOutput(audioTracks: asset.tracks, audioSettings: outputSettings)
        
        if !assetReader.canAdd(readerAudioMixOutput) {
            
            print("can't add readerAudioMixOutput")
            return
        }
        
        assetReader.add(readerAudioMixOutput)
        
        // MARK: 1.保存到文件
        
        // 5.创建AVAssetWriter实例
        guard let assetWriter = self.initAssetWriter() else { return }
        
        // 6.创建AVAssetWriterInput实例并绑定到assetWriter上
        
        if !assetWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaTypeAudio) {
            
            print("can't apply outputSettings")
            return
        }
        
        let writerInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: outputSettings)
        
        // 是否让媒体数据保持实时。在此不需要开启
        writerInput.expectsMediaDataInRealTime = false
        
        if !assetWriter.canAdd(writerInput) {
            
            print("can't add writerInput")
            return
        }
        
        assetWriter.add(writerInput)
        
        // 7.启动转码
        assetReader.startReading()
        assetWriter.startWriting()
        
        // 开启session
        guard let track = asset.tracks.first else { return }
        let startTime = CMTime(seconds: 0, preferredTimescale: track.naturalTimeScale)
        assetWriter.startSession(atSourceTime: startTime)
        
        let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
        writerInput.requestMediaDataWhenReady(on: mediaInputQueue, using: {
            
            while writerInput.isReadyForMoreMediaData {
                
                if let nextBuffer = readerAudioMixOutput.copyNextSampleBuffer() {
                    writerInput.append(nextBuffer)
                    
                } else {
                    
                    writerInput.markAsFinished()
                    assetReader.cancelReading()
                    assetWriter.finishWriting(completionHandler: {
                        print("whrite complete")
                    })
                    break
                }
            }
        })
        
        // MARK: 2.转成NSDate保存在内存中
        
//        // 5.启动转码
//        assetReader.startReading()
//        var PCMData = Data()
//        
//        while let nextBuffer = readerAudioMixOutput.copyNextSampleBuffer() {
//            
//            var audioBufferList = AudioBufferList()
//            var blockBuffer: CMBlockBuffer?
//            
//            // CMSampleBuffer to Data
//            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer,
//                                                                    nil,
//                                                                    &audioBufferList,
//                                                                    MemoryLayout<AudioBufferList>.size,
//                                                                    nil,
//                                                                    nil,
//                                                                    0,
//                                                                    &blockBuffer)
//            
//            let audioBuffer = audioBufferList.mBuffers
//            guard let frame = audioBuffer.mData else { continue }
//            
//            PCMData.append(frame.assumingMemoryBound(to: UInt8.self), count: Int(audioBuffer.mDataByteSize))
//            blockBuffer = nil;
//        }
//        
//        print("whrite complete")
    }
}

extension ViewController {
    
    // 用mp3文件创建一个AVAsset实例
    func readMp3File()  -> AVAsset? {
        
        guard let filePath = Bundle.main.path(forResource: "trust you", ofType: "mp3") else { return nil }
        let fileURL = URL(fileURLWithPath: filePath)
        let asset = AVAsset(url: fileURL)
        
        return asset
    }
    
    // 用一个AVAsset实例创建一个AVAssetReader实例
    func initAssetReader(asset: AVAsset) -> AVAssetReader? {
        
        let assetReader: AVAssetReader
        
        do {
            assetReader = try AVAssetReader(asset: asset)
            
        } catch {
            
            print(error)
            return nil
        }
        
        return assetReader
    }
    
    // 创建一个AVAssetWriter实例
    func initAssetWriter() -> AVAssetWriter? {
        
        let assetWriter: AVAssetWriter
        guard let outPutPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return nil }
        
        // 这里的扩展名'.wav'只是标记了文件的打开方式，实际的编码封装格式由assetWriter的fileType决定
        let fullPath = outPutPath + "/outPut.wav"
        print("path: \(fullPath)")
        let outPutURL = URL(fileURLWithPath: fullPath)
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outPutURL, fileType: AVFileTypeWAVE)
        } catch {
            
            print(error)
            return nil
        }
        
        return assetWriter
    }
}
