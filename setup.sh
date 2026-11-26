#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/br/com/lista
mkdir -p app/src/main/assets
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/values

cat > settings.gradle.kts <<'EOF_G'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "ListaDeCompras"
include(":app")
EOF_G

cat > build.gradle.kts <<'EOF_G'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}
EOF_G

cat > gradle.properties <<'EOF_G'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
EOF_G

cat > app/build.gradle.kts <<'EOF_G'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "br.com.lista"
    compileSdk = 35

    defaultConfig {
        applicationId = "br.com.lista"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.webkit:webkit:1.12.1")
}
EOF_G

cat > app/src/main/AndroidManifest.xml <<'EOF_G'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />

    <application
        android:allowBackup="true"
        android:icon="@drawable/ic_launcher"
        android:label="Lista de compras"
        android:roundIcon="@drawable/ic_launcher"
        android:supportsRtl="true"
        android:theme="@style/AppTheme">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF_G

cat > app/src/main/res/values/themes.xml <<'EOF_G'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:statusBarColor">#16A34A</item>
        <item name="android:navigationBarColor">#FFFFFF</item>
        <item name="android:windowLightNavigationBar">true</item>
    </style>
</resources>
EOF_G

cat > app/src/main/res/drawable/ic_launcher.xml <<'EOF_G'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#16A34A" android:pathData="M0,0h108v108h-108z" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M36,26h36a6,6 0 0 1 6,6v50a6,6 0 0 1 -6,6h-36a6,6 0 0 1 -6,-6v-50a6,6 0 0 1 6,-6z" />
    <path android:fillColor="#16A34A" android:pathData="M40,38h28v6h-28z" />
    <path android:fillColor="#16A34A" android:pathData="M40,52h20v5h-20z" />
    <path android:fillColor="#16A34A" android:pathData="M40,64h24v5h-24z" />
    <path android:fillColor="#16A34A" android:pathData="M40,76h14v5h-14z" />
</vector>
EOF_G

cat > app/src/main/java/br/com/lista/MainActivity.kt <<'EOF_G'
package br.com.lista

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.webkit.WebViewAssetLoader
import java.io.File

class MainActivity : Activity() {

