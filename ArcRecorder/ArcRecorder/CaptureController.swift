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




class CaptureController: NSObject {
    
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
    let writeQueue = DispatchQueue(label: "writeQueue")
    var count = 0
    
    func configure(done: @escaping (Error?) -> Void) {
        print("configuring")
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


extension CaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if recording {
            
            
            
            
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
        
        
        
    }
    
}
