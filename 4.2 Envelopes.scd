//	ENVELOPES
/*	Env.new(levels, times, curves, releaseNode, loopNode)
	levels - an array of levels. The first level is the initial value of the envelope.
	times - an array of durations of segments in seconds. There should be
	one fewer duration than there are levels.
	curve - this parameter determines the shape of the envelope segments.
	releaseNode - an Integer or nil. If not nil, the envelope will sustain at the releaseNode until released.
	loopNode - an Integer or nil. If not nil the sustain portion will loop from the releaseNode to the loop node.
*/
Env.new([0.25,0.5,0.0],[1.0,0.5],'linear',nil,nil).plot;  // plot in a GUI window
// levels of an 'exponential' Env must all be non-zero!!
Env.new([0.25,0.5,0.1],[1.0,0.5],'exponential',nil,nil).plot;
// sinusoidal curve
Env.new([0.25,0.5,0.0],[1.0,0.5],'sine',nil,nil).plot;
// the slope of curves can be specified by numbers
Env.new([0.25,0.5,0.0],[1.0,0.5],[4,1],nil,nil).plot;
Env.new([0.25,0.5,0.0],[1.0,0.5],[4,-1],nil,nil).plot;
Env.new([0.25,0.5,0.0],[1.0,0.5],[-4,1],nil,nil).plot;

/* ENVELOPE GENERATOR: EnvGen
EnvGen.ar(envelope, gate, levelScale, levelBias, timeScale, doneAction)
doneAction -
	 the doneAction arg allows you to make the EnvGen end the
	 Synth it is part of.  The most common doneActions are:
	doneAction = 0   do nothing when the envelope has ended.
 	doneAction = 1   pause the synth running, it is still resident.
 	doneAction = 2   remove the synth and deallocate it.
*/

// make an envelope and use it in an EnvGen that multiplies the output of a SinOsc,  controlling its amplitude
(
SynthDef(\envTest,{ arg out=0;
	var env;
	env = Env.new([0.0,0.5,0.0],[1.0,0.5],'linear',nil,nil);
	Out.ar(out,
		SinOsc.ar(800,0,
		// note "keyword" style of supplying the doneAction arg --  args can be specified in any order, identified by 'name:'
			EnvGen.kr(env, doneAction: 2)))   // env controls amplitude
}).play;
)


(// two envelopes, one for amplitude, one for frequency
SynthDef("twoEnvs",{ arg out=0;
	var ampEnv, freqEnv, sig;
	ampEnv = Env.new([0.0,0.5,0.0],[1.0,0.5],'linear');
	// try changing the curves of freqEnv
	freqEnv = Env.new([200,600,400],[1.0,0.5],[4,1]);
	sig = SinOsc.ar(EnvGen.kr(freqEnv),
						0,EnvGen.kr(ampEnv, doneAction: 2));
	Out.ar(out,sig)
}).play
)

// two voices, each with both amplitude and frequency
//		 envelopes - the envelopes are stored in arrays
// this is a model for the instrument in the assignment
(
SynthDef("duet",{ arg out;
	var ampEnvelopes, freqEnvelopes;
	ampEnvelopes =
		[
			Env.new([0.0,0.5,0.0],[1.0,0.5],'linear'),
			Env.new([0.0,0.5,0.0],[0.5,1.0],'linear')
		];
	freqEnvelopes =
		[
			Env.new([200,600,400],[1.0,0.5],[4,1]),
			Env.new([300,602,200],[0.5,1.0],[4,1])
		];
	Out.ar(out,
		SinOsc.ar(EnvGen.kr(freqEnvelopes.at(0)),
				0,EnvGen.kr(ampEnvelopes.at(0),doneAction: 2))
		+				// mixing the two oscillators
  		SinOsc.ar(EnvGen.kr(freqEnvelopes.at(1)),
  				0,EnvGen.kr(ampEnvelopes.at(1),doneAction: 2)))
 }).play
)

