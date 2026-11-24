// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 DosukaSOL and the PushFPS contributors. Part of PushFPS, a modified version of Veyra.
//
// PushFPS output presets: platform settings per resolution and frame rate for going live
// (PushStreamDialog.qml) and for recordings meant for an upload (SettingsPage.qml). A preset only
// fills in preferences; every value stays editable afterwards, and the dialogs show "modified"
// when they no longer match. Sources (checked November 2026):
//   YouTube Live encoder settings (support.google.com/youtube/answer/2853702): CBR, keyframe 2 s,
//     AAC 128 kbps; H.264 recommended bitrates 2160p60 50, 2160p30 42, 1440p60 34, 1440p30 21,
//     1080p60 17, 1080p30 14, 720p 8 Mbps.
//   YouTube upload encoding (answer/1722171): H.264 High, VBR; SDR 2160p 35-45 / 53-68 (high frame
//     rate), 1440p 16 / 24, 1080p 8 / 12, 720p 5 / 7.5 Mbps; HDR 2160p 44-56 / 66-85, 1440p 20 / 30,
//     1080p 10 / 15 Mbps; stereo audio 384 kbps (PushFPS's AAC encoder stops at 320).
//   Twitch broadcasting guidelines: H.264 CBR, keyframe 2 s; 1080p60 6000, 1080p30 / 720p60 4500,
//     720p30 3000 kbps; audio up to 160 kbps.
//   Kick: H.264 CBR (no VBR), up to 1080p60 and 8000 kbps, keyframe 2 s.
//   Facebook Live (Meta): 1080p60 4500-9000, 1080p30 3000-6000, 720p60 2250-6000, 720p30
//     1500-4000 kbps, keyframe 2 s.
//   TikTok LIVE (LIVE Studio / Seller University): vertical, 720 x 1280 for most connections up to
//     1080 x 1920, 30 FPS (60 for fast games), 2500-6000 kbps.
//   Trovo: up to 1080p60 and 9000 kbps (OBS rtmp-services).
//   Instagram Reels: 1080 x 1920, H.264 + AAC, 30 FPS recommended; 8-15 Mbps VBR is the usual
//     choice above Meta's floor. TikTok upload: 1080 x 1920, H.264 + AAC, no official bitrate,
//     8-12 Mbps is the usual choice. X: H.264 High + AAC, at most 1920 x 1200, 60 FPS, 25 Mbps.
// Keyframes: YouTube asks uploads for a closed GOP of half the frame rate; PushFPS's shortest
// interval is 1 s, which YouTube accepts.
.pragma library

// Stream presets. fit: 0 fit (whole game picture, bars), 1 fill (cropped to cover), 2 stretch.
function stream(id, w, h, fps, kbps, audio, fit) {
    return { id: id, width: w, height: h, fps: fps, kbps: kbps, audioKbps: audio, keyframe: 2, encoderPreset: 4, fit: fit || 0 }
}
var streamPlatforms = [
    { id: "twitch", name: "Twitch", presets: [
        stream("twitch-1080p60", 1920, 1080, 60, 6000, 160),
        stream("twitch-1080p30", 1920, 1080, 30, 4500, 160),
        stream("twitch-720p60", 1280, 720, 60, 4500, 160),
        stream("twitch-720p30", 1280, 720, 30, 3000, 160) ] },
    { id: "youtube", name: "YouTube", presets: [
        stream("youtube-2160p60", 3840, 2160, 60, 50000, 128),
        stream("youtube-2160p30", 3840, 2160, 30, 42000, 128),
        stream("youtube-1440p60", 2560, 1440, 60, 34000, 128),
        stream("youtube-1440p30", 2560, 1440, 30, 21000, 128),
        stream("youtube-1080p60", 1920, 1080, 60, 17000, 128),
        stream("youtube-1080p30", 1920, 1080, 30, 14000, 128),
        stream("youtube-720p60", 1280, 720, 60, 8000, 128) ] },
    { id: "kick", name: "Kick", presets: [
        stream("kick-1080p60", 1920, 1080, 60, 8000, 160),
        stream("kick-1080p30", 1920, 1080, 30, 6000, 160),
        stream("kick-720p60", 1280, 720, 60, 6000, 160) ] },
    { id: "facebook", name: "Facebook", presets: [
        stream("facebook-1080p60", 1920, 1080, 60, 7500, 128),
        stream("facebook-1080p30", 1920, 1080, 30, 5000, 128),
        stream("facebook-720p60", 1280, 720, 60, 4500, 128),
        stream("facebook-720p30", 1280, 720, 30, 3000, 128) ] },
    { id: "tiktok", name: "TikTok LIVE", presets: [
        stream("tiktok-1080x1920-60", 1080, 1920, 60, 6000, 128, 0),
        stream("tiktok-1080x1920-30", 1080, 1920, 30, 4500, 128, 0),
        stream("tiktok-720x1280-30", 720, 1280, 30, 2500, 128, 0) ] },
    { id: "trovo", name: "Trovo", presets: [
        stream("trovo-1080p60", 1920, 1080, 60, 8000, 160),
        stream("trovo-720p60", 1280, 720, 60, 5000, 160) ] }
]

