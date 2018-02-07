// Sampling, Granulation, Recording, etc

s.boot.scope(2);

(	// get audio input with SoundIn, and slow-pan it through stereo output
//  channels start at 0 = (left input);
SynthDef("soundIn",{ arg in=0;
	Out.ar(0,
		Pan2.ar(SoundIn.ar(in),	// Pan2 mixes input between two adjacent outputs
			SinOsc.kr(0.2),		// use a sinewave to control pan pos
			0.5))
}).play;
)
// number of input and output channels depends on the sound hardware used and maximum numbers can be set in ServerOptions, for ex., to see hardware attached:

ServerOptions.devices   // see all attached sound hardware
s.options.numAudioBusChannels  // maximum number of input and output audio buses combined
s.options.numInputBusChannels  // see number of input bus channels
s.options.numOutputBusChannels   // see number of output bus channels

// to change these, you must stop the server first, then provide different numbers, then restart the server

s.quit;
s.options.numInputBusChannels_(16);
s.options.numOutputBusChannels_(16);
s.boot;
s.options.numOutputBusChannels

/* Buffers are blocks of memory on the Server that are used for sample playback and manipulation, for streaming files off disk, for recording, making wavetables and FFT processing. The server defaults to having 1024 individual buffers, and more can be  allocated as needed from the operating system.
Buffers can be single or multichannel, but you must match channel numbers correctly to UGens that play them, otherwise you will hear nothing (without an error message!) */

s.options.numBuffers;    // current number of Buffers
s.options.numBuffers_(2048);  // set a new one (but must stop and restart s

//allocate a one channel buffer of 441000 sample frames (10 sec at standard sampling rate)

// execute these lines separately -- Buffer allocation takes a small but finite amount of time, so it wouldn't work properly if you executed them directly as a single block!  When you need to do that, you must use a 'completionMessage', which can be a Function that executes only after the Buffer has been allocated.

b=Buffer.alloc(s, 10*44100, 1);  // s= server, 10 seconds *44100 sample-rate frames, 1 = 1 channel, i.e. mono

b.bufnum 	// Each Buffer has a bufnum, but it is rarely used

b.free  //when finished with it, restore that memory and free its bufnum for reuse

// PlayBuf is the standard way to play back a sound from a Buffer.  You need to tell SClang the precise pathname of your sound.  For example:

File.exists(Platform.resourceDir +/+"sounds/a11wlk01.wav");  // this loads into a buffer the default sound that comes with SuperCollider

// if it is true, then go ahead and load it, otherwise it cannot load!  If you have trouble and and you're on a Mac, drag the file's icon onto the editor window, and you'll see it's correct pathname:

"/Sounds/birds/baltimore_oriole.wav"

// For all usages of a Buffer , you must ensure that the number of channels of the soundfile matches exactly the number of channels of the Buffer --  Buffer Ugens will fail silently (without warnings) if there is no match!!

(
// Buffer.read brings in the whole sound at once --
// Platform.resourceDir should find the "/sounds" directory on your machine!
b = Buffer.read(s,Platform.resourceDir +/+ "sounds/a11wlk01.wav");
)
b.plot;   // will display the waveform, AFTER the file is loaded, or do it this way:

Buffer.read(s,Platform.resourceDir +/+ "sounds/a11wlk01.wav",action: {|buf| { buf.plot }.defer });  // { }.defer is required here because buf.plot creates graphic interface, and in SC, graphics is lower priority and can only be executed with an AppClock, rather than the high priority SystemClock that an action function uses as its default-- it sounds complicated, but it's important to know this for any application which requires a time-critical response, like for example a MIDI note or controller message functioning as a trigger

// here is a simple SynthDef that plays a buffer, with adjustable rate, start position and optional looping
(
SynthDef("playbuf",{ arg out=0,buffer,rate=1,trigger=1,startPos=0,loop=1;
	Out.ar(out,
		Pan2.ar(
			PlayBuf.ar(1,buffer, BufRateScale.kr(buffer)*rate,trigger,
				BufFrames.ir(buffer)*startPos, loop),0.0)
	)
}).add;
)

// BufRateScale adjusts for different possible sampling rates,  because the default soundfile is actually at 11025Hz sampling rate, and my audio output is at 44100Hz. The BufFrames UGen returns the number of frames in the soundfile. But note the .ir - this is initialisation rate, i.e. it only runs BufFrames once when the synth is created, and it doesn't need to be continually recalculated.

