package;

import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.MouseEvent;
import flash.Lib;
import flash.utils.ByteArray;
import flaudiosprite.AudioSprite;

/**
 * Demo usage of AudioSprite class.
 * @author Pierre Chamberlain
 */

class Main 
{
	static private var audspr:AudioSprite;
	
	static function main() 
	{
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		stage.addEventListener(MouseEvent.CLICK, onClick);
		
		audspr = new AudioSprite();
		audspr.loadFromEmbedded(ExampleJSON, ExampleMP3);
		audspr.play("Wobble");
		
		//callLater(2000, function() { as.play("trackloop"); } );
		//callLater(3000, function() { as.stopAll(); } );
		//callLater(3200, function() { as.play("trackloop2"); } );
	}
	
	static private function onClick(e:MouseEvent):Void  {
		audspr.stopAll();
		audspr.navigator.playNext();
	}
}

@:file("bin/examples/example.mp3")
class ExampleMP3 extends ByteArray {}

@:file("bin/examples/example.json")
class ExampleJSON extends ByteArray {}
