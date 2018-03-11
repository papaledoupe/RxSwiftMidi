import RxSwift

enum MidiInputEventType {
    case on, off
    // TODO support others
}

struct MidiInputEvent {
    let portName: String
    let destinationId: Int32
    let data: MidiInputData
}

struct MidiInputData {

    static let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    let type: MidiInputEventType
    let channel: UInt8
    let noteValue: UInt8
    let velocity: UInt8

    var note: String {
        // https://www.midikits.net/midi_analyser/midi_note_numbers_for_octaves.htm
        let octave = Int(noteValue / 12) - 1
        let note = MidiInputData.notes[Int(noteValue % 12)]
        return "\(note)\(octave)"
    }
}

enum MidiInputError : Error {
    case couldNotCreatePort
    case couldNotConnectPortToSource
    case unknownSource
}

typealias MidiInputStream = Observable<MidiInputEvent>
typealias NoteStream = Observable<String>

extension Observable where Observable.E == MidiInputEvent {

    func channel(_ channel: UInt8) -> MidiInputStream {
        return self.filter {
            $0.data.channel == channel
        }
    }

    func type(_ type: MidiInputEventType) -> MidiInputStream {
        return self.filter {
            $0.data.type == type
        }
    }

    func notes() -> NoteStream {
        return self.type(.on).map {
            $0.data.note
        }
    }
}