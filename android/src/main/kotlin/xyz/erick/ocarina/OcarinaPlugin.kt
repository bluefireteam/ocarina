package xyz.erick.ocarina

import android.content.Context
import android.net.Uri
import android.os.storage.StorageVolume
import androidx.annotation.NonNull;
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.SimpleExoPlayer
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory
import com.google.android.exoplayer2.source.ExtractorMediaSource
import com.google.android.exoplayer2.source.MediaSource
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

  constructor(url: String, volume: Double, loop: Boolean, context: Context) {
    this.url = url;
    this.volume = volume;
    this.loop = loop;
    this.context = context;
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

  fun volume(volume: Double) {
    checkInitialized();
    this.volume = volume;
    player.volume = volume.toFloat();
  }

  abstract fun extractMediaSourceFromUri(uri: String): MediaSource;
}

class AssetOcarinaPlayer(url: String, volume: Double, loop: Boolean, context: Context) : OcarinaPlayer(url, volume, loop, context) {
  private lateinit var flutterAssets: FlutterPlugin.FlutterAssets;

  constructor(url: String, volume: Double, loop: Boolean, context: Context, flutterAssets: FlutterPlugin.FlutterAssets): this(url, volume, loop, context) {
    this.flutterAssets = flutterAssets;
  }

  override fun extractMediaSourceFromUri(uri: String): MediaSource {
    // trying to track https://github.com/erickzanardo/ocarina/issues/4
    if (!this::flutterAssets.isInitialized) {
      throw RuntimeException("FlutterAssets is not initialized");
    }

    val userAgent = getUserAgent(context, "ocarina");

    val assetUrl = flutterAssets.getAssetFilePathByName(uri);

    // find file on assets
    return ExtractorMediaSource(Uri.parse("file:///android_asset/" + assetUrl),
            DefaultDataSourceFactory(context,"ua"),
            DefaultExtractorsFactory(), null, null);
  }
}

class FileOcarinaPlayer(url: String, volume: Double, loop: Boolean, context: Context) : OcarinaPlayer(url, volume, loop, context) {

  override fun extractMediaSourceFromUri(uri: String): MediaSource {
    val userAgent = getUserAgent(context, "ocarina");

    return ExtractorMediaSource(Uri.parse(url),
            DefaultDataSourceFactory(context,"ua"),
            DefaultExtractorsFactory(), null, null);
  }
}

public class OcarinaPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private val players = mutableMapOf<Int, OcarinaPlayer>();
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
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "ocarina")

      channel.setMethodCallHandler(OcarinaPlugin())
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "load") {
      val id = playerIds;
      val url = call.argument<String>("url");
      val volume = call.argument<Double>("volume");
      val loop = call.argument<Boolean>("loop");
      val isAsset = call.argument<Boolean>("isAsset");

      var player: OcarinaPlayer = if (isAsset!!) {
        AssetOcarinaPlayer(url!!, volume!!, loop!!, context, flutterAssets);
      } else {
        FileOcarinaPlayer(url!!, volume!!, loop!!, context);
      }
      player.load();

      players.put(id, player);

      playerIds++;

      result.success(id);
    } else if (call.method == "play") {
      val playerId = call.argument<Int>("playerId");
      val player = players[playerId!!];
      player!!.play();

      result.success(0);
    } else if (call.method == "stop") {
      val playerId = call.argument<Int>("playerId");
      val player = players[playerId!!];
      player!!.stop();

      result.success(0);
    } else if (call.method == "pause") {
      val playerId = call.argument<Int>("playerId");
      val player = players[playerId!!];
      player!!.pause();

      result.success(0);
    } else if (call.method == "resume") {
      val playerId = call.argument<Int>("playerId");
      val player = players[playerId!!];
      player!!.resume();

      result.success(0);
    } else if (call.method == "seek") {
      val playerId = call.argument<Int>("playerId");
      val position = call.argument<Int>("position");
      val player = players[playerId!!];
      player!!.seek(position!!.toLong());

      result.success(0);
    } else if (call.method == "volume") {
      val playerId = call.argument<Int>("playerId");
      val volume = call.argument<Double>("volume");
      val player = players[playerId!!];
      player!!.volume(volume!!);

      result.success(0);
    } else if (call.method == "dispose") {
      val playerId = call.argument<Int>("playerId");
      val player = players[playerId!!];
      player!!.dispose();
      players.remove(playerId!!);

      result.success(0);
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
