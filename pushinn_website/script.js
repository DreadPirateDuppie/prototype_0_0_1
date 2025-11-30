// Matrix Rain Effect
function createMatrixRain() {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    canvas.style.position = 'fixed';
    canvas.style.top = '0';
    canvas.style.left = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.zIndex = '-2';
    canvas.style.pointerEvents = 'none';

    document.getElementById('matrix-rain').appendChild(canvas);

    function resizeCanvas() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    const chars = 'PUSHINN_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()_+-=[]{}|;:,.<>?';
    const charArray = chars.split('');

    const fontSize = 14;
    const columns = canvas.width / fontSize;

    const drops = [];
    for (let i = 0; i < columns; i++) {
        drops[i] = 1;
    }

    function draw() {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        ctx.fillStyle = '#00FF41';
        ctx.font = fontSize + 'px JetBrains Mono';

        for (let i = 0; i < drops.length; i++) {
            const text = charArray[Math.floor(Math.random() * charArray.length)];
            ctx.fillText(text, i * fontSize, drops[i] * fontSize);

            if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
                drops[i] = 0;
            }
            drops[i]++;
        }
    }

    setInterval(draw, 35);
}

// Smooth Scrolling
function scrollToSection(sectionId) {
    const element = document.getElementById(sectionId);
    if (element) {
        const offsetTop = element.offsetTop - 80; // Account for fixed navbar
        window.scrollTo({
            top: offsetTop,
            behavior: 'smooth'
        });
    }
}

// Navbar Scroll Effect
function initNavbarScroll() {
    const navbar = document.querySelector('.navbar');
    let lastScrollTop = 0;

    window.addEventListener('scroll', () => {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;

        if (scrollTop > lastScrollTop && scrollTop > 100) {
            // Scrolling down
            navbar.style.transform = 'translateY(-100%)';
        } else {
            // Scrolling up
            navbar.style.transform = 'translateY(0)';
        }

        // Add background opacity based on scroll
        if (scrollTop > 50) {
            navbar.style.background = 'rgba(0, 0, 0, 0.98)';
        } else {
            navbar.style.background = 'rgba(0, 0, 0, 0.95)';
        }

        lastScrollTop = scrollTop <= 0 ? 0 : scrollTop;
    });
}

// Intersection Observer for animations
function initScrollAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('fade-in-up');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe elements for animation
    const elementsToAnimate = document.querySelectorAll(
        '.feature-card, .platform-card, .contact-card, .download-info, .about-text, .roadmap'
    );

    elementsToAnimate.forEach(el => {
        observer.observe(el);
    });
}

// Typewriter Effect for Hero Title
function initTypewriter() {
    const titleLines = document.querySelectorAll('.title-line');
    let lineIndex = 0;
    let charIndex = 0;
    let isDeleting = false;

    function typeWriter() {
        if (lineIndex >= titleLines.length) return;

        const currentLine = titleLines[lineIndex];
        const text = currentLine.textContent;

        if (isDeleting) {
            currentLine.textContent = text.substring(0, charIndex - 1);
            charIndex--;
        } else {
            currentLine.textContent = text.substring(0, charIndex + 1);
            charIndex++;
        }

        let typeSpeed = isDeleting ? 50 : 100;

        if (!isDeleting && charIndex === text.length) {
            typeSpeed = 2000; // Pause at end
            isDeleting = true;
        } else if (isDeleting && charIndex === 0) {
            isDeleting = false;
            lineIndex++;
            typeSpeed = 500;
        }

        setTimeout(typeWriter, typeSpeed);
    }

    // Start typewriter effect after a delay
    setTimeout(typeWriter, 1000);
}

// Active Nav Link Highlighting
function initActiveNavLink() {
    const sections = document.querySelectorAll('section[id]');
    const navLinks = document.querySelectorAll('.nav-link');

    window.addEventListener('scroll', () => {
        let current = '';

        sections.forEach(section => {
            const sectionTop = section.offsetTop - 100;
            const sectionHeight = section.clientHeight;

            if (window.pageYOffset >= sectionTop &&
                window.pageYOffset < sectionTop + sectionHeight) {
                current = section.getAttribute('id');
            }
        });

        navLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === '#' + current) {
                link.classList.add('active');
            }
        });
    });
}

// Button Click Effects
function initButtonEffects() {
    const buttons = document.querySelectorAll('.btn');

    buttons.forEach(button => {
        button.addEventListener('click', function (e) {
            // Create ripple effect
            const ripple = document.createElement('span');
            const rect = this.getBoundingClientRect();
            const size = Math.max(rect.width, rect.height);
            const x = e.clientX - rect.left - size / 2;
            const y = e.clientY - rect.top - size / 2;

            ripple.style.width = ripple.style.height = size + 'px';
            ripple.style.left = x + 'px';
            ripple.style.top = y + 'px';
            ripple.classList.add('ripple');

            this.appendChild(ripple);

            setTimeout(() => {
                ripple.remove();
            }, 600);
        });
    });
}

