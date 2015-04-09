package flaudiosprite;
import flash.errors.Error;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.TimerEvent;
import flash.Lib;
import flash.media.Sound;
import flash.media.SoundChannel;
import flash.net.URLRequest;
import flash.net.URLStream;
import flash.utils.ByteArray;
import flash.utils.Endian;
import flash.utils.JSON;
import flash.utils.Timer;
import flaudiosprite.AudioSprite.AudioNavigator;

/**
 * An AudioSprite Implementation for Flash, written in Haxe.
 * @author Pierre Chamberlain
 */
class AudioSprite extends EventDispatcher
{
	static var _callLaters:MapTimers;
	
	var _mapLoops:MapSound;
	var _mapSprites:MapItems;
	var _mapChannels:MapChannels;
	var _sortedSprites:ArraySprites;
	var _sortedIDs:Array<String>;
	var _allChannels:ArrayChannels;
	var _stoppedChannels:Array<String>;
	var _sound:Sound;
	var _soundBytes:ByteArray;
	var _stream:URLStream;
	var _isReady = false;
	var _isStoppingAll = false;
	var _playQueue:Array<String>;
	var _timer:Timer;
	var _timerResolution:Int = 1;
	var _timeLast:Float = 0;
	var _maxLength:Float = 0;
	
	public var navigator:AudioNavigator;
	
	public function new() {
		super();
		if (_callLaters == null) {
			_callLaters = new MapTimers();
		}
		
		_mapLoops = new MapSound();
		_mapSprites = new MapItems();
		_mapChannels = new MapChannels();
		_allChannels = new ArrayChannels();
		_playQueue = [];
		_stoppedChannels = [];
		
		_timeLast = Lib.getTimer() * 0.001;
		_timer = new Timer(_timerResolution);
		_timer.addEventListener(TimerEvent.TIMER, onTimerCycles);
		_timer.start();
	}
	
	public function setTimerResolution(value:Int) {
		_timerResolution = value;
	}
	
	public function load(url:String, alternateSound:Sound=null) {
		trace("Not implemented yet: " + url);
	}
	
	function loadFromDataAndSound( jsonData:String, sound:Sound = null ) {
		_sound = sound;
		if (_sound != null) {
			trace("Sound resource is supplied, will override JSON data.");
		}
		parseJSON( jsonData );
		navigator = new AudioNavigator(this);
		
		prepareSoundLoops();
	}
	
	public function loadFromEmbedded(jsonClass:Class<ByteArray>, mp3Class:Class<ByteArray>) 
	{
		var jsonData:ByteArray = Type.createEmptyInstance(jsonClass);
		var jsonStr = jsonData.readUTFBytes(jsonData.length);
		var mp3Bytes = Type.createEmptyInstance(mp3Class);
		
		var mp3Sound = new Sound();
		mp3Sound.loadCompressedDataFromByteArray( mp3Bytes, mp3Bytes.length );
		
		loadFromDataAndSound(jsonStr, mp3Sound);
	}
	
	function loadExternalSound(soundURL:String) {
		_stream = new URLStream();
		_stream.addEventListener(Event.COMPLETE, onExternalSoundComplete);
		_stream.load( new URLRequest(soundURL) );
	}
	
	private function onExternalSoundComplete(e:Event) {
		trace("Sound Loaded Externally.");
		_soundBytes = new ByteArray();
		_stream.readBytes(_soundBytes);
		
		_sound = new Sound();
		_sound.loadCompressedDataFromByteArray(_soundBytes, _soundBytes.length);
		_stream.close();
		_stream = null;
		
		prepareSoundLoops();
	}
	
