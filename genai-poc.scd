//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//This is a proof of concept about how interactions with LLMs can be used to edit sound producing code
//to create musical development.
//Our strategy will be to take an initial patch, prompt an LLM to understand how it functions, and then generate a contrasting section using it
//Then, we will prompt it to tie the movements together in a single sequence.
//The starting patch we will use can be found on the examples in SuperCollider's official documentation, called 60Hz Gabber Rave 1995
//The model used will be GPT 4o.

//This is the original patch:
(
SynthDef(\gabberkick, {
    var snd, freq, high, lfo;
    freq = \freq.kr(440) * (Env.perc(0.001, 0.08, curve: -1).ar * 48 * \bend.kr(1)).midiratio;
    snd = Saw.ar(freq);
    snd = (snd * 100).tanh + ((snd.sign - snd) * -8.dbamp);
    high = HPF.ar(snd, 300);
    lfo = SinOsc.ar(8, [0, 0.5pi]).range(0, 0.01);
    high = high.dup(2) + (DelayC.ar(high, 0.01, lfo) * -2.dbamp);
    snd = LPF.ar(snd, 100).dup(2) + high;
    snd = RLPF.ar(snd, 7000, 2);
    snd = BPeakEQ.ar(snd, \ffreq.kr(3000) * XLine.kr(1, 0.8, 0.3), 0.5, 15);
    snd = snd * Env.asr(0.001, 1, 0.05).ar(2, \gate.kr(1));
    Out.ar(\out.kr(0), snd * \amp.kr(0.1));
}).add;

SynthDef(\hoover, {
    var snd, freq, bw, delay, decay;
    freq = \freq.kr(440);
    freq = freq * Env([-5, 6, 0], [0.1, 1.7], [\lin, -4]).kr.midiratio;
    bw = 1.035;
    snd = { DelayN.ar(Saw.ar(freq * ExpRand(bw, 1 / bw)) + Saw.ar(freq * 0.5 * ExpRand(bw, 1 / bw)), 0.01, Rand(0, 0.01)) }.dup(20);
    snd = (Splay.ar(snd) * 3).atan;
    snd = snd * Env.asr(0.01, 1.0, 1.0).kr(0, \gate.kr(1));
    snd = FreeVerb2.ar(snd[0], snd[1], 0.3, 0.9);
    snd = snd * Env.asr(0, 1.0, 4, 6).kr(2, \gate.kr(1));
    Out.ar(\out.kr(0), snd * \amp.kr(0.1));
}).add;
)

(
var durations;
durations = [1, 1, 1, 1, 3/4, 1/4, 1/2, 3/4, 1/4, 1/2];
Ppar([
    Pbind(*[
        instrument: \gabberkick,
        amp: -23.dbamp,
        freq: 60,
        legato: 0.8,
        ffreq: Pseq((0..(durations.size * 4 - 1)).normalize, inf).linexp(0, 1, 100, 4000),
        dur: Pseq(durations, inf),
        bend: Pfuncn({ |x| if(x < (1/2), 0.4, 1) }, inf) <> Pkey(\dur),
    ]),
    Pbind(*[
        instrument: \hoover,
        amp: -20.dbamp,
        midinote: 74,
        dur: durations.sum * 2,
        sustain: 7,
    ])
]).play(TempoClock(210 / 60));
)

//////////////////////////////////////////////////////////////////////////////////////////////////
//First prompt: contextualizing model on how the patch works and what we want to do with it:
//P1: thoroughly explain this supercollider patch with special attention to points that can be changed so the music sounds different
//A1: (summary) the model explained the code line by line and suggested mutations. We will prompt for our own later on.

