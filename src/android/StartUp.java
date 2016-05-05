package ru.orangeapps.startup;

import android.util.Log;
import android.os.AsyncTask;
import android.content.Context;
import android.content.DialogInterface;
import android.app.AlertDialog;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import java.util.ArrayList;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.io.BufferedReader;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;

public class StartUp extends CordovaPlugin {

    private static final String TAG = "StartUp";
    private static final String ACTION_LOADING_COMPLETE = "ScriptsLoadingComplete";
    private String manifestUrl;
    private CallbackContext _callbackContext;
    private int connectionTries;
    private JSONObject savedManifest;

    /**
     * Gets the application context from cordova's main activity.
     * @return the application context
     */
    private Context getApplicationContext() {
        return this.webView.getContext();
    }

    @Override
    protected void pluginInitialize()
    {
        manifestUrl = preferences.getString("OriginManifestUrl", null);
        if(manifestUrl != null) {
            Log.w(TAG, "Get manifest url: "+manifestUrl);
        }
    }

    @Override
    public Object onMessage(String id, Object data)
    {
        if("onPageFinished".equals(id)) {
            connectionTries = 3;
            loadManifest();
        }
        return null;
    }

    @Override
    public boolean execute(String action, CordovaArgs args, final CallbackContext callbackContext) throws JSONException 
    {
        this._callbackContext = callbackContext;
        if(ACTION_LOADING_COMPLETE.equals(action)) {
            runFinalScript();
            return true;
        }
        Log.e(TAG, "Unknown action: "+action);
        _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "Unimplemented method: "+action));
        _callbackContext.error("Unimplemented method: "+action);
        return false;
    }

    void loadManifest()
    {
        Log.w(TAG, "Start manifest loading: "+manifestUrl);
        final CordovaWebView webView = this.webView;
        new AsyncTask<String, String, String> () {
            InputStream inputStream = null;
            String result = ""; 
            @Override protected String doInBackground(String... params) {
                ArrayList<NameValuePair> param = new ArrayList<NameValuePair>();

                try {
                    // Set up HTTP post

                    // HttpClient is more then less deprecated. Need to change to URLConnection
                    HttpClient httpClient = new DefaultHttpClient();

                    HttpPost httpPost = new HttpPost(manifestUrl);
                    httpPost.setEntity(new UrlEncodedFormEntity(param));
                    HttpResponse httpResponse = httpClient.execute(httpPost);
                    HttpEntity httpEntity = httpResponse.getEntity();

                    // Read content & Log
                    inputStream = httpEntity.getContent();
                } catch (UnsupportedEncodingException e1) {
                    Log.e("UnsupportedEncodingException", e1.toString());
                    e1.printStackTrace();
                    noConnectionDialog();
                } catch (ClientProtocolException e2) {
                    Log.e("ClientProtocolException", e2.toString());
                    e2.printStackTrace();
                    noConnectionDialog();
                } catch (IllegalStateException e3) {
                    Log.e("IllegalStateException", e3.toString());
                    e3.printStackTrace();
                    noConnectionDialog();
                } catch (IOException e4) {
                    Log.e("IOException", e4.toString());
                    e4.printStackTrace();
                    noConnectionDialog();
                }
                // Convert response to string using String Builder
                try {
                    BufferedReader bReader = new BufferedReader(new InputStreamReader(inputStream, "utf-8"), 8);
                    StringBuilder sBuilder = new StringBuilder();

                    String line = null;
                    while ((line = bReader.readLine()) != null) {
                        sBuilder.append(line + "\n");
                    }
                    inputStream.close();
                    result = sBuilder.toString();
                } catch (Exception e) {
                    Log.e("StringBuilding & BufferedReader", "Error converting result " + e.toString());
                }
                return "";
            }

            @Override protected void onPostExecute(String v) {
                try {
                    savedManifest = new JSONObject(result);
                    Log.i(TAG, "Loaded manifest: "+savedManifest.toString());
                    JSONObject scripts = savedManifest.getJSONObject("scripts");
                    JSONArray scrAndroid = scripts.getJSONArray("android");
                    JSONArray scrAll = scripts.getJSONArray("all");
                    JSONArray resultScripts = concatArray(scrAll, scrAndroid);
                    String scrs = resultScripts.toString();
                    Log.i(TAG, "Load scripts array: "+scrs);
                    webView.loadUrl("javascript:StartUp.LoadScripts("+scrs+");");
                } catch (JSONException e) {
                    Log.e("JSONException", "Error: " + e.toString());
                }
            }
        }.execute();
    }

    void runFinalScript()
    {
        this.cordova.getActivity().runOnUiThread(new Runnable() {
                public void run() {
                    //try {
                        Log.w(TAG, "Start final javascript");
                        //String script = savedManifest.getString("run");
                        String script = "cordova.fireDocumentEvent('startupComplete')";
                        webView.loadUrl("javascript:"+script+";");
                    //} catch (JSONException e) {
                        //Log.e("JSONException", "Error: " + e.toString());
                    //}
                }
            });
    }

    void noConnectionDialog()
    {
        connectionTries -= 1;
        if(connectionTries > 0) {
            loadManifest();
            return;
        }
        this.cordova.getActivity().runOnUiThread(new Runnable() {
                public void run() {
                    AlertDialog alertDialog = new AlertDialog.Builder(getApplicationContext()).create();
                    alertDialog.setTitle("Error");
                    alertDialog.setMessage("Check your Internet connection and try again");
                    alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                                          new DialogInterface.OnClickListener() {
                                              public void onClick(DialogInterface dialog, int which) {
                                                  dialog.dismiss();
                                                  connectionTries = 3;
                                                  loadManifest();
                                              }
                                          });
                    alertDialog.show();
                }
            });
    }

    private JSONArray concatArray(JSONArray... arrs)
        throws JSONException {
        JSONArray result = new JSONArray();
        for (JSONArray arr : arrs) {
            for (int i = 0; i < arr.length(); i++) {
                result.put(arr.get(i));
            }
        }
        return result;
    }
}
