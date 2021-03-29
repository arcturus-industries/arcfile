//
//  CaptureViewController.swift
//  ArcRecorder
//
//  Created by Aaron Bryden on 3/27/21.
//

import UIKit
import SwiftUI

final class CaptureViewController: UIViewController {
    var captureController = CaptureController()
    var previewView: UIView!
    
    override func viewDidLoad() {
        print("view loaded")
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
    
    func startRecording() {
        captureController.startRecording()
    }
    
    
}

//extension CaptureViewController : UIViewControllerRepresentable{
//    public typealias UIViewControllerType = CaptureViewController
//    @Binding var isRecording: Bool
//
//    public func makeUIViewController(context: UIViewControllerRepresentableContext<CaptureViewController>) -> CaptureViewController {
//        return CaptureViewController()
//    }
//
//    public func updateUIViewController(_ uiViewController: CaptureViewController, context: UIViewControllerRepresentableContext<CaptureViewController>) {
//
//    }
//}

struct CaptureView : UIViewControllerRepresentable {
    typealias UIViewControllerType = CaptureViewController
    
    @Binding var isRecording: Bool
    
    func makeUIViewController(context: Context) -> CaptureViewController {
        return CaptureViewController()
    }
    
    func updateUIViewController(_ uiViewController: CaptureViewController, context: Context) {
        if(isRecording) {
            uiViewController.captureController.startRecording()
        }
        else {
            uiViewController.captureController.stopRecording()
        }
    }
    
    
    
     
}
