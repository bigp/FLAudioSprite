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
import flash.utils.JSON;
import flash.utils.Timer;
import flash.net.URLStream;
//import flaudiosprite.AudioSprite.ArrayChannels;


typedef VoidFunc = Void->Void;
typedef MapTimers = Map<Timer, CallLaterItem>;

typedef ArrayChannels = Array<AudioSpriteChannel>;
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

/**
 * ...
 * @author Pierre Chamberlain
 */
class AudioSprite extends EventDispatcher
{
	static var _callLaters:MapTimers;
	
	var _mapSprites:MapItems;
	var _mapChannels:MapChannels;
	var _allChannels:ArrayChannels;
	var _stoppedChannels:Array<String>;
	var _sound:Sound;
	var _stream:URLStream;
	var _isReady = false;
	var _isStoppingAll = false;
	var _playQueue:Array<String>;
	var _timer:Timer;
	var _timerResolution:Int = 10;
	var _timeLast:Float = 0;
	var _timeElapsed:Float = 0;
	
	public function new() {
		super();
		if (_callLaters == null) {
			_callLaters = new MapTimers();
		}
		
		_mapSprites = new MapItems();
		_mapChannels = new MapChannels();
		_allChannels = new ArrayChannels();
		_playQueue = [];
		_stoppedChannels = [];
	}
	
	public function setTimerResolution(value:Int) {
		_timerResolution = value;
	}
	
	public function load(url:String, alternateSound:Sound=null) {
		trace("Not implemented yet: " + url);
	}
	
	public function loadFromDataAndSound( jsonData:String, sound:Sound = null ) {
		_sound = sound;
		if (_sound != null) {
			trace("Sound resource is supplied, will override JSON data.");
		}
		parseJSON( jsonData );
		
		checkIfSoundReady();
	}
	
	function checkIfSoundReady() {
		if (_sound==null) return false;
		
		_isReady = true;
		dispatchEvent(new Event(Event.COMPLETE));
		
		if (_playQueue.length > 0) {
			playQueuedSounds();
		}
		
		_timeLast = Lib.getTimer();
		_timer = new Timer(_timerResolution);
		_timer.addEventListener(TimerEvent.TIMER, onTimerCycles);
		_timer.start();
		
		return true;
	}
	
	function playQueuedSounds() 
	{
		for (queuedID in _playQueue) {
			play(queuedID);
		}
	}
	
	function parseJSON(jsonData:String) {
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
		for (a in Reflect.fields(sprites)) {
			var spriteData:SpriteData = Reflect.field(sprites, a);
			var spriteItem = new AudioSpriteItem();
			spriteItem.id = a;
			spriteItem.startTime = spriteData.start * 1000;
			spriteItem.duration = (spriteData.end - spriteData.start) * 1000;
			
			if (spriteData.loop == true) {
				spriteItem.loop = true;
			}
			
			_mapSprites.set(spriteItem.id, spriteItem);
		}
	}
	
	function loadExternalSound(soundURL:String) {
		_stream = new URLStream();
		_stream.addEventListener(Event.COMPLETE, onExternalSoundComplete);
		_stream.load( new URLRequest(soundURL) );
	}
	
	private function onExternalSoundComplete(e:Event) {
		trace("Sound Loaded Externally.");
		var ba = new ByteArray();
		_stream.readBytes(ba);
		
		_sound = new Sound();
		_sound.loadCompressedDataFromByteArray(ba, ba.length);
		_stream.close();
		_stream = null;
		
		checkIfSoundReady();
	}
	
	public function play(id:String, offsetAdjustment:Float=0):Bool {
		if (!_isReady) {
			_playQueue.push(id);
			return false;
		}
		
		var now = Lib.getTimer();
		var sprite:AudioSpriteItem = _mapSprites.get(id);
		var channel = _sound.play( sprite.startTime + offsetAdjustment);
		
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
	
	private function onTimerCycles(e:TimerEvent):Void 
	{
		var now = Lib.getTimer();
		var diff = now - _timeLast;
		_timeElapsed += diff;
		
		var channelsToRemove:ArrayChannels = [];
		for (channel in _allChannels) {
			var sprite:AudioSpriteItem = channel.sprite;
			var isStopped = _isStoppingAll || _stoppedChannels.indexOf(sprite.id)>-1;
			if (_timeElapsed >= channel.endAt|| isStopped) {
				channelsToRemove.push(channel);
			}
			
			if (!isStopped && sprite.loop) {
				var offset = 0;
				play(sprite.id, offset);
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
	}
	
	////////////////////////////////////
	
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

private class AudioSpriteItem {
	public var id:String;
	public var startTime:Float;
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