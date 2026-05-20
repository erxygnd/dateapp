package com.piyasa.app

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val mediaChannelName = "tanisma_app/media"
    private val recordAudioRequestCode = 4102
    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var pendingStartResult: MethodChannel.Result? = null
    private var player: MediaPlayer? = null
    private var playbackFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceRecording" -> startVoiceRecording(result)
                "stopVoiceRecording" -> stopVoiceRecording(result)
                "playVoiceData" -> playVoiceData(call.argument("dataUrl"), result)
                "stopVoicePlayback" -> stopVoicePlayback(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startVoiceRecording(result: MethodChannel.Result) {
        if (!hasRecordAudioPermission()) {
            pendingStartResult = result
            requestRecordAudioPermission()
            return
        }

        try {
            recorder?.release()
            val file = File(cacheDir, "voice_${System.currentTimeMillis()}.m4a")
            recordingFile = file
            recorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(32000)
                setAudioSamplingRate(22050)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            result.success(null)
        } catch (error: Exception) {
            recorder?.release()
            recorder = null
            recordingFile?.delete()
            recordingFile = null
            result.error("record_start_failed", error.message, null)
        }
    }

    private fun stopVoiceRecording(result: MethodChannel.Result) {
        val recorderToStop = recorder
        val file = recordingFile

        if (recorderToStop == null || file == null) {
            result.success(null)
            return
        }

        try {
            recorderToStop.stop()
            recorderToStop.release()
            recorder = null
            recordingFile = null

            val encoded = Base64.encodeToString(file.readBytes(), Base64.NO_WRAP)
            file.delete()
            result.success("data:audio/mp4;base64,$encoded")
        } catch (error: Exception) {
            recorderToStop.release()
            recorder = null
            recordingFile = null
            file.delete()
            result.error("record_stop_failed", error.message, null)
        }
    }

    private fun playVoiceData(dataUrl: String?, result: MethodChannel.Result) {
        if (dataUrl.isNullOrBlank()) {
            result.error("empty_audio", "Ses kaydı bulunamadı.", null)
            return
        }

        try {
            stopPlayback()
            val encoded = dataUrl.substringAfter(",", dataUrl)
            val audioBytes = Base64.decode(encoded, Base64.DEFAULT)
            val file = File(cacheDir, "playback_${System.currentTimeMillis()}.m4a")
            file.writeBytes(audioBytes)
            playbackFile = file
            player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener {
                    stopPlayback()
                }
                prepare()
                start()
            }
            result.success(null)
        } catch (error: Exception) {
            stopPlayback()
            result.error("playback_failed", error.message, null)
        }
    }

    private fun stopVoicePlayback(result: MethodChannel.Result) {
        stopPlayback()
        result.success(null)
    }

    private fun hasRecordAudioPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        return checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestRecordAudioPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                recordAudioRequestCode
            )
        }
    }

    private fun stopPlayback() {
        player?.release()
        player = null
        playbackFile?.delete()
        playbackFile = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != recordAudioRequestCode) {
            return
        }

        val pendingResult = pendingStartResult ?: return
        pendingStartResult = null

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startVoiceRecording(pendingResult)
        } else {
            pendingResult.error(
                "record_permission_denied",
                "Mikrofon izni verilmedi.",
                null
            )
        }
    }
}
