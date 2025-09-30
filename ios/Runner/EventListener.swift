class EventListener: FilesStreamHandler {
    var eventSink: PigeonEventSink<[PlatformFile]>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<[PlatformFile]>) {
        eventSink = sink
    }

    func onEvent(files: [PlatformFile]) {
        eventSink?.success(files)
    }

    override func onCancel(withArguments arguments: Any?) {
        eventSink?.endOfStream()
        eventSink = nil
    }
}