// play it with default args
Synth(\playbuf, [\out, 0, \buffer, b]);  // use cmd+period to stop it

 //play at half rate
Synth(\playbuf, [\out, 0, \buffer, b, \rate, 0.5]);

/* BufRd is similar to PlayBuf but lets you directly read from a buffer using a phase argument,  allowing you to directly change the read point in the file.  This is more convenient for taking custom control of how you read through a sample, for example, using MouseX to scrub through the source file.  (You could also use this to read non-soundfiles)   */

(  //
SynthDef("scratchMe",{ arg buffer;
	Out.ar(0,
		Pan2.ar(BufRd.ar(1, buffer,
			K2A.ar(BufFrames.ir(buffer)  // this is the phase argument
				*MouseX.kr(0.0,1.0)).lag(MouseY.kr(0.0,1.0))),
		0.0)	// center pan
	)
}).add;
)
Synth(\scratchMe,[\buffer,b]);

/*  The K2A is needed to convert control rate Mouse to run at audio rate, because the BufRd needs to know where it is reading for every sample.

.lag (which is a shortcut to get a Lag UGen) smooths the transition to a new value by using 'catch-up delay' (amount controlled by MouseY).

[BufRd] //the help file has more examples
*/

// To stream a large file continuously from disc, use DiskIn.  A small Buffer is needed to smooth out data which arrives in bursts from the disc. Replace the filename here with one that is valid for your machine

(
//Prepare to stream-
b=Buffer.cueSoundFile(s,"/Sounds/world/nadhaswaram_ens_close.wav",0, 1);
)
// args are \numChannels, and \bufnum, and numChannels must match the channels in the Buffer
SynthDef(\diskin,{Out.ar(0,DiskIn.ar(1, b.bufnum ))}).play(s);

// You can only play back, you can't modulate the streaming rate in any way. But this allows you to bring in files for any processing you like.  Note also that the number of channels of the soundfile must match those in the Buffer, and the DiskIn argument

[DiskIn] // see its help file

(	// define a sampler
SynthDef("sampler",{ arg sampbuf=0,rate=1,startPos=0,trg=0,loop=1.0;
	var out;
	out = PlayBuf.ar(1,	 // numChannels, change this if Buffer is stereo or ??
		sampbuf,		//  bufnum to play
		BufRateScale.kr(sampbuf)*rate,   // gets sampRate for this Buffer
		trg,		// a trigger ( changing from 0 (or less) to positive) causes a jump to startPos
		startPos*BufFrames.kr(sampbuf),  // startPos, in sampleFrames of Buffer
		loop);			// 1 means loop, 0 means no loop
	Out.ar(0,out)
}).add;
)

b = Buffer.read(s,"/Sounds/birds/baltimore_oriole.wav");
x = Synth(\sampler,[\sampbuf,b]);
x.set(\rate,exprand(0.125,8).postln);   // random choice with exponential curve
(
x.set(\startPos,rand(1.0));
x.set(\trg,1);   // set trigger, but it has to be reset before it can be triggered again
SystemClock.sched(0.01, { x.set(\trg,0)});  // try compiling this at the same time to reset trg 0.01 sec later
)

// this sampler allows you to set its loop endPos too
(
SynthDef("loopSampler",{ arg sampbuf=0, rate=1, startPos=0, endPos=1.0, loop=1;
	var thisRate, thisDur, loopFrq;
	thisRate = BufRateScale.kr(sampbuf)*rate;  // BufRateScale converts  differences in sampleRates from soundfiles and your playback rate
	thisDur = ((endPos-startPos).abs*BufDur.kr(sampbuf)); // BufDur gets the duration of the Buffer, 'abs' method gets absolute value, to convert negative results to positive durations
	loopFrq = (thisDur.reciprocal).min(100);  // frequency of looping is the reciprocal of the loop duration -- also guard against infinite frequency using 'min' -- this returns the smaller of the reciprocal or its argument (100)
	Out.ar(0,
		PlayBuf.ar(1,			// numChannels
			sampbuf,				// which bufnum to play
			thisRate,   			// rate
			Impulse.kr(loopFrq*loop),	// Impulse Ugen retriggers sample
			startPos*BufFrames.kr(sampbuf),  // startPos*BufFrames gets the starting position sample number
			loop)
		)
}).add;
)