///////////////////////////////////////////////////////////////////////////
//Second prompt: we will attempt to generate a contrasting movement
//P2: using only new patterns and no new synthdefs, generate a new contrasting sequence that is much slower, expansive and ambient-like
//A2:
(
Ppar([
    // Ambient Gabberkick: sparse sub-bass pulses
    Pbind(
        \instrument, \gabberkick,
        \freq, 48,  // lower than original 60Hz
        \amp, -30.dbamp,
        \dur, Pseq([4, 6, 8], inf), // very slow spacing
        \legato, 1,
        \ffreq, Pseg(Pseq([200, 800, 150], inf), Pseq([20, 40], inf)),
        \bend, 0.2
    ),

    // Floating Hoover: long overlapping tones, drifting in and out
    Pbind(
        \instrument, \hoover,
        \midinote, Pwhite(60, 72, inf), // soft upper range
        \amp, Pseg(Pseq([0.08, 0.04, 0.06, 0.02], inf), 10),
        \dur, Pwhite(10, 20, inf),
        \sustain, Pkey(\dur) * 0.9
    )
]).play(TempoClock(40 / 60));  // much slower tempo
)

/////////////////////////////////////////////////////////////////////////////////////////////////////
//Third prompt: we must now try to alter the patch so that patterns can be played in succession
//P3: make it so when a pattern is played, all other patterns are silenced so that only one pattern plays at a time
//A3:

// Define a stop-all function
(
~stopAllPatterns = {
    [\partA, \partB].do { |key| Pdef(key).stop };
};
)

// Define first pattern (ambient hoover + sparse kick)
(
Pdef(\partA,
    Ppar([
        Pbind(
            \instrument, \gabberkick,
            \freq, 48,
            \amp, -30.dbamp,
            \dur, Pseq([4, 6, 8], inf),
            \legato, 1,
            \ffreq, Pseg(Pseq([200, 800, 150], inf), Pseq([20, 40], inf)),
            \bend, 0.2
        ),
        Pbind(
            \instrument, \hoover,
            \midinote, Pwhite(60, 72, inf),
            \amp, Pseg(Pseq([0.08, 0.04, 0.06, 0.02], inf), 10),
            \dur, Pwhite(10, 20, inf),
            \sustain, Pkey(\dur) * 0.9
        )
    ])
);
)

// Define second pattern (original gabber rave)
(
var durations = [1, 1, 1, 1, 3/4, 1/4, 1/2, 3/4, 1/4, 1/2];
Pdef(\partB,
    Ppar([
        Pbind(
            \instrument, \gabberkick,
            \amp, -23.dbamp,
            \freq, 60,
            \legato, 0.8,
            \ffreq, Pseq((0..(durations.size * 4 - 1)).normalize, inf).linexp(0, 1, 100, 4000),
            \dur, Pseq(durations, inf),
            \bend, Pfuncn({ |x| if(x < (1/2), 0.4, 1) }, inf) <> Pkey(\dur),
        ),
        Pbind(
            \instrument, \hoover,
            \amp, -20.dbamp,
            \midinote, 74,
            \dur, durations.sum * 2,
            \sustain, 7,
        )
    ])
);
)

~stopAllPatterns.();

// Controller to alternate patterns
(
Routine {
    loop {
        ~stopAllPatterns.();
        Pdef(\partA).play(TempoClock(40 / 60));
        (5).wait; // play ambient for 5 seconds

        ~stopAllPatterns.();
        Pdef(\partB).play(TempoClock(210 / 60));
        (5).wait; // play gabber for 5 seconds
    }
}.play;
)

///////////////////////////////////////////////////////////////////////
//Fourth prompt: creating a development arc
//P4: create a full ambient-gabber-ambient arc with fade transitions

// Create a control bus for amplitude fading
~fadeBus = Bus.control(s, 1);

// Amp controller Synth to apply fade-ins/outs
(
SynthDef(\ampControl, {
    Out.kr(\bus.kr(0), EnvGen.kr(Env.newClear(2), doneAction: 2))
}).add;
)

// Function to create fades
(
~fadeTo = { |targetAmp, time|
    Synth(\ampControl, [\bus, ~fadeBus, \fadeTime, time], target: s.defaultGroup).map(\fadeTime, targetAmp.linlin(0, 1, 0, 1)).run;
};
)

// Stop all patterns
(
~stopAll = {
    [\partAmbient, \partGabber].do { |key| Pdef(key).stop };
};
)

