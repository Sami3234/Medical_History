package com.medicalhistory.app

import android.content.Intent
import android.net.Uri
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

private const val CHANNEL = "medical_history/native_documents"

class MainActivity : FlutterFragmentActivity() {
    private var scanResult: MethodChannel.Result? = null
    private val pendingSharedFiles = mutableListOf<Map<String, String>>()

    private val scannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult(),
    ) { result ->
        val callback = scanResult ?: return@registerForActivityResult
        scanResult = null
        if (result.resultCode != RESULT_OK || result.data == null) {
            callback.success(emptyList<Map<String, String>>())
            return@registerForActivityResult
        }
        val scan = GmsDocumentScanningResult.fromActivityResultIntent(result.data)
        val files = mutableListOf<Map<String, String>>()
        scan?.pages?.forEachIndexed { index, page ->
            copyUri(page.imageUri, "scan_${System.currentTimeMillis()}_$index.jpg")?.let {
                files.add(mapOf("path" to it, "mime" to "image/jpeg", "name" to "scanned_page_${index + 1}.jpg"))
            }
        }
        scan?.pdf?.let { pdf ->
            copyUri(pdf.uri, "scan_${System.currentTimeMillis()}.pdf")?.let {
                files.add(mapOf("path" to it, "mime" to "application/pdf", "name" to "scanned_document.pdf"))
            }
        }
        callback.success(files)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        consumeShareIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanDocuments" -> startDocumentScanner(result)
                "recognizeText" -> recognizeText(call, result)
                "consumeSharedFiles" -> {
                    val files = pendingSharedFiles.toList()
                    pendingSharedFiles.clear()
                    result.success(files)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeShareIntent(intent)
    }

    private fun startDocumentScanner(result: MethodChannel.Result) {
        if (scanResult != null) {
            result.error("BUSY", "A document scan is already running.", null)
            return
        }
        scanResult = result
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(10)
            .setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF,
            )
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(this)
            .addOnSuccessListener { sender ->
                scannerLauncher.launch(IntentSenderRequest.Builder(sender).build())
            }
            .addOnFailureListener { error ->
                scanResult = null
                result.error("SCANNER_ERROR", error.message, null)
            }
    }

    private fun recognizeText(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("INVALID_PATH", "Image path is required.", null)
            return
        }
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image)
                .addOnSuccessListener { text ->
                    result.success(text.text)
                    recognizer.close()
                }
                .addOnFailureListener { error ->
                    recognizer.close()
                    result.error("OCR_ERROR", error.message, null)
                }
        } catch (error: Exception) {
            result.error("OCR_ERROR", error.message, null)
        }
    }

    private fun consumeShareIntent(incoming: Intent?) {
        if (incoming == null || incoming.action != Intent.ACTION_SEND && incoming.action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = if (incoming.action == Intent.ACTION_SEND_MULTIPLE) {
            (incoming.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: arrayListOf())
        } else {
            listOfNotNull(incoming.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        }
        uris.forEachIndexed { index, uri ->
            val mime = contentResolver.getType(uri) ?: "application/octet-stream"
            val extension = if (mime.contains("pdf")) "pdf" else if (mime.contains("png")) "png" else "jpg"
            copyUri(uri, "shared_${System.currentTimeMillis()}_$index.$extension")?.let { path ->
                pendingSharedFiles.add(mapOf("path" to path, "mime" to mime, "name" to File(path).name))
            }
        }
    }

    private fun copyUri(uri: Uri, name: String): String? {
        return try {
            val file = File(cacheDir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(file).use { output -> input.copyTo(output) }
            } ?: return null
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