	function parseJSON(jsonData:String) {
		_maxLength = 0;
		_sortedIDs = [];
		_sortedSprites = [];
		
		var data = JSON.parse( jsonData );
		if (_sound == null) {
			var foundMP3:String = null;
			var resources:Array<String> = data.resources;
			for (r in 0...resources.length) {
				var res:String = resources[r];
				if (res.indexOf(".mp3") > -1) {
					foundMP3 = res;
					break;
				}
			}
			
			if (foundMP3==null) throw new Error("No valid sound resources can be found in JSON data!");
			loadExternalSound( foundMP3 );
		}
		
		var sprites:Dynamic = data.spritemap;
		for (id in Reflect.fields(sprites)) {
			var spriteData:SpriteData = Reflect.field(sprites, id);
			var spriteItem = new AudioSpriteItem();
			spriteItem.id = id;
			spriteItem.start = spriteData.start;
			spriteItem.duration = (spriteData.end - spriteData.start);
			
			if (spriteData.loop == true) {
				spriteItem.loop = true;
				_mapLoops.set(id, new Sound());
			}
			
			if (_maxLength < spriteData.end) {
				_maxLength = spriteData.end;
			}
			
			_mapSprites.set(spriteItem.id, spriteItem);
			_sortedSprites.push( spriteItem );
		}
		
		
		_sortedSprites.sort( function(a:AudioSpriteItem, b:AudioSpriteItem):Int {
			return Std.int((a.start - b.start) * 1000);
		});
		
		for (sprite in _sortedSprites) {
			_sortedIDs.push( sprite.id );
		}
	}
	
	function prepareSoundLoops() {
		var loops = _mapLoops.keys();
		if (loops == null) return;
		
		if (_sound == null) {
			trace("Cannot prepare loops without sound.");
			return;
		}
		
		var goldenOffset:UInt = (64 << 5);
		var goldenDuration:UInt = (64 << 2);
		var sampleRate:UInt = 44100;
		
		for (id in loops) {
			var sprite:AudioSpriteItem = _mapSprites.get(id);
			var loop:Sound = _mapLoops.get(id);
			var sampleBytes = new ByteArray();
			var samplesTotal:UInt = cast(sprite.duration * sampleRate + goldenDuration);
			var samplesStart:UInt = cast(sprite.start * sampleRate + goldenOffset);
			sampleBytes.endian = Endian.BIG_ENDIAN;
			
			_sound.extract(sampleBytes, samplesTotal, samplesStart);
			sampleBytes.endian = Endian.BIG_ENDIAN;
			
			sampleBytes.position = 0;
			loop.loadPCMFromByteArray(sampleBytes, samplesTotal, "float", true);
		}
		
		checkIfSoundReady();
	}
	
	function checkIfSoundReady() {
		if (_sound==null) return false;
		
		_isReady = true;
		dispatchEvent(new Event(Event.COMPLETE));
		
		playQueuedSounds();
		
		return true;
	}
	
	function playQueuedSounds() 
	{
		if (_playQueue.length == 0) return;
		
		for (queuedID in _playQueue) {
			play(queuedID);
		}
		
		_playQueue = [];
	}
	
	public function play(id:String):Bool {
		if (!_isReady || _isStoppingAll) {
			_playQueue.push(id);
			return false;
		}
		
		trace("Playing: " + id);
		
		var sprite:AudioSpriteItem = _mapSprites.get(id);
		if (sprite == null) return false;
		
		var channel:SoundChannel;
		var sound = _sound;
		var now = Lib.getTimer() * 0.001;
		
		if (sprite.loop) {
			sound = _mapLoops.get(id);
			channel = sound.play( 0, 9999 );
		} else {
			channel = sound.play( sprite.start * 1000 );
		}
		
		var arrChannels = getChannelsForID(id);
		var audioChannel = new AudioSpriteChannel();
		
		audioChannel.channel = channel;
		audioChannel.sprite = sprite;
		audioChannel.startedAt = now;
		audioChannel.endAt = now + sprite.duration;
		arrChannels.push( audioChannel );
		_allChannels.push( audioChannel );
		
		return true;
	}
	
	inline function getChannelsForID(id:String) 
	{
		var arrChannels;
		if (!_mapChannels.exists(id)) {
			arrChannels = new ArrayChannels();
			_mapChannels.set(id, arrChannels);
		} else {
			arrChannels = _mapChannels.get(id);
		}
		return arrChannels;
	}
	