( // same, but stereo, instead of mixed  --
SynthDef("duet",{ arg out;
	var ampEnvelopes, freqEnvelopes;
	ampEnvelopes =
		[
			Env.new([0.0,0.5,0.0],[1.0,0.5],'linear'),
			Env.new([0.0,0.5,0.0],[0.5,1.0],'linear')
		];
	freqEnvelopes =
		[
			Env.new([200,600,400],[1.0,0.5],[4,1]),
			Env.new([300,602,200],[0.5,1.0],[4,1])
		];
	Out.ar(out,
		// two oscillators in an Array
		[ SinOsc.ar(EnvGen.kr(freqEnvelopes.at(0)),0,
			EnvGen.kr(ampEnvelopes.at(0), doneAction: 2)),
		 SinOsc.ar(EnvGen.kr(freqEnvelopes.at(1)),0,
			EnvGen.kr(ampEnvelopes.at(1), doneAction: 2))]
  		)
 }).play
)

(// other convenient envelope creation methods
SynthDef("envTests",{ arg out=0;
	var env;
	//	*perc(attackTime, releaseTime, peakLevel, curve)
	//	env = Env.perc(0.0,0.35,0.5,-1);
	//	*triangle(duration, level)
	//	env = Env.triangle(1.0,0.8);
	//	*linen(attackTime, sustainTime, releaseTime, sustainLevel)
		env = Env.linen(0.1,2.5,1.5,0.5);
	Out.ar(out,
		SinOsc.ar(500,0,EnvGen.kr(env,doneAction: 2)))
}).play
)

/* the Env methods 'adsr' and 'asr' create envelopes with
 sustain segments,which stay at the sustain level
	until explicitly released by the Synth that plays it:

	*adsr(attackTime, decayTime, sustainLevel,
							releaseTime, peakLevel, curve)
	*asr(attackTime, sustainLevel,  releaseTime, peakLevel, curve)

	to control the release, the Synth must have an arg called 'gate'
	which is on (value=1) when the Synth starts */
(
a = SynthDef("susEnvTests",{ arg out=0, gate=1;
	var env;
	env = Env.adsr(0.1, 0.2, 0.25, 0.8, 1, -4);
	Out.ar(out,
		// the 'gate' arg controls the EnvGen release
		SinOsc.ar(500,0,EnvGen.kr(env,gate,doneAction: 2)))
}).play;
)
// the method 'release' will set the 'gate' arg to 0, initiating the
// release time segment
a.release;

//	EnvGen's 'gate' can be modulated to retrigger an Env
(	// create a repeating note,
//	using a pulse wave to gate and release EnvGen
a = SynthDef("repTest",{ arg out=0;
	var env, sig, speed, gate;  // this 'gate' is a variable, so it can't be used to release the Synth
	// *adsr(attackTime, decayTime, sustainLevel,  releaseTime, peakLevel, curve)
	env = Env.adsr(0.05, 0.2, 0.25, 0.25, 1, -4);
	// MouseX-position controls gate speed
	// LFPulse.ar(freq, iphase,width, mul, add)
	gate = LFPulse.ar(MouseX.kr(0.2, 20, 'exponential'),0,
	// MouseY controls pulse-width of gate
		MouseY.kr(0.01,0.99));	//
	sig = SinOsc.ar(300, 0, EnvGen.kr(env,gate));
	Out.ar(out,sig)
}).play;
)
a.free;
// now, add use of levelScale and timeScale args to change the
// loudness and time of the same envelope as it plays
(
SynthDef("repTest",{ arg out=0;
	var env, gate, sig, speed;
	env = Env.adsr(0.05, 0.2, 0.25, 0.25, 1, -4);
	// MouseX-position controls gate speed
	speed = MouseX.kr(0.2, 20, 'exponential');
	gate = LFPulse.kr(speed,0,0.5);
	sig = SinOsc.ar(300, 0,
		EnvGen.kr(env,gate,
				levelScale: MouseY.kr(0,1),
				timeScale: speed.reciprocal));
	Out.ar(out,sig)
}).play;
)

