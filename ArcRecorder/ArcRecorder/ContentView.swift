//
//  ContentView.swift
//  ArcRecorder
//
//  Created by Aaron Bryden on 3/27/21.
//

import SwiftUI

struct ContentView: View {
    @State private var isRecording = false
    @State private var useHEVC = true
    var body: some View {
        CaptureView(isRecording: $isRecording, useHEVC: $useHEVC)
            .edgesIgnoringSafeArea(.top)
        VStack {
            Button(action: {
                isRecording = !isRecording
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(Color.white)
            }
            Toggle("HEVC", isOn: $useHEVC )
                .padding()
                .disabled(isRecording)
                .background(Color.orange)
                .frame(width: 200, height: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
