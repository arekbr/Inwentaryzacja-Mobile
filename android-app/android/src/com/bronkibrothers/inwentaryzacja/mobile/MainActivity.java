package com.bronkibrothers.inwentaryzacja.mobile;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;

import androidx.core.content.FileProvider;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import org.qtproject.qt.android.bindings.QtActivity;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Custom Qt Activity, która:
 * 1. Na starcie pyta o permission CAMERA (Qt 6.9.1 QCameraPermission ma bug na Android 16 —
 *    auto-denies bez popupu, więc robimy to ręcznie).
 * 2. Wystawia metodę {@code launchCamera()} wołaną z C++ przez JNI — startuje natywną
 *    aplikację Camera Google przez Intent ACTION_IMAGE_CAPTURE. Dzięki temu dostajemy
 *    pełną jakość zdjęć Pixela (HDR+, Night Sight, multi-frame processing) zamiast
 *    podstawowego Qt Multimedia.
 * 3. W {@code onActivityResult()} oddaje ścieżkę pliku JPG z powrotem do C++ przez
 *    native methods — sygnał dociera do QML jako {@code cameraIntent.photoCaptured(path)}.
 */
public class MainActivity extends QtActivity {
    private static final String TAG = "InwentaryzacjaMobile";
    private static final int PERMISSION_REQUEST_CODE = 1001;
    private static final int REQUEST_CAMERA_CAPTURE = 2001;

    private static final String[] REQUIRED_PERMISSIONS = {
        Manifest.permission.CAMERA
    };

    private String currentPhotoPath;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (!allPermissionsGranted()) {
            Log.i(TAG, "Requesting permissions: " + String.join(",", REQUIRED_PERMISSIONS));
            requestPermissions(REQUIRED_PERMISSIONS, PERMISSION_REQUEST_CODE);
        } else {
            Log.i(TAG, "All permissions already granted");
        }
    }

    private boolean allPermissionsGranted() {
        for (String perm : REQUIRED_PERMISSIONS) {
            if (checkSelfPermission(perm) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == PERMISSION_REQUEST_CODE) {
            for (int i = 0; i < permissions.length; i++) {
                String status = grantResults[i] == PackageManager.PERMISSION_GRANTED
                    ? "GRANTED" : "DENIED";
                Log.i(TAG, "Permission " + permissions[i] + ": " + status);
            }
        }
    }

    // === Intent Camera ===

    /**
     * Wywoływane z C++ przez JNI. Startuje natywną aplikację Camera Google,
     * która zapisze zdjęcie do naszego katalogu app-specific.
     */
    public void launchCamera() {
        Log.i(TAG, "launchCamera() called from native");
        Intent intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
        if (intent.resolveActivity(getPackageManager()) == null) {
            Log.e(TAG, "No camera activity available");
            nativeOnPhotoError("Brak aplikacji Camera na urządzeniu");
            return;
        }
        try {
            File photoFile = createImageFile();
            currentPhotoPath = photoFile.getAbsolutePath();
            Uri photoUri = FileProvider.getUriForFile(
                this,
                getPackageName() + ".qtprovider",
                photoFile
            );
            intent.putExtra(MediaStore.EXTRA_OUTPUT, photoUri);
            intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            Log.i(TAG, "Starting camera intent, output: " + currentPhotoPath);
            startActivityForResult(intent, REQUEST_CAMERA_CAPTURE);
        } catch (Exception e) {
            Log.e(TAG, "launchCamera failed", e);
            nativeOnPhotoError("Błąd uruchomienia kamery: " + e.getMessage());
        }
    }

    private File createImageFile() throws java.io.IOException {
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
        String imageFileName = "MUZEUM_" + timeStamp + "_";
        File storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        if (storageDir == null) {
            throw new java.io.IOException("External files dir unavailable");
        }
        return File.createTempFile(imageFileName, ".jpg", storageDir);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_CAMERA_CAPTURE) {
            if (resultCode == RESULT_OK && currentPhotoPath != null) {
                Log.i(TAG, "Camera returned OK: " + currentPhotoPath);
                nativeOnPhotoCaptured(currentPhotoPath);
            } else if (resultCode == RESULT_CANCELED) {
                Log.i(TAG, "Camera cancelled by user");
                nativeOnPhotoError("Anulowano");
            } else {
                Log.w(TAG, "Camera returned unexpected resultCode=" + resultCode);
                nativeOnPhotoError("Błąd kamery (code=" + resultCode + ")");
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        restoreSystemBars();
    }

    /**
     * Przywraca paski systemowe po powrocie z pełnoekranowego Intentu aparatu.
     *
     * Objaw (Pixel 10 Pro 07.09.2026, odtworzone na emulatorze Android 16 10.09.2026):
     * po zrobieniu zdjęcia górny pas jest czarny, bez zegara i ikon.
     * Przyczyna ZMIERZONA (`adb shell dumpsys window`): okno naszej aktywności wraca ze stanem
     * `InsetsSource type=statusBars ... visible=false` — pasek jest UKRYTY, a nie „nieodrysowany".
     * To warstwa okna, nie QML: żaden padding w QML nie narysuje systemowego zegara.
     */
    private void restoreSystemBars() {
        WindowInsetsControllerCompat controller =
                WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        controller.show(WindowInsetsCompat.Type.systemBars());
    }

    // === JNI bridge ===
    public static native void nativeOnPhotoCaptured(String path);
    public static native void nativeOnPhotoError(String message);
}
