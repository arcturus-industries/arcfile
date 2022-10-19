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
    @State private var focusNeeded = false
    @State private var exposure = 20
    
    var body: some View {
        CaptureView(isRecording: $isRecording, useHEVC: $useHEVC, focusNeeded:$focusNeeded, exposureIn4000thSecond: $exposure)
            .edgesIgnoringSafeArea(.top)
        VStack {
            HStack {
                Button(action: {
                    isRecording = !isRecording
                })
                {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .padding()
                }
                .background(Color.blue)
                .foregroundColor(Color.white)
                .cornerRadius(5)
                Toggle("HEVC", isOn: $useHEVC )
                    .padding()
                    .disabled(isRecording)
                    .background(Color.blue)
                    .cornerRadius(5)
                    .frame(width: 200, height: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                Button(action: {
                    focusNeeded = true
                }) {
                    Text("Focus")
                        .padding()
                }
                .background(Color.blue)
                .foregroundColor(Color.white)
                .cornerRadius(5)
                .disabled(isRecording)
                
                
            }
            Picker("Exposure", selection: $exposure, content: {
                            Text("1.25 ms").tag(5)
                            Text("2.5 ms").tag(10)
                            Text("5 ms").tag(20)
                            Text("10 ms").tag(40)
                
                        })
                        .pickerStyle(SegmentedPickerStyle())

                                        Text("Value: \(exposure)")
            
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
