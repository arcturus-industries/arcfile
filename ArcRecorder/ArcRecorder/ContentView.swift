//
//  ContentView.swift
//  ArcRecorder
//
//  Created by Aaron Bryden on 3/27/21.
//

import SwiftUI

struct ContentView: View {
    @State private var isRecording = false
    var body: some View {
        CaptureView(isRecording: $isRecording)
            .edgesIgnoringSafeArea(.top)
        Button(action: {
            isRecording = !isRecording
        }) {
            Text(isRecording ? "Stop Recording" : "Start Recording")
                .padding()
                .background(Color.red)
                .foregroundColor(Color.white)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