// Ambient pattern
(
Pdef(\partAmbient,
    Ppar([
        Pbind(
            \instrument, \gabberkick,
            \freq, 48,
            \amp, Pkey(\amp) * -30.dbamp.dbamp,
            \dur, Pseq([4, 6, 8], inf),
            \legato, 1,
            \ffreq, Pseg(Pseq([200, 800, 150], inf), Pseq([20, 40], inf)),
            \bend, 0.2,
            \amp, In.kr(~fadeBus)
        ),
        Pbind(
            \instrument, \hoover,
            \midinote, Pwhite(60, 72, inf),
            \dur, Pwhite(10, 20, inf),
            \sustain, Pkey(\dur) * 0.9,
            \amp, In.kr(~fadeBus)
        )
    ])
);
)

// Gabber pattern
(
var durations = [1, 1, 1, 1, 3/4, 1/4, 1/2, 3/4, 1/4, 1/2];
Pdef(\partGabber,
    Ppar([
        Pbind(
            \instrument, \gabberkick,
            \freq, 60,
            \amp, In.kr(~fadeBus),
            \legato, 0.8,
            \ffreq, Pseq((0..(durations.size * 4 - 1)).normalize, inf).linexp(0, 1, 100, 4000),
            \dur, Pseq(durations, inf),
            \bend, Pfuncn({ |x| if(x < (1/2), 0.4, 1) }, inf) <> Pkey(\dur)
        ),
        Pbind(
            \instrument, \hoover,
            \midinote, 74,
            \dur, durations.sum * 2,
            \sustain, 7,
            \amp, In.kr(~fadeBus)
        )
    ])
);
)

// Master routine to fade between sections
(
Routine {
    ~stopAll.();
    ~fadeBus.set(0);  // start silent
    Pdef(\partAmbient).play(TempoClock(40 / 60));
    ~fadeTo.(0.6, 10);  // fade in ambient
    10.wait;

    ~fadeTo.(0.0, 5);  // fade out ambient
    5.wait;
    ~stopAll.();

    Pdef(\partGabber).play(TempoClock(210 / 60));
    ~fadeTo.(0.7, 5);  // fade in gabber
    10.wait;

    ~fadeTo.(0.0, 5);  // fade out gabber
    5.wait;
    ~stopAll.();

    Pdef(\partAmbient).play(TempoClock(30 / 60));
    ~fadeTo.(0.5, 10);  // fade in ambient again
    10.wait;

    ~fadeTo.(0.0, 10); // final fade out
    5.wait;
    ~stopAll.();
}.play;
)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//This resulted in bad use of the preceding synthdefs and initiated iterations about fixing them so the new routines could be applied.
//Error fixing iterations were condensed into the following output with the final patch:

// SYNTH DEFINITIONS (with control via fadeBus)
(
SynthDef(\gabberkick, {
    var snd, freq, high, lfo;
    freq = \freq.kr(440) * (Env.perc(0.001, 0.08, curve: -1).ar * 48 * \bend.kr(1)).midiratio;
    snd = Saw.ar(freq);
    snd = (snd * 100).tanh + ((snd.sign - snd) * -8.dbamp);
    high = HPF.ar(snd, 300);
    lfo = SinOsc.ar(8, [0, 0.5pi]).range(0, 0.01);
    high = high.dup(2) + (DelayC.ar(high, 0.01, lfo) * -2.dbamp);
    snd = LPF.ar(snd, 100).dup(2) + high;
    snd = RLPF.ar(snd, 7000, 2);
    snd = BPeakEQ.ar(snd, \ffreq.kr(3000) * XLine.kr(1, 0.8, 0.3), 0.5, 15);
    snd = snd * Env.asr(0.001, 1, 0.05).ar(2, \gate.kr(1));
    Out.ar(\out.kr(0), snd * \amp.kr(0.1) * In.kr(\fadeBus.kr(0), 1));
}).add;

SynthDef(\hoover, {
    var snd, freq, bw;
    freq = \freq.kr(440);
    freq = freq * Env([-5, 6, 0], [0.1, 1.7], [\lin, -4]).kr.midiratio;
    bw = 1.035;
    snd = { DelayN.ar(Saw.ar(freq * ExpRand(bw, 1 / bw)) + Saw.ar(freq * 0.5 * ExpRand(bw, 1 / bw)), 0.01, Rand(0, 0.01)) }.dup(20);
    snd = (Splay.ar(snd) * 3).atan;
    snd = snd * Env.asr(0.01, 1.0, 1.0).kr(0, \gate.kr(1));
    snd = FreeVerb2.ar(snd[0], snd[1], 0.3, 0.9);
    snd = snd * Env.asr(0, 1.0, 4, 6).kr(2, \gate.kr(1));
    Out.ar(\out.kr(0), snd * \amp.kr(0.1) * In.kr(\fadeBus.kr(0), 1));
}).add;
)