// Recording presets. rate: 0 CBR, 1 VBR, 2 constant quality (quality = level); container 0 MP4.
function record(id, w, h, fps, kbps, audio, extra) {
    return Object.assign({ id: id, width: w, height: h, fps: fps, kbps: kbps, audioKbps: audio, rate: 1, quality: 22,
                           keyframe: 1, encoderPreset: 5, hevc: false, container: 0, fit: 0 }, extra || {})
}
var recordPlatforms = [
    { id: "youtube", name: "YouTube", presets: [
        record("yt-2160p60", 3840, 2160, 60, 60000, 320),
        record("yt-2160p30", 3840, 2160, 30, 40000, 320),
        record("yt-1440p60", 2560, 1440, 60, 24000, 320),
        record("yt-1440p30", 2560, 1440, 30, 16000, 320),
        record("yt-1080p60", 1920, 1080, 60, 12000, 320),
        record("yt-1080p30", 1920, 1080, 30, 8000, 320),
        record("yt-720p60", 1280, 720, 60, 7500, 320) ] },
    { id: "youtube-hdr", name: "YouTube HDR", hdr: true, presets: [
        record("ythdr-2160p60", 3840, 2160, 60, 75000, 320, { hevc: true }),
        record("ythdr-2160p30", 3840, 2160, 30, 50000, 320, { hevc: true }),
        record("ythdr-1440p60", 2560, 1440, 60, 30000, 320, { hevc: true }),
        record("ythdr-1080p60", 1920, 1080, 60, 15000, 320, { hevc: true }) ] },
    { id: "shorts", name: "YouTube Shorts", presets: [
        record("shorts-60", 1080, 1920, 60, 12000, 320, { fit: 1 }),
        record("shorts-30", 1080, 1920, 30, 8000, 320, { fit: 1 }) ] },
    { id: "tiktok", name: "TikTok", presets: [
        record("tiktok-60", 1080, 1920, 60, 12000, 192, { fit: 1 }),
        record("tiktok-30", 1080, 1920, 30, 10000, 192, { fit: 1 }) ] },
    { id: "reels", name: "Instagram Reels", presets: [
        record("reels-30", 1080, 1920, 30, 10000, 128, { fit: 1 }),
        record("reels-60", 1080, 1920, 60, 12000, 128, { fit: 1 }) ] },
    { id: "x", name: "X", presets: [
        record("x-1080p60", 1920, 1080, 60, 15000, 128),
        record("x-1080p30", 1920, 1080, 30, 10000, 128),
        record("x-720p60", 1280, 720, 60, 8000, 128) ] },
    // For editing: the picture's own size and frame rate at a constant quality, keyframe every second.
    { id: "edit", name: "Editing", presets: [
        record("edit-source", 0, 0, 0, 0, 320, { rate: 2, quality: 16, hevc: true }),
        record("edit-source-h264", 0, 0, 0, 0, 320, { rate: 2, quality: 18 }) ] }
]

function findIn(list, id) {
    for (var i = 0; i < list.length; ++i)
        for (var j = 0; j < list[i].presets.length; ++j)
            if (list[i].presets[j].id === id) return list[i].presets[j]
    return null
}
function platformOf(list, presetId) {
    for (var i = 0; i < list.length; ++i)
        for (var j = 0; j < list[i].presets.length; ++j)
            if (list[i].presets[j].id === presetId) return list[i]
    return null
}
function streamPreset(id) { return findIn(streamPlatforms, id) }
function recordPreset(id) { return findIn(recordPlatforms, id) }

