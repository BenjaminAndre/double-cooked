class_name WebPage
extends Node
## What the Web build needs from its page (does nothing elsewhere):
## - In a hidden tab, browsers stop requestAnimationFrame, and with it Godot's main loop. A
##   Worker's timer keeps running there, so it calls back into the game (hidden_beat) to keep
##   the night and the network going, without drawing.
## - A crash that kills the main loop leaves the canvas frozen with no sign of what happened.
##   A red banner, plain HTML, shows the error on top of it.

## Emitted about 30 times a second while the tab is hidden.
signal hidden_beat

const BEAT_MS := 33

var _callback: JavaScriptObject


func _ready() -> void:
    if not OS.has_feature("web"):
        return
    _callback = JavaScriptBridge.create_callback(_on_beat)
    JavaScriptBridge.get_interface("window").doubleCookedBeat = _callback
    JavaScriptBridge.eval("""
(function () {
    var source = 'setInterval(function () { postMessage(0); }, %d);';
    var worker = new Worker(URL.createObjectURL(new Blob([source], {type: 'text/javascript'})));
    worker.onmessage = function () {
        if (document.hidden && window.doubleCookedBeat) {
            window.doubleCookedBeat();
        }
    };
    function showCrash(text) {
        if (document.getElementById('crash-banner')) {
            return;
        }
        var banner = document.createElement('div');
        banner.id = 'crash-banner';
        banner.style.cssText = 'position:fixed;top:0;left:0;right:0;padding:12px 16px;z-index:9999;'
                + 'background:#b00020;color:#fff;font:16px sans-serif;white-space:pre-wrap';
        banner.textContent = "Le jeu a planté · F12 puis Console, et copie l'erreur :\\n" + text;
        document.body.appendChild(banner);
    }
    window.addEventListener('error', function (event) {
        showCrash(event.message || String(event.error));
    });
    window.addEventListener('unhandledrejection', function (event) {
        showCrash(String(event.reason));
    });
})();
""" % BEAT_MS, true)


func _on_beat(_args: Array) -> void:
    hidden_beat.emit()
