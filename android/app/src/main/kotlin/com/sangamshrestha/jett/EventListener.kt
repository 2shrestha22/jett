package com.sangamshrestha.jett

import FilesStreamHandler
import PigeonEventSink
import PlatformFile

class EventListener : FilesStreamHandler() {
    private var eventSink: PigeonEventSink<List<PlatformFile>>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<List<PlatformFile>>) {
        eventSink = sink
    }

    fun onEvent(files: List<PlatformFile>) = eventSink?.success(files)

    override fun onCancel(p0: Any?) {
        eventSink?.endOfStream()
        eventSink = null
    }
}