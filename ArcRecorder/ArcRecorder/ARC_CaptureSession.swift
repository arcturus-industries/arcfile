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
                print("configuring2")
                self.captureSession = AVCaptureSession()
                
                self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                try self.captureDevice?.lockForConfiguration()
                self.captureDevice?.unlockForConfiguration()
                guard let captureSession = self.captureSession else { throw CaptureControllerError.configurationError }
                guard let captureDevice = self.captureDevice else { throw CaptureControllerError.configurationError }
                self.deviceInput = try AVCaptureDeviceInput(device: captureDevice)
                captureSession.addInput(self.deviceInput!)
                
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
    
    func startRecording() {
        
        
        let url:URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pbUrl = url.appendingPathComponent("testProtobuf.arc")
        let outstream = OutputStream.init(url: pbUrl, append: false)!
        outstream.open()
        self.outStream = outstream
        recording = true
        
    }
    func stopRecording() {
        
        
        writeQueue.async { [weak self] in
            self?.recording = false
            self?.outStream?.close()
            
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
                
                let _ = self.videoEncoder!.encode(
                    imageBuffer: imageBuffer,
                    presentationTimeStamp: presentationTimestamp,
                    duration: duration,
                    fpsHint: self.avgFPS)
                {   (parameterSets:Array<(parameterSetCount: Int, parameterData: UnsafePointer<UInt8>?, parameterDataSizeInBytes: Int)>, imageDataPtr:UnsafeMutablePointer<Int8>, totalLength:Int, encodedSampleBuffer: CMSampleBuffer?, videoFormatDescription:CMVideoFormatDescription) in
                    
                    
                    let d = Data(bytesNoCopy: imageDataPtr, count: totalLength, deallocator: .none)
                    var image = ARC_ColorImage()
                    image.imageEncoding = ARC_ImageEncoding.hevc
                    image.timestampInSeconds = 0
                    image.imageData = d
                    var wrappedMsg = ARC_WrappedMessage()
                    wrappedMsg.colorImage = image
                    try! BinaryDelimited.serialize(message: wrappedMsg, to: self.outStream!)
                    
                    
                    
                    colorEncodingDoneSemapahore.signal()
                    
                }
                
                colorEncodingDoneSemapahore.wait()
            }
        }
        
        
        
    }
    
}
