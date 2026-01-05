import React, { useState, useEffect } from 'react';

const TerminalHero = () => {
    const [bootLines, setBootLines] = useState([]);
    const [showHero, setShowHero] = useState(false);

    const lines = [
        "> INITIALIZING PUSHINN_CORE...",
        "> LOADING NEURAL_MAP_DATA...",
        "> ESTABLISHING PEER_CONNECTION...",
        "> DECRYPTING PROTOCOL_V1.0.4...",
        "> SYSTEM_READY: ACCESS_GRANTED"
    ];

    useEffect(() => {
        let currentLine = 0;
        const interval = setInterval(() => {
            if (currentLine < lines.length) {
                setBootLines(prev => [...prev, lines[currentLine]]);
                currentLine++;
            } else {
                clearInterval(interval);
                setTimeout(() => setShowHero(true), 500);
            }
        }, 4000); // Slower for "WOW" effect
        return () => clearInterval(interval);
    }, []);

    return (
        <section className="min-h-screen flex flex-col justify-center items-center px-6 relative">
            {!showHero ? (
                <div className="font-mono text-matrix-green text-sm md:text-base space-y-2 max-w-xl w-full">
                    {bootLines.map((line, i) => (
                        <div key={i} className="animate-fade-in">{line}</div>
                    ))}
                    <div className="w-2 h-5 bg-matrix-green animate-pulse inline-block ml-1"></div>
                </div>
            ) : (
                <div className="animate-fade-in text-center max-w-5xl">
                    <div className="mb-12">
                        <h1 className="text-7xl md:text-[12rem] font-black leading-none tracking-tighter text-white group cursor-default">
                            PUSH<span className="text-matrix-green">INN</span>
                        </h1>
                        <div className="flex items-center justify-center gap-4 mt-4">
                            <div className="h-px w-20 bg-matrix-green/30"></div>
                            <span className="font-mono text-xs tracking-[0.8em] text-matrix-green uppercase">The Social Layer</span>
                            <div className="h-px w-20 bg-matrix-green/30"></div>
                        </div>
                    </div>

                    <p className="text-xl md:text-3xl font-mono text-matrix-dark-green mb-16 max-w-3xl mx-auto leading-relaxed">
                        Decentralized skateboarding. <br />
                        Map spots, battle peers, own the streets.
                    </p>

                    <div className="flex flex-col sm:flex-row gap-8 justify-center">
                        <a href="#access" className="glass px-12 py-6 text-xl font-bold text-matrix-green hover:bg-matrix-green hover:text-matrix-black transition-all shadow-matrix-glow group">
                            [ REQUEST_ACCESS ]
                        </a>
                        <a href="#protocol" className="px-12 py-6 text-xl font-bold text-matrix-dark-green hover:text-white transition-all">
                            VIEW_PROTOCOL_DATA
                        </a>
                    </div>
                </div>
            )}
        </section>
    );
};

export default TerminalHero;
