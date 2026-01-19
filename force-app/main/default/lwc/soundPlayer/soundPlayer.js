import { LightningElement, api } from 'lwc';

export default class SoundPlayer extends LightningElement {
    audioContext;

    @api
    playTone(type) {
        try {
            this.initAudioContext();
            
            switch (type) {
                case 'success':
                    this.playSuccessChime();
                    break;
                case 'alert':
                    this.playSoftAlert();
                    break;
                case 'reveal':
                    this.playRevealSound();
                    break;
                case 'timer':
                    this.playTimerEndSound();
                    break;
                case 'join':
                    this.playJoinSound();
                    break;
                default:
                    console.warn('Unknown tone type:', type);
            }
        } catch (error) {
            console.warn('Audio playback failed (interaction required?):', error);
        }
    }

    initAudioContext() {
        if (!this.audioContext) {
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        }
        if (this.audioContext.state === 'suspended') {
            this.audioContext.resume();
        }
    }

    // --- Sound Synthesis Methods ---

    playSuccessChime() {
        // Melodic ascending triad (C5 - E5 - G5)
        const now = this.audioContext.currentTime;
        this.playOscillator(523.25, now, 0.1, 'sine'); // C5
        this.playOscillator(659.25, now + 0.1, 0.1, 'sine'); // E5
        this.playOscillator(783.99, now + 0.2, 0.3, 'sine'); // G5
    }

    playSoftAlert() {
        // Soft double beep
        const now = this.audioContext.currentTime;
        this.playOscillator(440, now, 0.15, 'sine');
        this.playOscillator(440, now + 0.2, 0.15, 'sine');
    }

    playRevealSound() {
        // Whoosh / Flip effect (filtered noise or rapid slide)
        // Simulating a "card flip" with a quick frequency sweep
        const now = this.audioContext.currentTime;
        const oscillator = this.audioContext.createOscillator();
        const gainNode = this.audioContext.createGain();
        
        oscillator.type = 'triangle';
        oscillator.frequency.setValueAtTime(400, now);
        oscillator.frequency.exponentialRampToValueAtTime(800, now + 0.1);
        
        gainNode.gain.setValueAtTime(0.1, now);
        gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.1);
        
        oscillator.connect(gainNode);
        gainNode.connect(this.audioContext.destination);
        
        oscillator.start(now);
        oscillator.stop(now + 0.15);
    }

    playTimerEndSound() {
        // Descending warning tone
        const now = this.audioContext.currentTime;
        this.playOscillator(880, now, 0.3, 'sine'); // A5
        this.playOscillator(440, now + 0.3, 0.5, 'sine'); // A4
    }

    playJoinSound() {
        // Little "pop"
        const now = this.audioContext.currentTime;
        this.playOscillator(600, now, 0.05, 'sine');
    }

    // Helper for simple tones
    playOscillator(freq, startTime, duration, type = 'sine') {
        const oscillator = this.audioContext.createOscillator();
        const gainNode = this.audioContext.createGain();

        oscillator.type = type;
        oscillator.frequency.setValueAtTime(freq, startTime);

        // Envelope: Attack (quick), Decay (smooth)
        gainNode.gain.setValueAtTime(0, startTime);
        gainNode.gain.linearRampToValueAtTime(0.1, startTime + 0.02);
        gainNode.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

        oscillator.connect(gainNode);
        gainNode.connect(this.audioContext.destination);

        oscillator.start(startTime);
        oscillator.stop(startTime + duration + 0.1);
    }
}