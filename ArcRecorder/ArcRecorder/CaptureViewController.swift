//
//  CaptureViewController.swift
//  ArcRecorder
//
//  Created by Aaron Bryden on 3/27/21.
//

import UIKit
import SwiftUI

final class CaptureViewController: UIViewController {
    var captureController = ARC_CaptureSession()
    var previewView: UIView!
    
    override func viewDidLoad() {
        previewView = UIView(frame: CGRect(x:0, y:0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
        previewView.contentMode = UIView.ContentMode.scaleAspectFit
        view.addSubview(previewView)
        
        captureController.configure {(error) in
            if let error = error {
                print(error)
            }
            
            try? self.captureController.displayPreview(on: self.previewView)
        }
        
    }
    
}

struct CaptureView : UIViewControllerRepresentable {
    typealias UIViewControllerType = CaptureViewController
    
    @Binding var isRecording: Bool
    @Binding var useHEVC: Bool
    @Binding var focusNeeded: Bool
    @Binding var exposureIn4000thSecond: Int
    
    func makeUIViewController(context: Context) -> CaptureViewController {
        return CaptureViewController()
    }
    
    func updateUIViewController(_ uiViewController: CaptureViewController, context: Context) {
        
        uiViewController.captureController.hevc = useHEVC
        
        if(isRecording) {
            uiViewController.captureController.startRecording()
        }
        else {
            uiViewController.captureController.stopRecording()
        }
        
        if(focusNeeded) {
            uiViewController.captureController.focusOnce()
            print("did focus once")
            DispatchQueue.main.async {
                focusNeeded = false
            }
        }
        uiViewController.captureController.updateExposure(exposure: exposureIn4000thSecond)
    }
    
    
    
     
}
