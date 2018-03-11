# RxSwiftMidi

A feature-poor and experimental reactive wrapper around Apple's CoreMIDI framework. Not for production use. 

## Features

Currently supports input only, and on/off note events only. 

## Usage

A very simple usage example (using `extension String : Error {}` to throw strings as errors):

```swift
guard let mgr = CoreMidiMidiManager() else {
    throw "Couldn't start MIDI manager"
}

guard let source = mgr.listSources().first else {
    throw "No MIDI sources"
}

// Prints notes (e.g. C#4) to the console as they arrive
_ = mgr
        .getInputStream(forSourceId: source.uniqueId)
        .notes()
        .subscribe(onNext: { event in
            print(event)
        }, onError: { err in
            print(err)
        })
```

## Requirements

Swift 4, RxSwift 4.x, macOS 10.11+; iOS requirements not investigated