//  play the loopSampler
(
	var buf, filename;
	filename = "/Sounds/latin/las mulatas";  // choose your own soundfile
	b = Buffer.read(s,filename);	// read the file into a Buffer
	x = Synth("loopSampler",
		["sampbuf",b,"startPos",0.3,"endPos",0.5]);
)
x.set("startPos",0.3);
x.set("endPos",0.8);
x.set("rate",-1.0);	// note that negative rate, plays backwards
x.set("rate",1.0);

// the first time the sampler plays, it sometimes plays from the start of the sample -- why?  because the sample hasn't loaded yet, so there is no accurate count of the number of frames in the Buffer -- so, it is usually better to load your samples first, before starting any Synths that play them -- alternatively, you can use the 'action' argument of Buffer.read to start the Synth after reading is complete -- see the help-file for Buffer to see explanation, and here is an implemented version:

(
	var filename;
	filename = "/Sounds/latin/las mulatas";
	Buffer.read(s,filename,	// read the file into a Buffer
	action: { arg buf;	// new Buffer  passed to action function after loading
		x = Synth(\loopSampler,
		[\sampbuf,buf.postln.bufnum,\startPos,0.15,\endPos,0.25]);
		}
	);
)

// create another Buffer to record Audio input -- note that it's assigned to environmental variable 'b', so that we can continue to reference it in the next compilations

b = Buffer.alloc(s,s.sampleRate*4.0,1); // a 4 second, 1 channel Buffer

( // record into it
SynthDef("recSoundIn",{ arg bufnum=0, in=0;
	RecordBuf.ar(SoundIn.ar(in),bufnum, loop:1) // record over and over
	// RecordBuf.ar(SoundIn.ar(in),bufnum, loop:0)  // or just once!
}).play(s,[\bufnum,b.bufnum]);
)

// then play it
x = Synth("loopSampler",["sampbuf",b.bufnum]);

// make loopSampler into an Ndef for GUI controls
// let's first load a list of samples
(
~samps = ["/Sounds/world/veena.wav","/Sounds/world/algerian ney","/Sounds/world/rakha"];
// 'collect' stores the buffers created into a list
~buffers = ~samps.collect {|file| Buffer.read(s,file) } ;
)
(
Spec.specs.add(\sampbuf->ControlSpec(~buffers.first.bufnum,~buffers.last.bufnum,step:1));
Spec.specs.add(\rate->[0.1,10.0,\exp,0,1].asSpec);
Spec.specs.add(\startPos->[0.0,1.0,\lin,0,0].asSpec);
Spec.specs.add(\endPos->[0.0,1.0,\lin,0,1].asSpec);
Spec.specs.add(\loop->[0,1,\lin,1,1].asSpec);

Ndef(\loopSampler,{ arg sampbuf=0,rate=1, startPos=0, endPos=1.0, loop=1;
	var thisRate, thisDur, loopFrq;
	thisRate = BufRateScale.kr(sampbuf)*rate;
	thisDur = ((endPos-startPos).abs*BufDur.kr(sampbuf));
	loopFrq = (thisDur.reciprocal).min(100);
	PlayBuf.ar(1,sampbuf,thisRate, Impulse.kr(loopFrq*loop),
			startPos*BufFrames.kr(sampbuf),loop)
});
Ndef(\loopSampler).gui
)

( // here are some generic GUI Controls for loopSampler --this example omits shortcuts to show the basic design process that gives you more exact control over widget placement
var myWind;
myWind =  Window.new("sampler"); // create a window
// you can position it by providing a "bounds" arg, in the form or a Rect (rectangle), like this: Rect.new(leftPos, topPos, width, height) -- all argument numbers are in pixels
myWind.front;	//  display it
x = Synth("loopSampler",["sampbuf",~buffers[2]]);  // start playing
// create a slider, with dimensions relative to myWind given by Rect
Slider(myWind,Rect(120,20,40,200)).value_(0.5)
.action = { arg slider; // give it an action to do when moved
	x.set("rate",\rate.asSpec.map(slider.value))
};
// make a text label for the slider
StaticText(myWind,Rect(120,230,40,20)).string_(" rate");
Slider(myWind,Rect(180,20,40,200)).value_(0)
.action = { arg slider;
	x.set("startPos",slider.value)
};
StaticText(myWind,Rect(180,230,40,20)).string_(" start");
Slider(myWind,Rect(240,20,40,200)).value_(1)
.action = { arg slider;
	x.set("endPos",slider.value)
};
StaticText(myWind,Rect(240,230,40,20)).string_(" end");
myWind.onClose_({ x.free });
)

