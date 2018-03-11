import Foundation
import CoreMIDI
import RxSwift

protocol MidiManager {
    func listSources() -> [MidiSource]
    func getInputStream(forSourceId sourceId: Int32, name: String?) -> MidiInputStream
}

class CoreMidiMidiManager : MidiManager {

    private var midiClientRef: MIDIClientRef = 0

    init?() {
        let name = "CoreMidiMidiManager-\(UUID().uuidString)"
        if !MIDIClientCreateWithBlock(name as CFString, &self.midiClientRef, nil).ok || midiClientRef == 0 {
            return nil
        }
    }

    deinit {
        MIDIClientDispose(midiClientRef)
    }

    func listSources() -> [MidiSource] {

        return (0 ..< MIDIGetNumberOfSources())
                .map { destIdx -> MidiSource? in
                    let midiEndpointRef = MIDIGetSource(destIdx)
                    guard let name = getMIDIObjectName(midiEndpointRef),
                          let uniqueId = getMIDIObjectId(midiEndpointRef) else {
                        return nil
                    }
                    return MidiSource(displayName: name, uniqueId: uniqueId)
                }
                .filter { $0 != nil }
                .map { $0! }
    }

    // Returns a hot observable sequence that connects to the MIDI destination upon subscription
    func getInputStream(forSourceId sourceId: Int32, name: String? = nil) -> MidiInputStream {
        let portName = name ?? "CoreMidiMidiManager_InputPort-\(UUID().uuidString)"
        return Observable.create { obs in

            var sourceRef: MIDIObjectRef = 0
            var foundObjectType: MIDIObjectType = MIDIObjectType.other
            if !MIDIObjectFindByUniqueID(sourceId, &sourceRef, &foundObjectType).ok || foundObjectType != MIDIObjectType.source {
                obs.onError(MidiInputError.unknownSource)
                return Disposables.create()
            }

            let readBlock: MIDIReadBlock = { packetList, _ in
                self.readInputPacketList(packetList, portName: portName, destinationId: sourceId).forEach {
                    obs.onNext($0)
                }
            }

            var port: MIDIPortRef = 0
            if !MIDIInputPortCreateWithBlock(self.midiClientRef, portName as CFString, &port, readBlock).ok {
                obs.onError(MidiInputError.couldNotCreatePort)
            }

            if !MIDIPortConnectSource(port, sourceRef, nil).ok {
                obs.onError(MidiInputError.couldNotConnectPortToSource)
            }

            return Disposables.create {
                MIDIPortDisconnectSource(port, sourceRef)
                MIDIPortDispose(port)
            }
        }
    }

    private func getMIDIObjectId(_ ref: MIDIObjectRef) -> Int32? {
        var id = Int32(0)
        if !MIDIObjectGetIntegerProperty(ref, kMIDIPropertyUniqueID, &id).ok {
            return nil
        }
        return id
    }

    private func getMIDIObjectName(_ ref: MIDIObjectRef) -> String? {
        var namePtr: Unmanaged<CFString>?
        if !MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, &namePtr).ok {
            return nil
        }
        return namePtr.map { $0.takeRetainedValue() as String }
    }

    private func readInputPacketList(_ packetList: UnsafePointer<MIDIPacketList>,
                                     portName: String,
                                     destinationId: Int32) -> [MidiInputEvent] {

        let packetList: MIDIPacketList = packetList.pointee

        var events: [MidiInputEvent] = []
        var packet: MIDIPacket = packetList.packet
        for _ in 1...packetList.numPackets {
            if let data = packet.toMidiInputData() {
                events.append(MidiInputEvent(portName: portName, destinationId: destinationId, data: data))
            }
            packet = MIDIPacketNext(&packet).pointee
        }
        return events
    }
}

private extension OSStatus {
    var ok: Bool {
        return self == OSStatus(noErr)
    }
}

private extension MidiInputEventType {
    static func from(statusByte: UInt8) -> MidiInputEventType? {
        let nibble = statusByte >> 4
        if nibble == UInt8(0b1001) { return on }
        if nibble == UInt8(0b1000) { return off }
        return nil
    }
}

private extension MIDIPacket {

    private static let expectedPacketLength = 3

    func toMidiInputData() -> MidiInputData? {

        guard self.length == MIDIPacket.expectedPacketLength else {
            // Unsupported input packet
            return nil
        }

        let status = self.data.0
        let note = self.data.1
        let velocity = self.data.2
        guard let type = MidiInputEventType.from(statusByte: status) else {
            // Unsupported or unknown type
            return nil
        }
        let channel = status & UInt8(0b00001111)

        return MidiInputData(type: type, channel: channel, noteValue: note, velocity: velocity)
    }
}