// Contact Actions
function openFeedback() {
    const email = 'feedback@pushinn.app';
    const subject = 'Pushinn Alpha Feedback';
    const body = 'Hello Pushinn Team,%0D%0A%0D%0AHere is my feedback on the alpha version:%0D%0A%0D%0A[Please describe your experience, suggestions, or concerns]%0D%0A%0D%0ABest regards,%0D%0A[Your name]';

    window.open(`mailto:${email}?subject=${subject}&body=${body}`, '_blank');
}

function reportBug() {
    const email = 'bugs@pushinn.app';
    const subject = 'Pushinn Alpha - Bug Report';
    const body = 'Hello Pushinn Team,%0D%0A%0D%0AI found a bug in the alpha version:%0D%0A%0D%0ADevice: [Your device]%0D%0AOS Version: [Your OS version]%0D%0AApp Version: Alpha%0D%0A%0D%0ABug Description:%0D%0A[Describe what happened]%0D%0A%0D%0ASteps to Reproduce:%0D%0A1. [Step 1]%0D%0A2. [Step 2]%0D%0A3. [Step 3]%0D%0A%0D%0AExpected Result:%0D%0A[What should happen]%0D%0A%0D%0AActual Result:%0D%0A[What actually happened]%0D%0A%0D%0AThanks!%0D%0A[Your name]';

    window.open(`mailto:${email}?subject=${subject}&body=${body}`, '_blank');
}

function joinCommunity() {
    const email = 'community@pushinn.app';
    const subject = 'Pushinn Alpha - Community Interest';
    const body = 'Hello Pushinn Team,%0D%0A%0D%0AI am interested in joining the Pushinn community and alpha testing.%0D%0A%0D%0AName: [Your name]%0D%0ASkate Experience: [Beginner/Intermediate/Advanced/Pro]%0D%0APreferred Contact: [Email]%0D%0A%0D%0ALooking forward to being part of the skate revolution!%0D%0A%0D%0ABest regards,%0D%0A[Your name]';

    window.open(`mailto:${email}?subject=${subject}&body=${body}`, '_blank');
}

// Download Actions
function downloadAPK() {
    // Placeholder for actual APK download
    alert('APK download will be available soon! Please check back later or contact us for early access.');

    // Track download attempt
    console.log('Download APK button clicked');
}

// Stats Counter Animation
function initStatsCounter() {
    const stats = document.querySelectorAll('.stat-number');

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateStat(entry.target);
                observer.unobserve(entry.target);
            }
        });
    });

    stats.forEach(stat => observer.observe(stat));
}

function animateStat(element) {
    const text = element.textContent;
    const number = parseInt(text.replace(/\D/g, '')) || 0;
    const suffix = text.replace(/[\d]/g, '');

    if (number === 0) return;

    let current = 0;
    const increment = number / 50;
    const timer = setInterval(() => {
        current += increment;
        if (current >= number) {
            element.textContent = text; // Restore original text
            clearInterval(timer);
        } else {
            element.textContent = Math.floor(current) + suffix;
        }
    }, 30);
}

// Keyboard Navigation
function initKeyboardNavigation() {
    document.addEventListener('keydown', (e) => {
        // Prevent default behavior for certain keys
        if (e.ctrlKey || e.metaKey || e.altKey) return;

        const sections = ['home', 'features', 'download', 'about', 'contact'];
        const currentSection = getCurrentSection();
        const currentIndex = sections.indexOf(currentSection);

        switch (e.key) {
            case 'ArrowDown':
            case 'PageDown':
                e.preventDefault();
                if (currentIndex < sections.length - 1) {
                    scrollToSection(sections[currentIndex + 1]);
                }
                break;

            case 'ArrowUp':
            case 'PageUp':
                e.preventDefault();
                if (currentIndex > 0) {
                    scrollToSection(sections[currentIndex - 1]);
                }
                break;

            case 'Home':
                e.preventDefault();
                scrollToSection('home');
                break;

            case 'End':
                e.preventDefault();
                scrollToSection('contact');
                break;
        }
    });
}

function getCurrentSection() {
    const sections = document.querySelectorAll('section[id]');
    const scrollPos = window.pageYOffset + 150;

    for (let section of sections) {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.offsetHeight;

        if (scrollPos >= sectionTop && scrollPos < sectionTop + sectionHeight) {
            return section.getAttribute('id');
        }
    }

    return 'home';
}

