package com.example.gomate

import android.content.Context
import android.media.MediaMetadataRetriever
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

@androidx.annotation.OptIn(UnstableApi::class)
object PostVideoExporter {
    private var active: Transformer? = null
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "gomate/post_video").setMethodCallHandler { call, result ->
            if (call.method != "export") { result.notImplemented(); return@setMethodCallHandler }
            if (active != null) { result.error("BUSY", "Video export is in progress", null); return@setMethodCallHandler }
            val path = call.argument<String>("path")
            val start = call.argument<Number>("startMs")?.toLong() ?: -1
            val end = call.argument<Number>("endMs")?.toLong() ?: -1
            if (path == null || start < 0 || end <= start || end - start > 30000 || !File(path).isFile) {
                result.error("INVALID_RANGE", "Invalid video or clipping range", null); return@setMethodCallHandler
            }
            val output = File(context.cacheDir, "gomate_post_${UUID.randomUUID()}.mp4")
            try {
                val item = MediaItem.Builder().setUri(android.net.Uri.fromFile(File(path)))
                    .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(start).setEndPositionMs(end).build()).build()
                active = Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                            active = null
                            val probe = MediaMetadataRetriever()
                            try {
                                probe.setDataSource(output.path)
                                val duration = probe.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0
                                if (duration <= 0 || duration > 30000 || output.length() == 0L) throw IllegalStateException()
                                result.success(mapOf("path" to output.path, "durationMs" to duration))
                            } catch (e: Exception) {
                                output.delete(); result.error("INVALID_OUTPUT", "Exported clip exceeds 30 seconds or cannot be decoded", null)
                            } finally { probe.release() }
                        }
                        override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                            active = null; output.delete(); result.error("EXPORT_FAILED", "Cannot export this video", null)
                        }
                    }).build()
                active!!.start(EditedMediaItem.Builder(item).build(), output.path)
            } catch (e: Exception) {
                active?.cancel(); active = null; output.delete(); result.error("EXPORT_FAILED", "Cannot export this video", null)
            }
        }
    }
}
