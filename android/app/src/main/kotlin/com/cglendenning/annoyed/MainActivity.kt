package com.cglendenning.annoyed

import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.annoyed.app/tts"
    private lateinit var textToSpeech: TextToSpeech
    private var ttsInitialized = false
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup method channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Initialize TTS
        textToSpeech = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val result = textToSpeech.setLanguage(Locale.US)
                ttsInitialized = result != TextToSpeech.LANG_MISSING_DATA && 
                                 result != TextToSpeech.LANG_NOT_SUPPORTED
                
                // Set up completion listener
                textToSpeech.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    
                    override fun onDone(utteranceId: String?) {
                        // Notify Flutter that speech has completed
                        runOnUiThread {
                            methodChannel.invokeMethod("onComplete", null)
                        }
                    }
                    
                    override fun onError(utteranceId: String?) {}
                })
            }
        }
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text")
                    if (text != null && ttsInitialized) {
                        val params = Bundle()
                        params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "tts_utterance_id")
                        textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, params, "tts_utterance_id")
                        result.success(null)
                    } else {
                        result.error("TTS_ERROR", "Text-to-speech not available", null)
                    }
                }
                "stop" -> {
                    if (ttsInitialized) {
                        textToSpeech.stop()
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        if (::textToSpeech.isInitialized) {
            textToSpeech.stop()
            textToSpeech.shutdown()
        }
        super.onDestroy()
    }
}
