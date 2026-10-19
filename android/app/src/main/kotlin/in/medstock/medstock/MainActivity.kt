package `in`.medstock.medstock

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // On-device label reading with ML Kit (iOS uses Apple Vision; see AppDelegate.swift).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medstock/ocr").setMethodCallHandler { call, result ->
            if (call.method != "recognize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("args", "path is required", null)
                return@setMethodCallHandler
            }
            val image = try {
                // Reads EXIF rotation, so photos taken sideways still read correctly.
                InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            } catch (e: Exception) {
                result.error("image", e.message, null)
                return@setMethodCallHandler
            }
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image)
                .addOnSuccessListener { text ->
                    result.success(text.textBlocks.flatMap { block ->
                        block.lines.map { line ->
                            mapOf("text" to line.text, "height" to (line.boundingBox?.height() ?: 0).toDouble())
                        }
                    })
                }
                .addOnFailureListener { e -> result.error("ocr", e.message, null) }
                .addOnCompleteListener { recognizer.close() }
        }
    }
}
