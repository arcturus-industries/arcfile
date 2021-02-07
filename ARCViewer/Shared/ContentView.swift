//
//  ContentView.swift
//  Shared
//

import SwiftUI
import MetalKit

struct ContentView: View {
    var body: some View {
        HStack
        {
            ViewWrapper { MetalCameraView() }
                .frame(width: 200, height: 200)
            ViewWrapper { MetalCameraView() }
                .frame(width: 200, height: 200)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