// The next example is a granular sampler, which uses another envelope for each loop that will get rid of the click at the beginning and end of the loop
(
Ndef(\granSampler,{ arg rate=1,startPos=0,endPos=1,sampbuf=0,pan=0, amp=0.1, gate=1;
	var dir, thisRate, grainDur,clk,env,gateEnvGen,sampler,looplength=1,
	chngTrg,minGrainDur=0.005;
	// synth env
	gateEnvGen = EnvGen.kr(Env.asr(attackTime: 0.0125, releaseTime: 0.0125),
		gate: gate, doneAction: 2);
	// compute looplength,grainDur,clk
	looplength=(endPos-startPos).abs;
	thisRate = (BufRateScale.kr(sampbuf)*rate);
	chngTrg = Mix(Changed.kr([looplength,thisRate])); // trg on change of length
	grainDur = (looplength*BufDur.kr(sampbuf)*(rate.reciprocal)).max(minGrainDur);
	clk = Impulse.kr(grainDur.reciprocal);  // trigger grain env
	// update loop startPos and endPos before every loop, and also if looplength changes
	#startPos,endPos = Demand.kr(clk+chngTrg,0,[startPos,endPos]);
	dir = (endPos-startPos).sign;
	dir = (dir.abs>0).if(dir,1);   // if endPos-startPos == 0, then dir = 1 (not 0)
	thisRate = thisRate*dir;
	// loop env
	env = EnvGen.ar(Env.new([0,1,1,0],
		[minGrainDur*0.5,grainDur-minGrainDur,minGrainDur*0.5],
		\welch),clk+chngTrg);  // also triggers if loop-length changes
	sampler = PlayBuf.ar(1,sampbuf,thisRate,clk,startPos*BufFrames.kr(sampbuf),1)*env*amp;
});
Ndef(\granSampler).gui
)
(
SynthDef(\granSampler,{ arg rate=1,startPos=0,endPos=1,sampbuf=0,pan=0, amp=0.1, gate=1;
	var dir, thisRate, grainDur,clk,env,gateEnvGen,sampler,looplength=1,
	chngTrg,minGrainDur=0.005;
	// synth env
	gateEnvGen = EnvGen.kr(Env.asr(attackTime: 0.0125, releaseTime: 0.0125),
		gate: gate, doneAction: 2);
	// compute looplength,grainDur,clk
	looplength=(endPos-startPos).abs;
	thisRate = (BufRateScale.kr(sampbuf)*rate);
	chngTrg = Mix(Changed.kr([looplength,thisRate])); // trg on change of length
	grainDur = (looplength*BufDur.kr(sampbuf)*(rate.reciprocal)).max(minGrainDur);
	clk = Impulse.kr(grainDur.reciprocal);  // trigger grain env
	// update loop startPos and endPos before every loop, and also if looplength changes
	#startPos,endPos = Demand.kr(clk+chngTrg,0,[startPos,endPos]);
	dir = (endPos-startPos).sign;
	dir = (dir.abs>0).if(dir,1);   // if endPos-startPos == 0, then dir = 1 (not 0)
	thisRate = thisRate*dir;
	// loop env
	env = EnvGen.ar(Env.new([0,1,1,0],
		[minGrainDur*0.5,grainDur-minGrainDur,minGrainDur*0.5],
		\welch),clk+chngTrg);  // also triggers if loop-length changes
	sampler = PlayBuf.ar(1,sampbuf,thisRate,clk,startPos*BufFrames.kr(sampbuf),1)*env;
	Out.ar(0,Pan2.ar(sampler,pan,amp))
}).add
)
x = Synth("granSampler",[\sampbuf, ~buffers[0], \startPos,0.2,\endPos,0.4]);
x.set(\endPos,0.5);