// Loading Screen
function initLoadingScreen() {
    window.addEventListener('load', () => {
        const loader = document.createElement('div');
        loader.id = 'page-loader';
        loader.innerHTML = `
            <div class="loader-content">
                <div class="loader-logo">
                    <img src="assets/pushinn_logo.png" alt="Pushinn" style="width: 80px; height: 80px; filter: brightness(0) invert(1) sepia(1) saturate(5) hue-rotate(90deg);">
                </div>
                <div class="loader-text">INITIALIZING...</div>
                <div class="loader-bar">
                    <div class="loader-progress"></div>
                </div>
            </div>
        `;

        loader.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: #000;
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
            transition: opacity 0.5s ease-out;
        `;

        document.body.appendChild(loader);

        // Simulate loading progress
        const progressBar = loader.querySelector('.loader-progress');
        let progress = 0;

        const progressTimer = setInterval(() => {
            progress += Math.random() * 15;
            if (progress >= 100) {
                progress = 100;
                clearInterval(progressTimer);

                setTimeout(() => {
                    loader.style.opacity = '0';
                    setTimeout(() => {
                        loader.remove();
                    }, 500);
                }, 500);
            }

            progressBar.style.width = progress + '%';
        }, 100);
    });
}

// Glitch Effect
function initGlitchEffect() {
    const glitchElements = document.querySelectorAll('.matrix-green');

    glitchElements.forEach(element => {
        element.addEventListener('mouseenter', () => {
            element.style.animation = 'none';
            element.offsetHeight; // Trigger reflow
            element.style.animation = 'glitch 0.3s ease-in-out';
        });
    });
}

// Custom cursor effect
function initCustomCursor() {
    const cursor = document.createElement('div');
    cursor.id = 'custom-cursor';
    cursor.style.cssText = `
        position: fixed;
        width: 20px;
        height: 20px;
        background: rgba(0, 255, 65, 0.5);
        border: 2px solid #00FF41;
        border-radius: 50%;
        pointer-events: none;
        z-index: 9999;
        transition: transform 0.1s ease;
        box-shadow: 0 0 10px rgba(0, 255, 65, 0.5);
    `;

    document.body.appendChild(cursor);

    document.addEventListener('mousemove', (e) => {
        cursor.style.left = e.clientX - 10 + 'px';
        cursor.style.top = e.clientY - 10 + 'px';
    });

    // Scale cursor on hover over interactive elements
    const interactiveElements = document.querySelectorAll('a, button, .btn');
    interactiveElements.forEach(el => {
        el.addEventListener('mouseenter', () => {
            cursor.style.transform = 'scale(1.5)';
        });

        el.addEventListener('mouseleave', () => {
            cursor.style.transform = 'scale(1)';
        });
    });
}

// Initialize all functions when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    createMatrixRain();
    initNavbarScroll();
    initScrollAnimations();
    initTypewriter();
    initActiveNavLink();
    initButtonEffects();
    initStatsCounter();
    initKeyboardNavigation();
    initGlitchEffect();

    // Add custom cursor for desktop only
    if (window.innerWidth > 768) {
        initCustomCursor();
    }

    // Handle window resize
    window.addEventListener('resize', () => {
        // Recreate matrix rain on resize
        const canvas = document.querySelector('#matrix-rain canvas');
        if (canvas) {
            canvas.remove();
            createMatrixRain();
        }
    });
});

// Handle download button click
document.addEventListener('DOMContentLoaded', () => {
    const downloadBtn = document.querySelector('.btn-download');
    if (downloadBtn) {
        downloadBtn.addEventListener('click', downloadAPK);
    }
});

// Add CSS for ripple effect
const style = document.createElement('style');
style.textContent = `
    .btn {
        position: relative;
        overflow: hidden;
    }
    
    .ripple {
        position: absolute;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.3);
        transform: scale(0);
        animation: ripple-animation 0.6s linear;
        pointer-events: none;
    }
    
    @keyframes ripple-animation {
        to {
            transform: scale(4);
            opacity: 0;
        }
    }
    
    .nav-link.active {
        color: var(--matrix-green) !important;
        text-shadow: 0 0 5px var(--glow-green);
    }
    
    .nav-link.active::after {
        width: 100% !important;
    }
    
    @keyframes glitch {
        0% { transform: translate(0); }
        20% { transform: translate(-2px, 2px); }
        40% { transform: translate(-2px, -2px); }
        60% { transform: translate(2px, 2px); }
        80% { transform: translate(2px, -2px); }
        100% { transform: translate(0); }
    }
    
    #page-loader .loader-content {
        text-align: center;
        color: var(--matrix-green);
        font-family: 'JetBrains Mono', monospace;
    }
    
    #page-loader .loader-logo {
        margin-bottom: 2rem;
        animation: logo-pulse 2s ease-in-out infinite;
    }
    
    #page-loader .loader-text {
        font-size: 1.2rem;
        letter-spacing: 3px;
        margin-bottom: 2rem;
        text-shadow: 0 0 10px var(--glow-green);
    }
    
    #page-loader .loader-bar {
        width: 300px;
        height: 4px;
        background: rgba(0, 255, 65, 0.2);
        border-radius: 2px;
        overflow: hidden;
        margin: 0 auto;
    }
    
    #page-loader .loader-progress {
        height: 100%;
        background: var(--matrix-green);
        box-shadow: 0 0 10px var(--glow-green);
        transition: width 0.3s ease;
    }
`;

document.head.appendChild(style);
