//
//  ViewWrapper.swift
//  ARCViewer

import SwiftUI

public struct ViewWrapper: NSViewRepresentable {
    
    public var wrappedView: NSView
    
    private var handleUpdateNSView: ((NSView, Context) -> Void)?
    private var handleMakeNSView: ((Context) -> NSView)?
    
    public init(closure: () -> NSView) {
        wrappedView = closure()
    }
    
    public func makeNSView(context: Context) -> NSView {
        guard let handler = handleMakeNSView else {
            return wrappedView
        }
        
        return handler(context)
    }
    
    public func updateNSView(_ uiView: NSView, context: Context) {
        handleUpdateNSView?(uiView, context)
    }
}

public extension ViewWrapper {
    mutating func setMakeUIView(handler: @escaping (Context) -> NSView) -> Self {
        handleMakeNSView = handler
        return self
    }
    
    mutating func setUpdateUIView(handler: @escaping (NSView, Context) -> Void) -> Self {
        handleUpdateNSView = handler
        return self
    }
}