	public function stop(id:String) {
		if (_stoppedChannels.indexOf(id) > -1) return;
		_stoppedChannels.push(id);
	}
	
	public function stopAll() {
		_isStoppingAll = true;
	}
	
	public function getSprites():ArraySprites { return _sortedSprites; }
	public function getSoundIDs():Array<String> { return _sortedIDs; }
	public function getMaxLengthSeconds():Float { return _maxLength; }
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	private function onTimerCycles(e:TimerEvent):Void 
	{
		var channelsToRemove:ArrayChannels = [];
		var now = Lib.getTimer() * 0.001;
		var diff = now - _timeLast;
		var drift:Float = diff - _timerResolution;
		
		for (channel in _allChannels) {
			var sprite:AudioSpriteItem = channel.sprite;
			var isStopped = _isStoppingAll || _stoppedChannels.indexOf(sprite.id) > -1;
			if ((!sprite.loop && now >= channel.endAt) || isStopped) {
				channelsToRemove.push(channel);
			}
		}
		
		for (removed in channelsToRemove) {
			var arrChannels = _mapChannels.get(removed.sprite.id);
			arrChannels.remove( removed );
			_allChannels.remove( removed );
			removed.destroy();
		}
		
		if(_stoppedChannels.length>0) {
			_stoppedChannels = [];
		}
		
		_isStoppingAll = false;
		_timeLast = now;
		
		playQueuedSounds();
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public static function callLater(delay:Float, func:Dynamic, args:Array<Dynamic>=null) {
		var timer = new Timer(delay);
		timer.addEventListener(TimerEvent.TIMER, callLaterComplete);
		timer.start();
		
		_callLaters.set(timer, {func: func, args: args});
	}
	
	public static function callLaterComplete(e:Event) {
		var timer = e.target;
		if (!_callLaters.exists(timer)) return;
		timer.stop();
		var item = _callLaters.get(timer);
		_callLaters.remove(timer);
		item.func.apply(null, item.args);
		item.func = null;
		item.args = null;
	}
}

typedef VoidFunc = Void->Void;
typedef MapTimers = Map<Timer, CallLaterItem>;
typedef MapSound = Map<String, Sound>;
typedef ArrayChannels = Array<AudioSpriteChannel>;
typedef ArraySprites = Array<AudioSpriteItem>;
typedef MapItems = Map<String, AudioSpriteItem>;
typedef MapChannels = Map<String, ArrayChannels>;
typedef SpriteData = {
	start:Float,
	end:Float,
	loop:Bool
}
typedef CallLaterItem = {
	func:Dynamic,
	args:Array<Dynamic>
}

private class AudioSpriteItem {
	public var id:String;
	public var start:Float;
	public var duration:Float;
	public var loop:Bool = false;
	
	public function new() {}
}

private class AudioSpriteChannel {
	public var sprite:AudioSpriteItem;
	public var channel:SoundChannel;
	public var startedAt:Float = 0;
	public var endAt:Float = 0;
	
	public function new() { }
	
	public function destroy() {
		if (channel == null) return;
		channel.stop();
		channel = null;
		sprite = null;
		trace("Sound destroyed.");
	}
}

class AudioNavigator {
	var _owner:AudioSprite;
	var _ids:Array<String>;
	var _currentIndex:Int = -1;
	var _currentID:String;
	
	public function new( owner:AudioSprite ) {
		_owner = owner;
		_ids = owner.getSoundIDs();
		trace(_currentIndex);
	}
	
	function playCurrentID() {
		_currentID = _ids[_currentIndex];
		_owner.play( _currentID );
	}
	
	public function playNext() {
		_currentIndex++;
		if (_currentIndex >= _ids.length) _currentIndex = 0;
		playCurrentID();
	}
	
	public function playPrev() {
		_currentIndex--;
		if (_currentIndex < 0) _currentIndex = _ids.length - 1;
		playCurrentID();
	}
}