// Here is another granular SynthDefs that uses the UGen 'TGrains', which creates the grain window for you -- When the grain window is small and moving regularly to scan through the Buffer we can do  pitch-shifting in which the playback of the sound material in the window can be at any rate while the scanning of the window is at another, with the result that the Buffer's sound may be played at any pitch while its duration the same as its original one, or at any other ... i.e. pitch and duration are independent
(  // it uses these additional arguments
Spec.specs.add(\gfrq->[0.2,20.0,\exp,0,1].asSpec);
Spec.specs.add(\gdur->[0.01,2.0,\exp,0,1].asSpec);
Spec.specs.add(\fMod->[0,1,\lin,0,0].asSpec);
Spec.specs.add(\mfrqF->[0.05,2.0,\exp,0,1].asSpec);
Spec.specs.add(\mfrqD->[0.05,5.0,\exp,0,1].asSpec);
Spec.specs.add(\dMod->[0,1,\lin,0,0].asSpec);
Spec.specs[\dMod]
)
(
Ndef(\tGrainScan,{ arg rate=1,startPos=0s,endPos=1,spd=1,gdur=0.2,gfrq=10,fMod=0,mfrqF=1,
	dMod=0,mfrqD=1,sampbuf=0,pan=0,amp=0.1,gate=1;
	var thisPos,thisRate,thisDur,gateEnvGen, granulator,bufDur,scanSpd,sign;
	gateEnvGen = EnvGen.kr(Env.asr(attackTime: 0.01, releaseTime: 0.01),gate,
		levelScale: 1,doneAction: 2 );
	bufDur = BufDur.kr(sampbuf);
	thisDur = (endPos*bufDur)-(startPos*bufDur); // is signed, or can be 0
	sign = thisDur.sign;
	sign = (sign >= 0) + (sign*(sign<0));
	scanSpd = spd*((thisDur.abs.max(0.01)).reciprocal);
	thisPos = LFSaw.kr(scanSpd,1,0.5,0.5)*thisDur;
	gfrq = SinOsc.kr(mfrqF,0,fMod*gfrq,gfrq); // modulate grain freq
	gdur = SinOsc.kr(mfrqD,0,dMod*gdur,gdur); // modulate density (duration of grain)
	granulator = TGrains.ar(1,Impulse.kr(gfrq),sampbuf,
		rate*sign,
		(startPos*bufDur)+thisPos+(gdur*0.5),  // buffer centerPos in secs
		gdur,0,amp,4);
	Pan2.ar(granulator,pan)
});
)
Ndef(\tGrainScan).gui;
(
SynthDef(\tGrainScan,{ arg rate=1,startPos=0s,endPos=1,spd=1,gdur=0.2,gfrq=10,fMod=0,mfrqF=1,
	dMod=0,mfrqD=1,sampbuf=0,pan=0,amp=0.1,gate=1;
	var thisPos,thisRate,thisDur,gateEnvGen, granulator,bufDur,scanSpd,sign;
	gateEnvGen = EnvGen.kr(Env.asr(attackTime: 0.01, releaseTime: 0.01),gate,
		levelScale: 1,doneAction: 2 );
	bufDur = BufDur.kr(sampbuf);
	thisDur = (endPos*bufDur)-(startPos*bufDur); // is signed, or can be 0
	sign = thisDur.sign;
	sign = (sign >= 0) + (sign*(sign<0));
	scanSpd = spd*((thisDur.abs.max(0.01)).reciprocal);
	thisPos = LFSaw.kr(scanSpd,1,0.5,0.5)*thisDur;
	gfrq = SinOsc.kr(mfrqF,0,fMod*gfrq,gfrq); // modulate grain freq
	gdur = SinOsc.kr(mfrqD,0,dMod*gdur,gdur); // modulate density (duration of grain)
	granulator = TGrains.ar(1,Impulse.kr(gfrq),sampbuf,
		rate*sign,
		(startPos*bufDur)+thisPos+(gdur*0.5),  // buffer centerPos in secs
		gdur,0,amp,4);
	Out.ar(0,Pan2.ar(granulator,pan))
}).add
)

x = Synth("tGrainScan",[\sampbuf, ~buffers[0], \startPos,0.2,\endPos,0.4]);
x.set(\endPos,0.1);   // plays backwards
x.release   // release sends \gate = 0, which releases the Envelope, for a gradual turning off of the voice

