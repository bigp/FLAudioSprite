# FLAudioSprite
An AudioSprite implementation for Flash, written in Haxe

Usage Demo
------------------
![enter image description here](https://raw.githubusercontent.com/bigp/FLAudioSprite/master/docs/demo_main.png "Usage &#40;Demo&#41;")

Todo
------
The project is still early in development and lacks quite a bit of features (and probably misses some details regarding the AudioSprite structure). So here's a list of things I'm planning to implement next:

 - **SoundTransform**: handle volume, pan, left & right channel distribution. Could be passed by channel, sound *ID*, or entire *AudioSprite* engine / *SoundMixer*.
 - **Events**: Setup events that can dispatch like the built-in Sound object does in Flash.
 - **Optionally Do/Don't Loop**: Even though the JSON file dictates which sounds are intended to loop, the developer could override it by passing the # of loops manually: `play(id:String, loop:Int)` 
 - **HTML5 Implementation**: Although there are existing JS libs that handles AudioSprites (HowlerJS, SoundJS, Zynga-Jukebox), it makes sense to create a JS version to keep the functionality consistent for cross-platform development.
 - **Fade-Ins & Fade-Outs**: Handle smooth audio fade-in/-out, cross-dissolve between sounds.
 - **Support Playrate (Fast/Slow)**: Change the speed of a sound (affects pitch & timing) using the `SAMPLE_DATA` event. Could be processed as a static (once-at-start) or dynamic (change-in-realtime) effect.

If you want to help, leave me a note on **Twitter [@_bigp](https://twitter.com/_bigp "@_bigp")** or here on **GitHub**!