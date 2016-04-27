function StartUp() {
    // Does nothing
    this.scriptsQueue = [];
}

StartUp.prototype.InjectScript = function(url, onload, onerror) {
    var script = document.createElement("script");
    script.onload = onload;
    script.onerror = onerror;
    script.src = url;
    document.head.appendChild(script);
};

StartUp.prototype.ScriptError = function(err) {
    console.log('Script loading error', err);
    module.exports.InjectNextScript();
}

StartUp.prototype.InjectNextScript = function() {
    if(!module.exports.scriptsQueue || module.exports.scriptsQueue.length <= 0) {
        console.log('Scripts loading complete');
        cordova.exec(null, null, "StartUp", "ScriptsLoadingComplete", []);
        return;
    }
    var scr = module.exports.scriptsQueue.pop();
    module.exports.InjectScript(scr, module.exports.InjectNextScript, module.exports.ScriptError);
}

StartUp.prototype.LoadScripts = function(scripts) {
    module.exports.scriptsQueue = scripts;
    module.exports.InjectNextScript();
};

module.exports = new StartUp();