// This next SynthDef plays just a single grain of sound before deallocating itself using an EnvGen with doneAction: 2.
(
SynthDef("grain",{ arg sampbuf=0,rate=1.0,startPos=0, size=0.1;
	Out.ar(0,
		Pan2.ar(
			PlayBuf.ar(1,sampbuf,
				rate*BufRateScale.kr(sampbuf),1,
				startPos*BufSamples.kr(sampbuf),1)
			*EnvGen.kr(
				Env([0,0.2,0],[size,size],\sine), // a sinusoidal envelope, duration = 2* size
				doneAction: 2),
			0)	// pan position
	);
}).add;
)
x = Synth("grain",["sampbuf",~buffers[0],"startPos",1.0.rand,"size",0.2]);

// Now we make a GUI to control a Routine that automatically plays grains with different argument values.  This GUI will use a convenience class called EZSlider that easily links a Slider with a number readout of its value and a label.  It also includes a ControlSpec, that automatically scales the slider's range and sets other useful characteristics like its default value, step resolution, and "warp", which allows for non-linear scaling of graphical controls.

// EZSlider(window, dimensions, label, controlSpec, action, initVal, initAction, labelWidth, numberWidth)

//	ControlSpec.new( minval, maxval, warp, step, default,units);

(	// play the grain sampler from a gui - try moving the start slider slowly through its range -- you will hear a granular scan through the soundfile

var myWind,rate=1.0,startPos=0,size=1,density=1,speed=8;
myWind = Window.new("grain scanner", 350@200);
myWind.front;  // you must do this, or no display!
//	 a FlowLayout allows automated placement of GUI objects in a window
myWind.view.decorator = FlowLayout(myWind.view.bounds);
EZSlider(myWind,300 @ 20,"rate",[0.25,4.0,\exp,0,1.0].asSpec,
	{ arg slider; rate = slider.value },1.0,numberWidth:40);
myWind.view.decorator.nextLine;
EZSlider(myWind,300 @ 20,"start",[0.0,1.0,\lin,0,0.0].asSpec,
	{ arg slider; startPos = slider.value },0.0,numberWidth:40);
myWind.view.decorator.nextLine;
EZSlider(myWind,300 @ 20,"size",[0.01,1.0,\exp,0.01,0.1].asSpec,
	{ arg slider; size = slider.value },0.1,numberWidth:40);
myWind.view.decorator.nextLine;
EZSlider(myWind,300 @ 20,"grainSpd",[1,60,\exp,0,12].asSpec,
	{ arg slider; speed = slider.value },12,numberWidth:40);
myWind.onClose_({ ~rout.stop });

// a Routine is a function that can pause (or wait), then resume
~rout = Routine({
	loop({
		Synth("grain",[\sampbuf, ~buffers[2],
			\rate,rate,\startPos,startPos,
			\size,size*density]);
		(speed.reciprocal).max(0.01).wait;  // make sure that this is never zero, or nil!
		});
}).play;
)
// in the above code, a new Synth is created with every loop, and each Synth is deallocated after its amplitude envelope completes

// Write a Pdef that creates a cloud of Synth.grains, with changing rate, speed, and size
(
Pdef(\granCloud,
	Pbind(\instrument,\grain,
		\sampbuf,~buffers[2],
		\rate,Pwhite(0.5,2.0),
		\startPos,Pn(Pseries(0,40.reciprocal,40)),
		\size,Pbrown(0.01,1,0.05),
		\dur,Pstutter(10,Pseq(((1..20)*0.01).mirror2,inf))
));
)
Pdef(\granCloud).play
Pdef(\granCloud).stop


// RECORDING SC music:

// recordings are automatically stored here:
thisProcess.platform.recordingsDir  // compile this to see where the file will turn up - you can also give it to your own pathname, using .recordingsDir_("path")

(  // set up the file format, otherwise, you'll get a floating-point file because SuperCollider output defaults to "float"  -- a recording in float format cannot be opened in many commercial sound editors, although the freeware "Audacity" will open it; but to record your output in 16bit format, first execute:

(
s.recSampleFormat_("int16");  // or "int24" -- "float" is default
)
( // to save in "wav" format
s.recHeaderFormat_("wav");  // or "aiff" is the default
)
// select "Start Recording from the Server menu...
(
s.prepareForRecord; // if not in SC3.7+, you have to compile this first before recording
)

 // start recording
s.record;  // if not starting from Server Menu

// play your sounds!!
{ SinOsc.ar }.play

// stop recording
s.stopRecording  // in SC 3.7+ stop from the Server menu, or if you use command-period, your recording will stop at the same time as the sounds do, but abruptly



