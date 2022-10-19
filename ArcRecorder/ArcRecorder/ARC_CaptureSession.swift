//
//  CaptureController.swift
//  ArcRecorder
//
//  Created by Aaron Bryden on 3/27/21.
//

import AVFoundation
import UIKit

import SwiftProtobuf
import FlatBuffers




class ARC_CaptureSession: NSObject {
    
    enum CaptureControllerError: Error {
        case configurationError
        case notRunning
    }
    
    var captureDevice: AVCaptureDevice?
    var deviceInput: AVCaptureInput?
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var outStream: OutputStream?
    var recording: Bool = false
    var hevc: Bool = true
    let writeQueue = DispatchQueue(label: "writeQueue")
    var count = 0
    
    private var maxFrameDuration:Double = 0
    private var minFrameDuration:Double = 0
    private var avgFPS:Float = 0
    
    private let videoEncodingFormatToUse = kCMVideoCodecType_HEVC
    private var videoEncoder:ARC_VideoEncoder? = nil
    
    func configure(done: @escaping (Error?) -> Void) {
        print("configuring")
        
        self.videoEncoder = ARC_VideoEncoder(codecType: videoEncodingFormatToUse)
        
        DispatchQueue(label: "initCamera").async {
            do {
                self.captureSession?.stopRunning()
                print("configuring2")
                self.captureSession = AVCaptureSession()
                
                self.captureDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                try self.captureDevice?.lockForConfiguration()
                //self.captureDevice?.setFocusModeLocked(lensPosition: 1.0)
                print("self.captureDevice?.activeFormat.maxExposureDuration " + String(self.captureDevice!.activeFormat.maxExposureDuration.seconds) + " self.captureDevice?.activeFormat.minExposureDuration " + String(self.captureDevice!.activeFormat.minExposureDuration.seconds) )
                //self.captureDevice?.activeMaxExposureDuration = CMTimeMakeWithSeconds(0.008, preferredTimescale: 1)
                self.captureDevice?.setExposureModeCustom(duration: CMTimeMake(value: 5, timescale: 1000), iso: 500.0)
                self.captureDevice?.unlockForConfiguration()
                guard let captureSession = self.captureSession else { throw CaptureControllerError.configurationError }
                guard let captureDevice = self.captureDevice else { throw CaptureControllerError.configurationError }
                self.deviceInput = try AVCaptureDeviceInput(device: captureDevice)
                captureSession.addInput(self.deviceInput!)
                captureSession.sessionPreset = .high
                for format in self.captureDevice!.formats
                {
                    
                    print("format: width:\(format.formatDescription)")
                    if(format.formatDescription.dimensions.height == 3024 && format.formatDescription.mediaSubType == .init(string: "420f"))
                    {
                        try self.captureDevice?.lockForConfiguration()
                        self.captureDevice?.activeFormat = format
                        self.captureDevice?.unlockForConfiguration()
                    }
                }
                
                
                let captureOutput = AVCaptureVideoDataOutput()
                let captureQueue = DispatchQueue(label: "captureQueue", qos: .userInteractive)
                captureOutput.setSampleBufferDelegate(self, queue: captureQueue)
                
                //maybe check if this can happen before doing it
                captureSession.addOutput(captureOutput)
                
                self.maxFrameDuration = captureDevice.activeVideoMaxFrameDuration.seconds
                self.minFrameDuration = captureDevice.activeVideoMinFrameDuration.seconds
                self.avgFPS = 1.0 / ((Float(self.maxFrameDuration) + Float(self.minFrameDuration)) / 2.0)
                
                captureSession.startRunning()
                
                
            }
            
            catch {
                DispatchQueue.main.async {
                    done(error)
                }
                
            }
            
            DispatchQueue.main.async {
                done(nil)
            }
            
        }
        
    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CaptureControllerError.notRunning }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .landscapeRight
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }
    func updateExposure(exposure: Int)
    {
        if let device = self.captureDevice
        {
            do {
                try self.captureDevice?.lockForConfiguration()
                //self.captureDevice?.setFocusModeLocked(lensPosition: 1.0)
                print("self.captureDevice?.activeFormat.maxExposureDuration " + String(self.captureDevice!.activeFormat.maxExposureDuration.seconds) + " self.captureDevice?.activeFormat.minExposureDuration " + String(self.captureDevice!.activeFormat.minExposureDuration.seconds) )
                //self.captureDevice?.activeMaxExposureDuration = CMTimeMakeWithSeconds(0.008, preferredTimescale: 1)
                self.captureDevice?.setExposureModeCustom(duration: CMTimeMake(value: Int64(exposure), timescale: 4000), iso: 500.0)
                self.captureDevice?.unlockForConfiguration()
            }
            catch {
                DispatchQueue.main.async {
                    print(error)
                    exit(1)
                }
            }
        }
        
    }
    func startRecording() {
        do {
            try self.captureDevice?.lockForConfiguration()
            self.captureDevice?.setFocusModeLocked(lensPosition: self.captureDevice!.lensPosition)
            self.captureDevice?.unlockForConfiguration()
            
            let url:URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let pbUrl = url.appendingPathComponent("testProtobuf.arc")
            let outstream = OutputStream.init(url: pbUrl, append: false)!
            outstream.open()
            self.outStream = outstream
            recording = true
        }
        catch {
            DispatchQueue.main.async {
                print(error)
                exit(1)
            }
            
        }
        
        
    }
    func stopRecording() {
        if(self.recording) {
            do {
                try self.captureDevice?.lockForConfiguration()
                self.captureDevice?.focusMode = .autoFocus
                self.captureDevice?.unlockForConfiguration()
                
                writeQueue.async { [weak self] in
                    self?.recording = false
                }
                writeQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.outStream?.close()
                    
                }
            }
            catch {
                DispatchQueue.main.async {
                    print(error)
                    exit(1)
                }
                
            }
        }
        
    }
    func focusOnce() {
        do {
            try self.captureDevice?.lockForConfiguration()
            self.captureDevice?.focusMode = .autoFocus
            self.captureDevice?.unlockForConfiguration()
        }
        catch {
            DispatchQueue.main.async {
                print(error)
                exit(1)
            }
            
        }
        
    }
}


