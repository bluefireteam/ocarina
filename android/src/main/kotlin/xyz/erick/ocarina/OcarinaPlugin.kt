package xyz.erick.ocarina

import android.content.Context
import android.net.Uri
import android.os.storage.StorageVolume
import androidx.annotation.NonNull;
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.SimpleExoPlayer
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory
import com.google.android.exoplayer2.source.*
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory
import com.google.android.exoplayer2.util.Util.getUserAgent

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.lang.RuntimeException

abstract class OcarinaPlayer {
  protected var volume: Double;
  protected var loop: Boolean;
  protected var context: Context;
  protected val url: String;
  protected lateinit var player: SimpleExoPlayer;
  protected lateinit var mediaSource: MediaSource;
  private val listener: OcarinaListener;

  constructor(url: String, volume: Double, loop: Boolean, context: Context) {
    this.url = url;
    this.volume = volume;
    this.loop = loop;
    this.context = context;
    this.listener = OcarinaListener(url);
  }

  // trying to track https://github.com/erickzanardo/ocarina/issues/4
  private fun checkInitialized() {
      if (!this::player.isInitialized) {
        throw RuntimeException("Player is not initialized");
      }
    if (!this::mediaSource.isInitialized) {
      throw RuntimeException("MediaSource is not initialized");
    }
  }

  fun dispose() {
    checkInitialized();
    player.release();
  }

  fun play() {
    checkInitialized();
    if (player.playbackState == Player.STATE_ENDED)
      player.seekTo(0);
    else if(player.playbackState == Player.STATE_IDLE)
      player.prepare(mediaSource);

    player.playWhenReady = true;
  }

  fun stop() {
    checkInitialized();
    player.stop();
  }

  fun pause() {
    checkInitialized();
    player.playWhenReady = false;
  }

  fun resume() {
    checkInitialized();
    player.playWhenReady = true;
  }

  fun load() {
    // trying to track https://github.com/erickzanardo/ocarina/issues/4
    if (context == null) {
      throw RuntimeException("Context is null");
    }
    player = SimpleExoPlayer.Builder(context).build();
    if (loop)
      player.repeatMode = Player.REPEAT_MODE_ALL;
    else
      player.repeatMode = Player.REPEAT_MODE_OFF;

    mediaSource = extractMediaSourceFromUri(url);
  }

  fun seek(position: Long) {
    checkInitialized();
    player.seekTo(position);
  }

  fun position(): Long {
    checkInitialized();
    return player.getCurrentPosition();
  }

  fun volume(volume: Double) {
    checkInitialized();
    this.volume = volume;
    player.volume = volume.toFloat();
  }

  internal fun addListener() {
    player.addListener(listener);
  }

  internal fun removeListener() {
    player.removeListener(listener);
  }

  protected fun mediaSourceFromUriString(uri: String): MediaSource {
    val mediaItem = MediaItem.Builder().setUri(Uri.parse(uri)).build();
    return ProgressiveMediaSource.Factory(
      DefaultDataSourceFactory(context,"ua"),
      DefaultExtractorsFactory()).createMediaSource(mediaItem);
  }

  abstract fun extractMediaSourceFromUri(uri: String): MediaSource;
}

class AssetOcarinaPlayer(url: String, packageName: String?, volume: Double, loop: Boolean, context: Context) : OcarinaPlayer(url, volume, loop, context) {
  private lateinit var flutterAssets: FlutterPlugin.FlutterAssets;
  private var packageName: String? = null;

  constructor(url: String, packageName: String?, volume: Double, loop: Boolean, context: Context, flutterAssets: FlutterPlugin.FlutterAssets): this(url, packageName, volume, loop, context) {
    this.flutterAssets = flutterAssets;
    this.packageName = packageName;
  }

  override fun extractMediaSourceFromUri(uri: String): MediaSource {
    // trying to track https://github.com/erickzanardo/ocarina/issues/4
    if (!this::flutterAssets.isInitialized) {
      throw RuntimeException("FlutterAssets is not initialized");
    }

    val userAgent = getUserAgent(context, "ocarina");

    val assetUrl = if (packageName != null) flutterAssets.getAssetFilePathByName(uri, packageName!!) else flutterAssets.getAssetFilePathByName(uri);

    // find file on assets
    return mediaSourceFromUriString("file:///android_asset/" + assetUrl);
  }
}