    private lateinit var web: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val loader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        web = WebView(this)
        web.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )

        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = false
            setSupportZoom(false)
            builtInZoomControls = false
        }

        web.addJavascriptInterface(Bridge(), "AndroidBridge")

        web.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ): WebResourceResponse? = loader.shouldInterceptRequest(request.url)

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                val url = request.url
                return if (url.host == "appassets.androidplatform.net") {
                    false
                } else {
                    startActivity(Intent(Intent.ACTION_VIEW, url))
                    true
                }
            }
        }

        if (BuildConfig.DEBUG) {
            WebView.setWebContentsDebuggingEnabled(true)
        }

        setContentView(web)
        web.loadUrl("https://appassets.androidplatform.net/assets/index.html")
    }

    @Deprecated("Compatibilidade com Activity base")
    override fun onBackPressed() {
        if (this::web.isInitialized && web.canGoBack()) web.goBack() else super.onBackPressed()
    }

    inner class Bridge {
        @JavascriptInterface
        fun saveFile(base64: String, filename: String, mime: String) {
            runOnUiThread {
                try {
                    val bytes = Base64.decode(base64, Base64.DEFAULT)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                            put(MediaStore.MediaColumns.MIME_TYPE, mime)
                            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        }
                        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        uri?.let { contentResolver.openOutputStream(it)?.use { s -> s.write(bytes) } }
                    } else {
                        @Suppress("DEPRECATION")
                        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        dir.mkdirs()
                        File(dir, filename).writeBytes(bytes)
                    }
                    Toast.makeText(this@MainActivity, "Salvo em Downloads", Toast.LENGTH_SHORT).show()
                } catch (e: Exception) {
                    Toast.makeText(this@MainActivity, "Falha ao salvar arquivo", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
}
EOF_G

cat > app/src/main/assets/index.html <<'EOF_HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Lista de compras</title>
<style>
  *{-webkit-tap-highlight-color:transparent}
  body{margin:0;padding:16px 14px 28px;background:#fff;color:#111827;font-family:system-ui,-apple-system,sans-serif;font-size:16px}
  h1{font-size:20px;font-weight:600;margin:0 0 2px;letter-spacing:-.01em}
  .sub{font-size:12px;color:#6b7280;margin:0}
  .card{background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:14px;margin:12px 0 10px}
  .total-line{display:flex;align-items:baseline;justify-content:space-between;gap:10px}
  .lbl{font-size:12px;color:#6b7280}
  .total{font-size:24px;font-weight:600;font-variant-numeric:tabular-nums;letter-spacing:-.02em}
  .total.over{color:#dc2626}
  .total-mini{display:flex;justify-content:space-between;font-size:12px;color:#6b7280;margin-top:6px;font-variant-numeric:tabular-nums}
  .total-mini .v{color:#16a34a;font-weight:500}
  .bar{height:4px;border-radius:4px;background:#e5e7eb;margin-top:10px;overflow:hidden}
  .bar>i{display:block;height:100%;width:0;background:#16a34a;transition:width .18s ease}
  .bar>i.over{background:#dc2626}
  .budget{display:flex;align-items:center;gap:8px;margin-top:12px;padding-top:11px;border-top:1px solid #e5e7eb}
  .budget label{font-size:12px;color:#6b7280;flex:0 0 auto}
  .budget .money{flex:1}
  .status{font-size:11px;text-align:right;flex:0 0 auto;font-variant-numeric:tabular-nums;color:#6b7280}
  .status.bad{color:#dc2626;font-weight:500}
  .status.ok{color:#16a34a}
  .warn{display:none;margin-top:10px;padding:8px 10px;border-radius:8px;font-size:12px;background:#fef2f2;border:1px solid #dc2626;color:#dc2626}
  .warn.on{display:block}
  .add{background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:12px;margin-bottom:14px}
  .add input,.add select{width:100%;box-sizing:border-box}
  .add .row{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
  input,select{background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:10px;font-size:16px;font-family:inherit;color:#111827;outline:none;appearance:none;-webkit-appearance:none}
  input:focus,select:focus{border-color:#16a34a}
  select{cursor:pointer;margin-top:8px}
  .money{position:relative}
  .money span{position:absolute;left:10px;top:50%;transform:translateY(-50%);font-size:12px;color:#6b7280;pointer-events:none}
  .money input{padding-left:28px;text-align:right;font-variant-numeric:tabular-nums}
  button{font-family:inherit;font-size:15px;border-radius:8px;border:1px solid transparent;cursor:pointer;font-weight:500}
  .btn-primary{width:100%;margin-top:8px;padding:12px;background:#16a34a;color:#fff}
  .ghost{background:#fff;border:1px solid #e5e7eb;color:#6b7280;padding:10px;font-size:13px}
  .group{margin-bottom:14px}
  .ghead{display:flex;justify-content:space-between;align-items:baseline;padding:0 2px 6px;border-bottom:1px solid #e5e7eb;margin-bottom:8px}
  .gname{font-size:11px;font-weight:500;color:#6b7280;letter-spacing:.03em}
  .gsub{font-size:11px;color:#6b7280;font-variant-numeric:tabular-nums}
  ul{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:8px}
  li{background:#f9fafb;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px}
  li.done{opacity:.55}
  li.done .name{text-decoration:line-through}
  .l1{display:flex;align-items:center;gap:9px}
  .l1 input[type=checkbox]{width:20px;height:20px;flex:0 0 auto;accent-color:#16a34a;padding:0}
  .name{flex:1;min-width:0;background:transparent;border:none;padding:2px 0;font-size:15px;font-weight:500}
  .del{background:transparent;border:none;color:#6b7280;font-size:20px;line-height:1;padding:2px 4px}
  .l2{display:flex;align-items:center;gap:8px;margin-top:8px;padding-left:29px}
  .step{display:flex;align-items:center;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;background:#fff}
  .step button{background:transparent;border:none;color:#111827;width:30px;height:34px;font-size:16px;padding:0}
  .step input{width:40px;text-align:center;border:none;border-left:1px solid #e5e7eb;border-right:1px solid #e5e7eb;border-radius:0;padding:6px 0;font-size:14px}
  .unit{flex:1;min-width:0}
  .unit input{width:100%;padding:6px 26px 6px 8px;font-size:14px;text-align:right}
  .unit span{font-size:11px;left:8px}
  .line{font-size:14px;font-weight:500;min-width:76px;text-align:right;font-variant-numeric:tabular-nums}
  .cat{width:100%;margin-top:8px;padding:6px 8px;font-size:12px;color:#6b7280;border-radius:6px}
  .empty{text-align:center;padding:26px 12px;border:1px dashed #e5e7eb;border-radius:12px;color:#6b7280;font-size:13px}
  .foot{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:14px}
  .foot .wide{grid-column:1 / -1}
  .panel{display:none;margin-top:12px;background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:12px}
  .panel.on{display:block}
  .panel h2{font-size:12px;font-weight:500;margin:0 0 8px;color:#6b7280}
  textarea{width:100%;box-sizing:border-box;min-height:170px;background:#fff;border:1px solid #e5e7eb;border-radius:8px;padding:10px;font-family:ui-monospace,Menlo,monospace;font-size:12px;line-height:1.5;color:#111827;resize:vertical;outline:none}
  .panel .row{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
  .hint{font-size:11px;color:#6b7280;text-align:center;margin-top:12px}
</style>
</head>
<body>
<h1>Lista de compras</h1>
<p class="sub" id="sub">—</p>

<div class="card">
  <div class="total-line">
    <span class="lbl">Total da compra</span>
    <span class="total" id="total">R$ 0,00</span>
  </div>
  <div class="total-mini">
    <span id="prog">0 de 0 marcados</span>
    <span class="v" id="doneTotal">R$ 0,00</span>
  </div>
  <div class="bar"><i id="bar"></i></div>
  <div class="budget">
    <label for="budget">Orçamento</label>
    <div class="money"><span>R$</span><input id="budget" inputmode="decimal" placeholder="0,00"></div>
    <span class="status" id="status"></span>
  </div>
  <div class="warn" id="warn" role="status"></div>
</div>

<div class="add">
  <input id="newName" placeholder="Nome do item" autocomplete="off">
  <select id="newCat" aria-label="Seção"></select>
  <div class="row">
    <input id="newQty" inputmode="decimal" value="1" placeholder="Qtd.">
    <div class="money"><span>R$</span><input id="newPrice" inputmode="decimal" placeholder="0,00"></div>
  </div>
  <button class="btn-primary" id="addBtn">Adicionar item</button>
</div>

<div id="groups"></div>
<div class="empty" id="empty">A lista está vazia. Adicione o primeiro item acima.</div>

<div class="foot">
  <button class="ghost" id="clearDone">Remover marcados</button>
  <button class="ghost" id="clearAll">Limpar tudo</button>
  <button class="ghost wide" id="exportBtn">Exportar lista</button>
</div>

<div class="panel" id="panel">
  <h2>Prévia da exportação</h2>
  <textarea id="preview" readonly></textarea>
  <div class="row">
    <button class="ghost" id="copyBtn">Copiar texto</button>
    <button class="ghost" id="imgBtn">Baixar imagem</button>
  </div>
  <div class="row">
    <button class="ghost" id="txtBtn">Baixar .txt</button>
    <button class="ghost" id="closeBtn">Fechar</button>
  </div>
</div>

<p class="hint">Os valores e o orçamento ficam salvos neste aparelho.</p>

<script>
(function () {
  var KEY = 'lista_compras_v2';
  var brl = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
  var n2 = function (v) { return v.toFixed(2).replace('.', ','); };
  var $ = function (id) { return document.getElementById(id); };

  var CATS = ['Hortifruti','Açougue e peixaria','Frios e laticínios','Padaria','Mercearia','Bebidas','Congelados','Limpeza','Higiene e beleza','Pet','Outros'];

  var seq = 0;
  var uid = function () { seq++; return 'i' + seq + Date.now().toString(36); };
  var budget = 0;
  var state = [];

  try {
    var raw = localStorage.getItem(KEY);
    if (raw) {
      var p = JSON.parse(raw);
      budget = Number(p.budget) || 0;
      state = (p.items || []).map(function (i) {
        return {
          id: i.id || uid(), name: i.name || '', qty: Number(i.qty) || 1,
          price: Number(i.price) || 0, done: !!i.done,
          cat: CATS.indexOf(i.cat) >= 0 ? i.cat : 'Outros'
        };
      });
    }
  } catch (e) { state = []; }

  if (!state.length && !localStorage.getItem(KEY)) {
    state = [
      { id: uid(), name: 'Arroz 5 kg', qty: 1, price: 27.9, done: false, cat: 'Mercearia' },
      { id: uid(), name: 'Leite integral 1 L', qty: 2, price: 5.49, done: false, cat: 'Frios e laticínios' },
      { id: uid(), name: 'Detergente 500 ml', qty: 1, price: 3.19, done: false, cat: 'Limpeza' }
    ];
  }

  var save = function () { try { localStorage.setItem(KEY, JSON.stringify({ budget: budget, items: state })); } catch (e) {} };

  var parsePrice = function (raw) {
    var s = String(raw).replace(/[^\d.,]/g, '');
    if (!s) return 0;
    if (s.indexOf(',') >= 0) s = s.replace(/\./g, '').replace(',', '.');
    else if (s.split('.').length > 2) s = s.split('.').join('');
    var v = parseFloat(s);
    return isNaN(v) ? 0 : v;
  };
  var parseQty = function (raw) {
    var v = parseFloat(String(raw).replace(',', '.'));
    return isNaN(v) || v <= 0 ? 1 : v;
  };

  CATS.forEach(function (c) {
    var o = document.createElement('option');
    o.value = c; o.textContent = c;
    $('newCat').append(o);
  });
  $('newCat').value = 'Mercearia';

  function totals() {
    var all = 0, done = 0, count = 0, marked = 0;
    state.forEach(function (it) {
      var l = it.qty * it.price;
      all += l; count++;
      if (it.done) { done += l; marked++; }
    });
    return { all: all, done: done, count: count, marked: marked };
  }

  function refresh() {
    var t = totals();
    var over = budget > 0 && t.all > budget;

    $('total').textContent = brl.format(t.all);
    $('total').classList.toggle('over', over);
    $('doneTotal').textContent = brl.format(t.done);
    $('prog').textContent = t.count ? t.marked + ' de ' + t.count + ' marcados' : '0 de 0 marcados';
    $('sub').textContent = t.count ? t.count + (t.count === 1 ? ' item na lista' : ' itens na lista') : 'Nenhum item';
    $('empty').style.display = t.count ? 'none' : 'block';

    var ratio = budget > 0 ? Math.min(t.all / budget, 1) : (t.count ? t.marked / t.count : 0);
    $('bar').style.width = (ratio * 100) + '%';
    $('bar').classList.toggle('over', over);

    var st = $('status');
    if (!budget) { st.textContent = ''; st.className = 'status'; }
    else if (over) { st.textContent = 'estourou ' + brl.format(t.all - budget); st.className = 'status bad'; }
    else { st.textContent = 'faltam ' + brl.format(budget - t.all); st.className = 'status ok'; }

    var w = $('warn');
    w.classList.toggle('on', over);
    if (over) w.textContent = 'Orçamento estourado em ' + brl.format(t.all - budget) + '. Revise a lista ou aumente o limite.';
  }

  function row(it) {
    var li = document.createElement('li');
    li.dataset.id = it.id;
    if (it.done) li.classList.add('done');

    var l1 = document.createElement('div'); l1.className = 'l1';
    var cb = document.createElement('input');
    cb.type = 'checkbox'; cb.checked = it.done; cb.dataset.act = 'toggle';
    var name = document.createElement('input');
    name.className = 'name'; name.value = it.name; name.dataset.field = 'name';
    var del = document.createElement('button');
    del.className = 'del'; del.textContent = '×'; del.dataset.act = 'del';
    l1.appendChild(cb); l1.appendChild(name); l1.appendChild(del);

    var l2 = document.createElement('div'); l2.className = 'l2';
    var step = document.createElement('div'); step.className = 'step';
    var minus = document.createElement('button');
    minus.textContent = '−'; minus.dataset.act = 'minus';
    var qty = document.createElement('input');
    qty.inputMode = 'decimal'; qty.value = String(it.qty).replace('.', ','); qty.dataset.field = 'qty';
    var plus = document.createElement('button');
    plus.textContent = '+'; plus.dataset.act = 'plus';
    step.appendChild(minus); step.appendChild(qty); step.appendChild(plus);

    var unit = document.createElement('div'); unit.className = 'money unit';
    var pre = document.createElement('span'); pre.textContent = 'R$';
    var price = document.createElement('input');
    price.inputMode = 'decimal'; price.value = it.price ? n2(it.price) : ''; price.placeholder = '0,00';
    price.dataset.field = 'price';
    unit.appendChild(pre); unit.appendChild(price);

    var line = document.createElement('span');
    line.className = 'line'; line.textContent = brl.format(it.qty * it.price);
    l2.appendChild(step); l2.appendChild(unit); l2.appendChild(line);

    var cat = document.createElement('select');
    cat.className = 'cat'; cat.dataset.field = 'cat';
    CATS.forEach(function (c) {
      var o = document.createElement('option');
      o.value = c; o.textContent = c;
      if (c === it.cat) o.selected = true;
      cat.appendChild(o);
    });

    li.appendChild(l1); li.appendChild(l2); li.appendChild(cat);
    return li;
  }

  function render() {
    var box = $('groups');
    box.textContent = '';
    CATS.forEach(function (cat) {
      var items = state.filter(function (i) { return i.cat === cat; });
      if (!items.length) return;
      var sec = document.createElement('section');
      sec.className = 'group';
      sec.dataset.cat = cat;
      var head = document.createElement('div');
      head.className = 'ghead';
      var gn = document.createElement('span');
      gn.className = 'gname'; gn.textContent = cat;
      var gs = document.createElement('span');
      gs.className = 'gsub';
      gs.textContent = brl.format(items.reduce(function (s, i) { return s + i.qty * i.price; }, 0));
      head.appendChild(gn); head.appendChild(gs);
      var ul = document.createElement('ul');
      items.forEach(function (i) { ul.appendChild(row(i)); });
      sec.appendChild(head); sec.appendChild(ul);
      box.appendChild(sec);
    });
    refresh();
  }

  function refreshGroup(cat) {
    var sec = document.querySelector('.group[data-cat="' + cat + '"]');
    if (!sec) return;
    var sum = state.filter(function (i) { return i.cat === cat; }).reduce(function (s, i) { return s + i.qty * i.price; }, 0);
    sec.querySelector('.gsub').textContent = brl.format(sum);
  }

  function find(el) {
    var li = el.closest('li');
    if (!li) return null;
    var id = li.dataset.id;
    return state.filter(function (x) { return x.id === id; })[0] || null;
  }

  $('groups').addEventListener('input', function (e) {
    var it = find(e.target);
    if (!it) return;
    var f = e.target.dataset.field;
    if (f === 'name') it.name = e.target.value;
    else if (f === 'qty') it.qty = parseQty(e.target.value);
    else if (f === 'price') it.price = parsePrice(e.target.value);
    else return;
    e.target.closest('li').querySelector('.line').textContent = brl.format(it.qty * it.price);
    save(); refresh(); refreshGroup(it.cat);
  });

  $('groups').addEventListener('change', function (e) {
    var it = find(e.target);
    if (!it) return;
    if (e.target.dataset.act === 'toggle') {
      it.done = e.target.checked;
      e.target.closest('li').classList.toggle('done', it.done);
      save(); refresh();
    } else if (e.target.dataset.field === 'cat') {
      it.cat = e.target.value;
      save(); render();
    }
  });

  $('groups').addEventListener('click', function (e) {
    var act = e.target.dataset.act;
    if (!act || act === 'toggle') return;
    var it = find(e.target);
    if (!it) return;
    var li = e.target.closest('li');
    if (act === 'del') {
      var cat = it.cat;
      state = state.filter(function (x) { return x.id !== it.id; });
      var sec = li.closest('.group');
      li.remove();
      if (sec && !sec.querySelector('li')) sec.remove(); else refreshGroup(cat);
    } else if (act === 'plus' || act === 'minus') {
      it.qty = Math.max(1, Math.round((it.qty + (act === 'plus' ? 1 : -1)) * 100) / 100);
      li.querySelector('[data-field=qty]').value = String(it.qty).replace('.', ',');
      li.querySelector('.line').textContent = brl.format(it.qty * it.price);
      refreshGroup(it.cat);
    }
    save(); refresh();
  });

  $('groups').addEventListener('blur', function (e) {
    var it = find(e.target);
    if (!it) return;
    var f = e.target.dataset.field;
    if (f === 'price') e.target.value = it.price ? n2(it.price) : '';
    else if (f === 'qty') e.target.value = String(it.qty).replace('.', ',');
  }, true);

  $('budget').addEventListener('input', function (e) { budget = parsePrice(e.target.value); save(); refresh(); });
  $('budget').addEventListener('blur', function (e) { e.target.value = budget ? n2(budget) : ''; save(); });

  function addItem() {
    var name = $('newName').value.trim();
    if (!name) { $('newName').focus(); return; }
    var it = { id: uid(), name: name, qty: parseQty($('newQty').value), price: parsePrice($('newPrice').value), done: false, cat: $('newCat').value };
    state.push(it);
    $('newName').value = ''; $('newQty').value = '1'; $('newPrice').value = '';
    $('newName').focus();
    save(); render();
  }

  $('addBtn').addEventListener('click', addItem);
  $('newName').addEventListener('keydown', function (e) { if (e.key === 'Enter') addItem(); });
  $('newPrice').addEventListener('keydown', function (e) { if (e.key === 'Enter') addItem(); });

  $('clearDone').addEventListener('click', function () {
    if (!state.some(function (i) { return i.done; })) return;
    state = state.filter(function (i) { return !i.done; });
    save(); render();
  });
  $('clearAll').addEventListener('click', function () {
    if (!state.length) return;
    state = [];
    save(); render();
  });

  function exportLines() {
    var t = totals();
    var out = [{ t: 'LISTA DE COMPRAS', k: 'title' }, { t: '', k: 'gap' }];
    out.push({ t: 'Total: ' + brl.format(t.all), k: 'total' });
    if (budget > 0) out.push({
      t: t.all > budget
        ? 'Orçamento: ' + brl.format(budget) + ' — estourou ' + brl.format(t.all - budget)
        : 'Orçamento: ' + brl.format(budget) + ' — faltam ' + brl.format(budget - t.all),
      k: t.all > budget ? 'bad' : 'budget'
    });
    out.push({ t: '', k: 'gap' });
    CATS.forEach(function (cat) {
      var items = state.filter(function (i) { return i.cat === cat; });
      if (!items.length) return;
      var sub = items.reduce(function (s, i) { return s + i.qty * i.price; }, 0);
      out.push({ t: cat.toUpperCase() + ' — ' + brl.format(sub), k: 'group' });
      items.forEach(function (i) {
        out.push({
          t: (i.done ? '[x] ' : '[ ] ') + i.name + ' — ' + i.qty + ' × ' + brl.format(i.price) + ' = ' + brl.format(i.qty * i.price),
          k: i.done ? 'done' : 'item'
        });
      });
      out.push({ t: '', k: 'gap' });
    });
    out.push({ t: t.marked + ' de ' + t.count + ' itens marcados', k: 'foot' });
    return out;
  }

  function buildText() {
    return exportLines().map(function (l) { return l.t; }).join('\n');
  }

  $('exportBtn').addEventListener('click', function () {
    $('preview').value = state.length ? buildText() : 'A lista está vazia.';
    $('panel').classList.add('on');
  });
  $('closeBtn').addEventListener('click', function () { $('panel').classList.remove('on'); });

  $('copyBtn').addEventListener('click', function () {
    var txt = buildText();
    if (navigator.clipboard) {
      navigator.clipboard.writeText(txt).catch(function () {
        $('preview').select(); document.execCommand('copy');
      });
    } else {
      $('preview').select(); document.execCommand('copy');
    }
    $('copyBtn').textContent = 'Copiado';
    setTimeout(function () { $('copyBtn').textContent = 'Copiar texto'; }, 1600);
  });

  function download(blob, filename) {
    if (window.AndroidBridge && window.AndroidBridge.saveFile) {
      var fr = new FileReader();
      fr.onloadend = function () {
        window.AndroidBridge.saveFile(String(fr.result).split(',')[1], filename, blob.type || 'application/octet-stream');
      };
      fr.readAsDataURL(blob);
      return;
    }
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 4000);
  }

  $('txtBtn').addEventListener('click', function () {
    download(new Blob([buildText()], { type: 'text/plain;charset=utf-8' }), 'lista-de-compras.txt');
  });

  var FONT = {
    title: '600 22px sans-serif', total: '600 18px sans-serif',
    budget: '400 14px sans-serif', bad: '600 14px sans-serif',
    group: '500 12px sans-serif', item: '400 14px sans-serif',
    done: '400 14px sans-serif', foot: '400 12px sans-serif', gap: '400 10px sans-serif'
  };
  var COLOR = { title: '#111827', total: '#111827', budget: '#6b7280', bad: '#dc2626', group: '#6b7280', item: '#111827', done: '#9ca3af', foot: '#6b7280', gap: '#ffffff' };

  function wrap(ctx, text, max) {
    if (!text) return [''];
    var lines = [];
    var cur = '';
    text.split(' ').forEach(function (w) {
      var test = cur ? cur + ' ' + w : w;
      if (ctx.measureText(test).width > max && cur) { lines.push(cur); cur = w; }
      else cur = test;
    });
    if (cur) lines.push(cur);
    return lines;
  }

  $('imgBtn').addEventListener('click', function () {
    if (!state.length) return;
    var W = 720, PAD = 40, LH = 26;
    var c = document.createElement('canvas');
    var ctx = c.getContext('2d');
    var flat = [];
    exportLines().forEach(function (l) {
      ctx.font = FONT[l.k];
      wrap(ctx, l.t, W - PAD * 2).forEach(function (part) { flat.push({ t: part, k: l.k }); });
    });
    var H = PAD * 2 + flat.length * LH;
    c.width = W; c.height = H;
    ctx = c.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, W, H);
    var y = PAD + 20;
    flat.forEach(function (l) {
      ctx.font = FONT[l.k];
      ctx.fillStyle = COLOR[l.k];
      ctx.fillText(l.t, PAD, y);
      if (l.k === 'done') ctx.fillRect(PAD, y - 5, ctx.measureText(l.t).width, 1);
      y += LH;
    });
    c.toBlob(function (b) { download(b, 'lista-de-compras.png'); });
  });

  render();
})();
</script>
</body>
</html>
EOF_HTML

echo "projeto criado"
