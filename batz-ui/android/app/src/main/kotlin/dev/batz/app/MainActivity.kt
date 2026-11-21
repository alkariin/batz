package dev.batz.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// A FragmentActivity: the unlock dialog of local_auth needs one
// (docs/decisions.md, « What `local_auth` asks of the Android app »).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The list of recent apps shows no picture of the last screen.
        // Android 13 and later; screenshots stay possible.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }
}
