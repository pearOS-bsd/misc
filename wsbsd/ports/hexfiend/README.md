# Hex Fiend port layer

Hex Fiend's application target has four Swift files (`Encodings.swift`, `ChooseStringEncodingWindowController.swift`, `HFByteTheme.swift`, `ScrollViewRepresenter.swift`).
Swift cannot subclass `NSObject` or call AppKit without Objective-C interoperability, which only Apple's toolchains have, so these four files are ported to
Objective-C here, with the interface Xcode would generate in `Hex_Fiend-Swift.h`. Everything else, the whole `HexFiend` framework and the other application
sources, is built from the unmodified upstream tree. `overlay.json` tells `tools/xcb` which sources the overlay replaces.