class FileOcarinaPlayer(url: String, volume: Double, loop: Boolean, context: Context) : OcarinaPlayer(url, volume, loop, context) {

  override fun extractMediaSourceFromUri(uri: String): MediaSource {
    val userAgent = getUserAgent(context, "ocarina");

    return mediaSourceFromUriString(uri);
  }
}

class OcarinaListener(private val url: String) : Player.Listener {
  override fun onIsPlayingChanged(isPlaying: Boolean) {
    OcarinaPlugin.notifyListeners(url, isPlaying)
  }
}

public class OcarinaPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private var playerIds = 0;
  private lateinit var flutterAssets: FlutterPlugin.FlutterAssets;
  private lateinit var context: Context;

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "ocarina")
    channel.setMethodCallHandler(this);

    flutterAssets = flutterPluginBinding.flutterAssets;
    context = flutterPluginBinding.applicationContext;
  }

  companion object {
    private val players = mutableMapOf<Int, OcarinaPlayer>();
    private val listeners: HashMap<String, (url: String, isPlaying: Boolean) -> Unit> = hashMapOf();

    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "ocarina")

      channel.setMethodCallHandler(OcarinaPlugin())
    }

    @JvmStatic
    fun notifyListeners(url: String, isPlaying: Boolean) {
      listeners.values.forEach { it.invoke(url, isPlaying) }
    }

    @JvmStatic
    fun addListener(@NonNull id: String, @NonNull listener: (url: String, isPlaying: Boolean) -> Unit) {
      if (listeners.isEmpty() && players.isNotEmpty()) {
        players.values.forEach { it.addListener() }
      }
      listeners.put(id, listener);
    }

    @JvmStatic
    fun removeListener(@NonNull id: String) {
      listeners.remove(id);
      if (listeners.isEmpty() && players.isNotEmpty()) {
        players.values.forEach { it.removeListener() }
      }
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "load") {
      load(call, result)
    } else if (call.method == "play") {
      play(call, result)
    } else if (call.method == "stop") {
      stop(call, result)
    } else if (call.method == "pause") {
      pause(call, result)
    } else if (call.method == "resume") {
      resume(call, result)
    } else if (call.method == "seek") {
      seek(call, result)
    } else if (call.method == "position") {
      position(call, result)
    } else if (call.method == "volume") {
      volume(call, result)
    } else if (call.method == "dispose") {
      dispose(call, result)
    } else {
      result.notImplemented()
    }
  }

  fun load(@NonNull call: MethodCall, @NonNull result: Result) {
    val id = playerIds;
    val url = call.argument<String>("url");
    val packageName = call.argument<String>("package");
    val volume = call.argument<Double>("volume");
    val loop = call.argument<Boolean>("loop");
    val isAsset = call.argument<Boolean>("isAsset");

    var player: OcarinaPlayer = if (isAsset!!) {
      AssetOcarinaPlayer(url!!, packageName, volume!!, loop!!, context, flutterAssets);
    } else {
      FileOcarinaPlayer(url!!, volume!!, loop!!, context);
    }
    player.load();

    players.put(id, player);

    playerIds++;

    if (!listeners.isEmpty()) {
      player.addListener()
    }

    result.success(id);
  }

  fun play(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val player = players[playerId!!];
    player!!.play();

    result.success(0);
  }

  fun stop(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val player = players[playerId!!];
    player!!.stop();

    result.success(0);
  }

  fun pause(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val player = players[playerId!!];
    player!!.pause();

    result.success(0);
  }

  fun resume(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val player = players[playerId!!];
    player!!.resume();

    result.success(0);
  }

  fun seek(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val position = call.argument<Int>("position");
    val player = players[playerId!!];
    player!!.seek(position!!.toLong());

    result.success(0);
  }

  fun position(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val player = players[playerId!!];
    val position = player!!.position();

    result.success(position);
  }

  fun volume(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val volume = call.argument<Double>("volume");
    val player = players[playerId!!];
    player!!.volume(volume!!);

    result.success(0);
  }

  fun dispose(@NonNull call: MethodCall, @NonNull result: Result) {
    val playerId = call.argument<Int>("playerId");
    val player = players[playerId!!];
    player!!.dispose();
    players.remove(playerId!!);

    result.success(0);
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
