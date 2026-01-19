import { LightningElement, api } from 'lwc';

export default class ConfettiEffect extends LightningElement {
    canvas;
    ctx;
    particles = [];
    animationId;
    isActive = false;

    connectedCallback() {
        // Will initialize when fired
    }

    disconnectedCallback() {
        this.stopAnimation();
    }

    renderedCallback() {
        if (!this.canvas) {
            this.canvas = this.template.querySelector('canvas');
            this.ctx = this.canvas.getContext('2d');
            this.resizeCanvas();
            // Listen for resize
            window.addEventListener('resize', this.handleResize);
        }
    }

    handleResize = () => {
        this.resizeCanvas();
    }

    resizeCanvas() {
        if (this.canvas) {
            this.canvas.width = window.innerWidth;
            this.canvas.height = window.innerHeight;
        }
    }

    @api
    fire() {
        if (this.isActive) return;
        this.isActive = true;
        this.createParticles();
        this.animate();
        
        // Auto-stop after 3 seconds
        setTimeout(() => {
            this.stopAnimation();
        }, 3000);
    }

    stopAnimation() {
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }
        if (this.ctx && this.canvas) {
            this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        }
        this.particles = [];
        this.isActive = false;
    }

    createParticles() {
        if (!this.canvas) return;
        
        const colors = ['#f44336', '#e91e63', '#9c27b0', '#673ab7', '#3f51b5', '#2196f3', '#03a9f4', '#00bcd4', '#009688', '#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107', '#FF9800', '#FF5722'];
        
        for (let i = 0; i < 200; i++) {
            this.particles.push({
                x: this.canvas.width * 0.5,
                y: this.canvas.height * 0.5,
                vx: (Math.random() - 0.5) * 20,
                vy: (Math.random() - 0.5) * 20 - 5, // Upward bias
                size: Math.random() * 8 + 4,
                color: colors[Math.floor(Math.random() * colors.length)],
                rotation: Math.random() * 360,
                rotationSpeed: (Math.random() - 0.5) * 10,
                gravity: 0.1 + Math.random() * 0.2, // Random gravity
                drag: 0.96 // Air resistance
            });
        }
    }

    animate = () => {
        if (!this.isActive || !this.ctx || !this.canvas) return;

        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        let activeParticles = 0;

        this.particles.forEach(p => {
            p.x += p.vx;
            p.y += p.vy;
            p.vy += p.gravity;
            p.vx *= p.drag;
            p.vy *= p.drag;
            p.rotation += p.rotationSpeed;

            // Draw confetti
            this.ctx.save();
            this.ctx.translate(p.x, p.y);
            this.ctx.rotate((p.rotation * Math.PI) / 180);
            this.ctx.fillStyle = p.color;
            this.ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.6);
            this.ctx.restore();

            // Check bounds
            if (p.x >= 0 && p.x <= this.canvas.width && p.y <= this.canvas.height + 20) {
                activeParticles++;
            }
        });

        if (activeParticles > 0) {
            this.animationId = requestAnimationFrame(this.animate);
        } else {
            this.stopAnimation(); // All particles off screen
        }
    }
}