extension ARC_CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if recording && self.hevc == false {
            
            
            
            
            // CMSampleBuffer is automatically memory managed by Swift so this should be okay
            // the pool of CMSampleBuffers will handle this as long as we don't get too far behind
            writeQueue.async { [weak self] in
                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }
                guard let self = self else { return }
                
                //this should prevent writing after recording has stopped
                if !self.recording { return }
                
                //let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let dataSize = CVPixelBufferGetDataSize(imageBuffer)
                CVPixelBufferLockBaseAddress(imageBuffer,CVPixelBufferLockFlags(rawValue: 0))
                
                let src_buff = CVPixelBufferGetBaseAddress(imageBuffer)
                if let b = src_buff {
                    let d = Data(bytesNoCopy: b, count: dataSize, deallocator: .none)
                    var image = ARC_ColorImage()
                    image.imageEncoding = ARC_ImageEncoding.rawYuv
                    
                    //TODO: incorporate timestamp
                    image.timestampInSeconds = 0
                    image.imageData = d
                    var wrappedMsg = ARC_WrappedMessage()
                    wrappedMsg.colorImage = image
                    
                    try! BinaryDelimited.serialize(message: wrappedMsg, to: self.outStream!)
                }
                CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            }
            
        }
        else if recording {
            writeQueue.async { [weak self] in
                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }
                
                guard let self = self else { return }
                
                let presentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                
                let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
                
                let colorEncodingDoneSemapahore = DispatchSemaphore(value:0)
                
                
                self.count = self.count + 1
                if(self.count % 5 == 0) {
                    let _ = self.videoEncoder!.encode(
                        imageBuffer: imageBuffer,
                        presentationTimeStamp: presentationTimestamp,
                        duration: duration,
                        fpsHint: self.avgFPS)
                    {   (parameterSets:Array<(parameterSetCount: Int, parameterData: UnsafePointer<UInt8>?, parameterDataSizeInBytes: Int)>, imageDataPtr:UnsafeMutablePointer<Int8>, totalLength:Int, encodedSampleBuffer: CMSampleBuffer?, videoFormatDescription:CMVideoFormatDescription) in
                        
                        
                        let numParameterSets:Int = parameterSets.count
                        
                        var image = ARC_ColorImage()
                        image.imageEncoding = ARC_ImageEncoding.hevc
                        image.timestampInSeconds = 0
                        
                        image.imageHeader = Array<Data>(repeating: SwiftProtobuf.Internal.emptyData, count: numParameterSets)
                        
                        for index in 0..<numParameterSets
                        {
                            let parameterSet = parameterSets[index]
                            
                            guard let parameterData = parameterSet.parameterData else {
                                assertionFailure("problem with parameter sets")
                                continue
                            }
                            
                            //NOTE: parameterData is an UnsafePointer<UInt8>
                            image.imageHeader[index] = Data(
                                bytesNoCopy: UnsafeMutableRawPointer(mutating: parameterData),
                                count: parameterSet.parameterDataSizeInBytes,
                                deallocator: Data.Deallocator.none)
                            
                            //lt_log("Header index: %d, SHA256: %@", log: self.encodingLog, index, Get_SHA256_Hash_String(messageData:imageFrame.imageHeader[index]))
                        }
                        
                        
                        let d = Data(bytesNoCopy: imageDataPtr, count: totalLength, deallocator: .none)
                        
                        image.imageData = d
                        var wrappedMsg = ARC_WrappedMessage()
                        wrappedMsg.colorImage = image
                        print("serializing \(self.count)")
                        
                        try! BinaryDelimited.serialize(message: wrappedMsg, to: self.outStream!)
                        
                        
                        
                        colorEncodingDoneSemapahore.signal()
                        
                    }
                    
                    colorEncodingDoneSemapahore.wait()
                }
            }
        }
        
        
        
    }
    
}
