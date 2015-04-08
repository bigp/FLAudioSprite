package;

import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;
import flash.events.MouseEvent;
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
	static private var as:flaudiosprite.AudioSprite;
	
	static function main() 
	{
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		
		as = new AudioSprite();
		as.loadFromEmbedded(ExampleJSON, ExampleMP3);
		as.play("Wobble");
		callLater(1000, function() { as.play("trackloop"); } );
		
		stage.addEventListener(MouseEvent.CLICK, onClick);
	}
	
	
	static private function onClick(e:MouseEvent):Void 
	{
		as.stopAll();
	}
}

@:file("bin/examples/example.mp3")

class ExampleMP3 extends ByteArray {}

@:file("bin/examples/example.json")
class ExampleJSON extends ByteArray {}