// Preferences a preset sets (keys validated in Preferences.cpp).
function streamPrefs(p) {
    return { streamWidth: p.width, streamHeight: p.height, streamFps: p.fps, streamBitrateKbps: p.kbps,
             streamAudioKbps: p.audioKbps, streamKeyframe: p.keyframe, streamEncoderPreset: p.encoderPreset, streamFit: p.fit,
             streamProfile: p.id }
}
function recordPrefs(p) {
    return { recordWidth: p.width, recordHeight: p.height, recordFps: p.fps, recordBitrateKbps: p.kbps, recordHevc: p.hevc,
             recordAdvanced: true, recordRateControl: p.rate, recordQuality: p.quality, recordPreset: p.encoderPreset,
             recordKeyframe: p.keyframe, recordAudioKbps: p.audioKbps, recordContainer: p.container, recordFit: p.fit,
             recordProfile: p.id }
}
// Defaults when a preference was never set (the same as the bridge's).
var streamDefaults = { streamWidth: 0, streamHeight: 0, streamFps: 60, streamBitrateKbps: 6000, streamAudioKbps: 160,
                       streamKeyframe: 2, streamEncoderPreset: 4, streamFit: 0 }
var recordDefaults = { recordWidth: 0, recordHeight: 0, recordFps: 0, recordBitrateKbps: 0, recordHevc: false, recordAdvanced: false,
                       recordRateControl: 1, recordQuality: 22, recordPreset: 4, recordKeyframe: 2, recordAudioKbps: 192,
                       recordContainer: 0, recordFit: 0 }
function valueOf(prefs, defaults, key) {
    var v = prefs[key]
    if (v === undefined || v === null || v === "") return defaults[key]
    return typeof defaults[key] === "boolean" ? v === true : Number(v)
}
// The keys whose current value differs from the preset (empty: the preset is in use unchanged).
// A constant-quality preset ignores the bitrate; a stream's bitrate set in Mbps by an older version
// counts as that many thousand kbps.
function differences(prefs, p, isStream) {
    var want = isStream ? streamPrefs(p) : recordPrefs(p)
    var defaults = isStream ? streamDefaults : recordDefaults
    var out = []
    for (var key in want) {
        if (key === "streamProfile" || key === "recordProfile") continue
        if (!isStream && key === "recordBitrateKbps" && p.rate === 2) continue
        if (!isStream && key === "recordQuality" && p.rate !== 2) continue
        var have = valueOf(prefs, defaults, key)
        if (isStream && key === "streamBitrateKbps" && (prefs.streamBitrateKbps === undefined || Number(prefs.streamBitrateKbps) <= 0))
            have = Math.max(1, Math.min(50, Number(prefs.streamBitrateMbps || 6))) * 1000
        if (have !== want[key]) out.push(key)
    }
    return out
}
// Label for a preset: "1080p · 60 FPS · 6 Mbps", vertical as "1080 × 1920".
function sizeLabel(w, h) {
    if (!w || !h) return ""
    return h > w ? w + " × " + h : h + "p"
}
function mbps(kbps) {
    var v = kbps / 1000
    return (Math.round(v * 10) / 10) + " Mbps"
}
function presetLabel(p, sourceLabel) {
    var size = sizeLabel(p.width, p.height) || sourceLabel
    var parts = [size]
    if (p.fps) parts.push(p.fps + " FPS")
    if (p.kbps) parts.push(mbps(p.kbps))
    return parts.join(" · ")
}
// The output sizes offered for manual choice: [w, h] (0 x 0 = the picture's own size).
var streamSizes = [[0, 0], [3840, 2160], [2560, 1440], [1920, 1080], [1600, 900], [1280, 720], [1080, 1920], [720, 1280]]
// Recordings also come in the two common ultrawide (21:9) sizes; how a 16:9 picture sits in them
// is the "picture fill" choice beside the size (fit with bars, fill and crop, stretch).
var recordSizes = [[0, 0], [3840, 2160], [2560, 1440], [1920, 1080], [1280, 720], [3440, 1440], [2560, 1080], [1080, 1920], [1080, 1350], [1080, 1080]]
