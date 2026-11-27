package com.rappace.novatube.web;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.WindowManager;

import org.mozilla.geckoview.GeckoResult;
import org.mozilla.geckoview.GeckoRuntime;
import org.mozilla.geckoview.GeckoRuntimeSettings;
import org.mozilla.geckoview.GeckoSession;
import org.mozilla.geckoview.GeckoSessionSettings;
import org.mozilla.geckoview.GeckoView;

/**
 * NovaTube Web : la version TV du site YouTube (youtube.com/tv), pilotable a la telecommande,
 * dans le moteur de Firefox (GeckoView) avec uBlock Origin integre.
 */
public class MainActivity extends Activity {
    private static final String URL = "https://www.youtube.com/tv";
    /* youtube.com/tv n'accepte que les navigateurs de televiseur */
    private static final String UA = "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 "
            + "(KHTML, like Gecko) 76.0.3809.146/6.0 TV Safari/537.36";
    private static final String UBLOCK_ID = "uBlock0@raymondhill.net";

    private static GeckoRuntime sRuntime;
    private static final String ANTIPUB_ID = "antipub@novatube.rappace";
    private static GeckoResult<?> sUblock;
    private GeckoSession session;
    private GeckoView view;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        view = new GeckoView(this);
        setContentView(view);

        if (sRuntime == null) {
            GeckoRuntimeSettings settings = new GeckoRuntimeSettings.Builder()
                    .displayDensityOverride(1.0f)   // 1 pixel = 1 point : l'image en vraie 1080p
                    .consoleOutput(false)
                    .aboutConfigEnabled(false)
                    .build();
            sRuntime = GeckoRuntime.create(getApplicationContext(), settings);
            // filtre NovaTube (pubs retirees des reponses de YouTube) puis uBlock Origin
            final org.mozilla.geckoview.WebExtensionController wec = sRuntime.getWebExtensionController();
            sUblock = wec.ensureBuiltIn("resource://android/assets/antipub/", ANTIPUB_ID)
                    .then(a -> wec.ensureBuiltIn("resource://android/assets/ublock/", UBLOCK_ID),
                          err -> wec.ensureBuiltIn("resource://android/assets/ublock/", UBLOCK_ID));
        }

        session = new GeckoSession(new GeckoSessionSettings.Builder()
                .userAgentOverride(UA)
                .viewportMode(GeckoSessionSettings.VIEWPORT_MODE_DESKTOP)
                .build());
        session.setPermissionDelegate(new GeckoSession.PermissionDelegate() {
            @Override
            public GeckoResult<Integer> onContentPermissionRequest(GeckoSession s, ContentPermission perm) {
                if (perm.permission == PERMISSION_AUTOPLAY_AUDIBLE || perm.permission == PERMISSION_AUTOPLAY_INAUDIBLE
                        || perm.permission == PERMISSION_MEDIA_KEY_SYSTEM_ACCESS) {
                    return GeckoResult.fromValue(ContentPermission.VALUE_ALLOW);
                }
                return GeckoResult.fromValue(ContentPermission.VALUE_DENY);
            }
        });
        session.setContentDelegate(new GeckoSession.ContentDelegate() {
            @Override
            public void onCloseRequest(GeckoSession s) { finish(); }   // « Quitter YouTube ? » → Oui
        });
        session.open(sRuntime);
        view.setSession(session);
        view.requestFocus();

        // on attend uBlock Origin avant d'ouvrir YouTube, pour que la premiere video soit deja filtree
        final Runnable load = () -> { if (session != null) session.loadUri(URL); };
        sUblock.accept(ext -> runOnUiThread(load), err -> runOnUiThread(load));
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        if (e.getKeyCode() == KeyEvent.KEYCODE_BACK) {
            // appui long sur Retour : on quitte
            if (e.getAction() == KeyEvent.ACTION_DOWN && e.getRepeatCount() == 12) { finish(); return true; }
            if (e.getRepeatCount() > 0) return true;
            // appui court : Retour de YouTube TV (touche Echap)
            KeyEvent esc = new KeyEvent(e.getDownTime(), e.getEventTime(), e.getAction(), KeyEvent.KEYCODE_ESCAPE, 0);
            return view.dispatchKeyEvent(esc);
        }
        return super.dispatchKeyEvent(e);
    }

    @Override
    protected void onStop() {
        super.onStop();
        // comme NovaTV : quand on quitte, l'appli se ferme vraiment (pas de mise en veille)
        if (!isChangingConfigurations()) finish();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (session != null) { session.close(); session = null; }
        if (isFinishing()) {
            new Handler(Looper.getMainLooper()).postDelayed(
                    () -> android.os.Process.killProcess(android.os.Process.myPid()), 400);
        }
    }
}
