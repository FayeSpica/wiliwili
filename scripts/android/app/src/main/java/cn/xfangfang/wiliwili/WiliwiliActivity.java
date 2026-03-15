package cn.xfangfang.wiliwili;

import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.Display;
import android.view.KeyEvent;

import org.libsdl.app.BorealisHandler;
import org.libsdl.app.PlatformUtils;
import org.libsdl.app.SDLActivity;

public class WiliwiliActivity extends SDLActivity {

    private static final String TAG = "wiliwili";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        PlatformUtils.borealisHandler = new BorealisHandler();

        // Detect display HDR capability
        boolean hdrSupported = false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Display display = getWindowManager().getDefaultDisplay();
            Display.HdrCapabilities hdrCaps = display.getHdrCapabilities();
            Log.i(TAG, "Display: " + display.getName() + " (" + display.getDisplayId() + ")");
            if (hdrCaps != null) {
                int[] types = hdrCaps.getSupportedHdrTypes();
                if (types != null && types.length > 0) {
                    hdrSupported = true;
                    StringBuilder sb = new StringBuilder();
                    for (int type : types) {
                        if (sb.length() > 0) sb.append(", ");
                        switch (type) {
                            case Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION:
                                sb.append("DolbyVision"); break;
                            case Display.HdrCapabilities.HDR_TYPE_HDR10:
                                sb.append("HDR10"); break;
                            case Display.HdrCapabilities.HDR_TYPE_HLG:
                                sb.append("HLG"); break;
                            case Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS:
                                sb.append("HDR10+"); break;
                            default:
                                sb.append("Unknown(" + type + ")"); break;
                        }
                    }
                    Log.i(TAG, "HDR supported: " + sb.toString());
                    Log.i(TAG, "Max luminance: " + hdrCaps.getDesiredMaxLuminance());
                } else {
                    Log.i(TAG, "HDR not supported (no HDR types)");
                }
            } else {
                Log.i(TAG, "HDR not supported (null capabilities)");
            }
        } else {
            Log.i(TAG, "HDR detection not available (API < 24)");
        }

        Log.i(TAG, "Setting WILIWILI_HDR_DISPLAY=" + (hdrSupported ? "1" : "0"));
        SDLActivity.nativeSetenv("WILIWILI_HDR_DISPLAY", hdrSupported ? "1" : "0");
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        System.exit(0);
    }

    @Override
    protected String[] getLibraries() {
        return new String[] {
                "SDL2",
                "wiliwili"
        };
    }

    @Override
    public void onBackPressed() {
        // Don't finish the activity. BACK is handled in dispatchKeyEvent.
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (event.getKeyCode() == KeyEvent.KEYCODE_BACK) {
            if (event.getAction() == KeyEvent.ACTION_DOWN) {
                onNativeKeyDown(KeyEvent.KEYCODE_BACK);
                return true;
            } else if (event.getAction() == KeyEvent.ACTION_UP) {
                onNativeKeyUp(KeyEvent.KEYCODE_BACK);
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }
}
