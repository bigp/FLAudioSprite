package;

import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.TimerEvent;
import flash.Lib;
import flash.utils.ByteArray;
import flash.utils.Timer;
import flaudiosprite.AudioSprite;
import flash.media.Sound;
import flaudiosprite.AudioSprite.callLater;

/**
 * ...
 * @author Pierre Chamberlain
 */

class Main 
{
	static function main() 
	{
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		
		var jsonData = new ExampleJSON();
		var jsonStr = jsonData.readUTFBytes(jsonData.length);
		var mp3Data = new ExampleMP3();
		var mp3Sound = new Sound();
		mp3Sound.loadCompressedDataFromByteArray( mp3Data, mp3Data.length );
		
		
		var as = new AudioSprite();
		as.loadFromDataAndSound(jsonStr, mp3Sound);
		
		as.play("trackloop");
		callLater(2000, function() { as.play("Wobble"); });
		callLater(4000, function() { as.play("Laser_Shoot2"); });
		callLater(4200, function() { as.play("Laser_Shoot3"); });
		callLater(4400, function() { as.play("Laser_Shoot1"); });
	}
	
}

@:file("bin/examples/example.mp3")
class ExampleMP3 extends ByteArray {}

@:file("bin/examples/example.json")
class ExampleJSON extends ByteArray {}
