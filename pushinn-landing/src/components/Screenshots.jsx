import React, { useState } from 'react';

const Screenshots = () => {
    const [activeIndex, setActiveIndex] = useState(0);

    const images = [
        {
            url: "/images/real_screenshot_1.png",
            title: "CRYSTAL PALACE FEED",
            desc: "Real-time spot updates and community posts from the heart of the scene.",
            isReal: true
        },
        {
            url: "/images/map_mockup.png",
            title: "NEURAL SPOT MAP",
            desc: "Interactive grid mapping with high-fidelity location tracking and spot details.",
            isReal: false
        },
        {
            url: "/images/battle_mockup.png",
            title: "BATTLE PROTOCOL",
            desc: "Synchronized video battles with decentralized community voting systems.",
            isReal: false
        }
    ];

    const next = () => setActiveIndex((prev) => (prev + 1) % images.length);
    const prev = () => setActiveIndex((prev) => (prev - 1 + images.length) % images.length);

    return (
        <section id="screenshots" className="py-24 relative overflow-hidden">
            {/* Decorative background elements */}
            <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-matrix-green to-transparent opacity-30"></div>

            <div className="container px-6 relative">
                <div className="flex flex-col md:flex-row justify-between items-end mb-16 gap-6">
                    <div className="text-left">
                        <h2 className="text-4xl md:text-5xl font-bold mb-4 tracking-tighter">SYSTEM_VISUALS</h2>
                        <p className="font-mono text-matrix-dark-green max-w-md">
                            High-fidelity interface snapshots from the Pushinn mobile core.
                        </p>
                    </div>
                    <div className="flex gap-4">
                        <button onClick={prev} className="w-12 h-12 glass flex items-center justify-center hover:bg-matrix-green hover:text-matrix-black transition-all">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="15 18 9 12 15 6"></polyline></svg>
                        </button>
                        <button onClick={next} className="w-12 h-12 glass flex items-center justify-center hover:bg-matrix-green hover:text-matrix-black transition-all">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
                        </button>
                    </div>
                </div>

                <div className="relative group">
                    <div className="glass p-2 md:p-4 rounded-2xl overflow-hidden shadow-2xl">
                        <div className="relative aspect-[9/19] md:aspect-video overflow-hidden rounded-xl bg-matrix-black">
                            {images.map((img, i) => (
                                <div
                                    key={i}
                                    className={`absolute inset-0 transition-all duration-1000 ease-in-out ${i === activeIndex ? 'opacity-100 translate-x-0 scale-100' : 'opacity-0 translate-x-20 scale-95 pointer-events-none'}`}
                                >
                                    <img
                                        src={img.url}
                                        alt={img.title}
                                        className={`w-full h-full ${img.isReal ? 'object-contain' : 'object-cover'} opacity-90`}
                                    />

                                    {/* Fake Data Overlay */}
                                    <div className="absolute top-4 right-4 flex flex-col gap-2">
                                        <div className="glass px-3 py-1 text-[10px] font-mono text-matrix-green animate-pulse">
                                            LIVE_STREAM: ACTIVE
                                        </div>
                                        <div className="glass px-3 py-1 text-[10px] font-mono text-white">
                                            LAT: 51.4225 | LON: -0.0666
                                        </div>
                                    </div>

                                    <div className="absolute bottom-0 left-0 w-full p-6 md:p-12 bg-gradient-to-t from-matrix-black via-matrix-black/60 to-transparent">
                                        <div className="flex items-center gap-3 mb-2">
                                            <div className="w-2 h-2 bg-matrix-green rounded-full shadow-matrix-glow animate-ping"></div>
                                            <h3 className="text-2xl md:text-4xl font-bold text-white tracking-tight">{img.title}</h3>
                                        </div>
                                        <p className="font-mono text-sm md:text-base text-matrix-green max-w-xl opacity-80">
                                            {img.desc}
                                        </p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Floating decorative elements */}
                    <div className="absolute -top-10 -left-10 w-40 h-40 border border-matrix-green opacity-10 rounded-full animate-pulse-glow -z-10"></div>
                    <div className="absolute -bottom-10 -right-10 w-60 h-60 border border-matrix-green opacity-5 rounded-full animate-pulse-glow -z-10"></div>
                </div>

                {/* Progress Indicators */}
                <div className="flex justify-center gap-3 mt-12">
                    {images.map((_, i) => (
                        <button
                            key={i}
                            onClick={() => setActiveIndex(i)}
                            className={`h-1.5 transition-all duration-500 rounded-full ${i === activeIndex ? 'w-16 bg-matrix-green shadow-matrix-glow' : 'w-4 bg-matrix-dark-green opacity-20'}`}
                        ></button>
                    ))}
                </div>
            </div>

            <style jsx>{`
        .aspect-[9/19] {
          aspect-ratio: 9 / 19;
        }
        @media (min-width: 768px) {
          .aspect-video { aspect-ratio: 16 / 9; }
        }
      `}</style>
        </section>
    );
};

export default Screenshots;