// CREATE VOLUME BUS AND FADE FUNCTION
(
~fadeBus = Bus.control(s, 1);
~fadeBus.set(0);

SynthDef(\fadeEnv, {
    arg bus = 0, target = 1, time = 5;
    Out.kr(bus, Line.kr(In.kr(bus), target, time, doneAction: 2));
}).add;

~fadeTo = { |target, time = 5|
    Synth(\fadeEnv, [\bus, ~fadeBus, \target, target, \time, time]);
};
)

// PARAMETER TO STOP EVERYTHING
(
~stopAll = {
    [\partAmbient, \partGabber].do { |key| Pdef(key).stop };
};
)

// AMBIENT PATTERN
(
Pdef(\partAmbient,
    Ppar([
        Pbind(
            \instrument, \gabberkick,
            \freq, 48,
            \amp, 1.0,
            \fadeBus, ~fadeBus,
            \dur, Pseq([4, 6, 8], inf),
            \legato, 1,
            \ffreq, Pseg(Pseq([200, 800, 150], inf), Pseq([20, 40], inf)),
            \bend, 0.2
        ),
        Pbind(
            \instrument, \hoover,
            \midinote, Pwhite(60, 72, inf),
            \dur, Pwhite(10, 20, inf),
            \sustain, Pkey(\dur) * 0.9,
            \amp, 1.0,
            \fadeBus, ~fadeBus
        )
    ])
);
)

// GABBER PATTERN
(
var durations = [1, 1, 1, 1, 3/4, 1/4, 1/2, 3/4, 1/4, 1/2];
Pdef(\partGabber,
    Ppar([
        Pbind(
            \instrument, \gabberkick,
            \freq, 60,
            \amp, 1.0,
            \fadeBus, ~fadeBus,
            \legato, 0.8,
            \ffreq, Pseq((0..(durations.size * 4 - 1)).normalize, inf).linexp(0, 1, 100, 4000),
            \dur, Pseq(durations, inf),
            \bend, Pfuncn({ |x| if(x < (1/2), 0.4, 1) }, inf) <> Pkey(\dur)
        ),
        Pbind(
            \instrument, \hoover,
            \midinote, 74,
            \dur, durations.sum * 2,
            \sustain, 7,
            \amp, 1.0,
            \fadeBus, ~fadeBus
        )
    ])
);
)

// MAIN ROUTINE – SECTIONS WITH SMOOTH TRANSITIONS
(
Routine {
    ~stopAll.();
    ~fadeBus.set(0);

    // INITIAL AMBIENT
    Pdef(\partAmbient).play(TempoClock(40/60));
    ~fadeTo.(0.6, 10); 10.wait;

    // TRANSITION TO GABBER
    ~fadeTo.(0.0, 5); 5.wait;
    ~stopAll.();

    Pdef(\partGabber).play(TempoClock(210/60));
    ~fadeTo.(0.7, 5); 10.wait;

    // TRANSITION TO FINAL AMBIENT
    ~fadeTo.(0.0, 5); 5.wait;
    ~stopAll.();

    Pdef(\partAmbient).play(TempoClock(30/60));
    ~fadeTo.(0.5, 10); 10.wait;

    // ENDING
    ~fadeTo.(0.0, 10); 10.wait;
    ~stopAll.();
}.play;
)



