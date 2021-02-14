# ARC File Format

![Logo](doc/resources/arc-logo-900x400.png)

### ARC file is a side project at [Arcturus Industries](https://arcturus.industries/) where we aim to create an open file format for 3D vision research and production.

At Arcturus Industries, we work on things like visual-inertial SLAM (Simultaneous Localization and Mapping), depth estimation, and scene reconstruction. 

We want ARC file to work well for those tasks, but also a wider range of tasks like data capture for deep learning research topics like neural rendering, and view synthesis. And likely will be suitable to other tasks like volumetric video, and more.

[Join us in the Discussions section](https://github.com/arcturus-industries/arcfile/discussions/1)


```
protoc --swift_out=. format/ARC.proto 
flatc --swift format/ARC.fbs
```

### Links:

[GitHub: FlatBuffers `swift/` directory fork for Swift Package Manager (SPM) compatibility](https://github.com/arcturus-industries/flatbuffers-swift)

### Thanks:

Thanks to [Vikas Reddy](https://twitter.com/vikasreddy) for sharing reference code he developed for realtime 3D capture.

### News:

**2021.2.6:** Repository created & development started.

**2021.2.13:** Trivial Protobuf and FlatBuffers integration has been added to a testbench ARCViewer project (Mac/iOS for now).



