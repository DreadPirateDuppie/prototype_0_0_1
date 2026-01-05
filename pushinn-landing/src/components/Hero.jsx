import React from 'react';

const Hero = () => {
    return (
        <section className="min-h-screen flex flex-col justify-center items-center text-center relative overflow-hidden pt-20">
            <div className="animate-fade-in max-w-5xl px-6 relative z-10">
                <div className="mb-8 inline-block">
                    <div className="flex items-center gap-3 glass px-4 py-2 rounded-full border-matrix-green/30">
                        <div className="w-2 h-2 bg-matrix-green rounded-full animate-ping"></div>
                        <span className="font-mono text-[10px] md:text-xs tracking-[0.3em] text-matrix-green">
                            PROTOCOL_VERSION: 1.0.4_BETA
                        </span>
                    </div>
                </div>

                <h1 className="text-6xl md:text-9xl font-black mb-8 leading-[0.9] tracking-tighter group">
                    <span className="block text-white hover:text-matrix-green transition-colors duration-500 cursor-default">PUSHINN</span>
                    <span className="block text-matrix-green relative">
                        NETWORK
                        <span className="absolute -inset-1 bg-matrix-green/20 blur-2xl -z-10 group-hover:opacity-100 opacity-0 transition-opacity"></span>
                    </span>
                </h1>

                <p className="text-lg md:text-2xl text-matrix-dark-green mb-12 font-mono max-w-3xl mx-auto leading-relaxed">
                    The decentralized social layer for skateboarding. <br className="hidden md:block" />
                    Map spots. Battle peers. Earn reputation.
                </p>

                <div className="flex flex-col sm:flex-row gap-6 justify-center items-center">
                    <a href="#signup" className="group relative px-10 py-5 bg-matrix-green text-matrix-black font-bold text-xl overflow-hidden transition-all hover:scale-105 active:scale-95">
                        <span className="relative z-10">INITIALIZE_BETA</span>
                        <div className="absolute inset-0 bg-white translate-y-full group-hover:translate-y-0 transition-transform duration-300"></div>
                    </a>
                    <a href="#features" className="px-10 py-5 border-2 border-matrix-green text-matrix-green font-bold text-xl hover:bg-matrix-green/10 transition-all hover:shadow-matrix-glow">
                        VIEW_PROTOCOL
                    </a>
                </div>
            </div>

            {/* Decorative side text */}
            <div className="hidden lg:block absolute left-10 top-1/2 -translate-y-1/2 font-mono text-[10px] text-matrix-dark-green vertical-text tracking-[0.5em] opacity-30">
                ESTABLISHING_CONNECTION... [OK]
            </div>
            <div className="hidden lg:block absolute right-10 top-1/2 -translate-y-1/2 font-mono text-[10px] text-matrix-dark-green vertical-text tracking-[0.5em] opacity-30">
                ENCRYPTING_DATA_STREAM... [OK]
            </div>

            <div className="absolute bottom-10 left-1/2 -translate-x-1/2 animate-bounce text-matrix-green opacity-30">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M7 13l5 5 5-5M7 6l5 5 5-5" /></svg>
            </div>

            <style jsx>{`
        .vertical-text {
          writing-mode: vertical-rl;
          text-orientation: mixed;
        }
        h1 {
          font-size: clamp(3.5rem, 15vw, 10rem);
        }
      `}</style>
        </section>
    );
};

export default Hero;
