import AVFoundation

/// Puts the shared audio session into playback mode before playing clips.
/// Without this, audio follows the default/ambient session — muted by the
/// silent switch, and routed to the quiet earpiece after the camera's
/// record session has run.
enum PlaybackAudio {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}
