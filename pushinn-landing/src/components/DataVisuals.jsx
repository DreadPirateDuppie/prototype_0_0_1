import React, { useState } from 'react';

const DataVisuals = () => {
    const [activeIndex, setActiveIndex] = useState(0);

    const streams = [
        {
            url: "/images/real_screenshot_1.png",
            title: "FEED_STREAM_01",
            meta: "LOC: CRYSTAL_PALACE // STATUS: LIVE"
        },
        {
            url: "/images/map_mockup.png",
            title: "MAP_STREAM_02",
            meta: "GRID: 51.4225, -0.0666 // ZOOM: 14.5"
        },
        {
            url: "/images/battle_mockup.png",
            title: "BATTLE_STREAM_03",
            meta: "PEERS: 2 // VOTES: 1,420 // ROUND: 04"
        }
    ];

    return (
        <section id="visuals" className="py-32 relative overflow-hidden">
            <div className="container px-6">
                <div className="flex flex-col items-center text-center mb-20">
                    <div className="font-mono text-xs text-matrix-green tracking-[0.5em] mb-4 opacity-40">INTERCEPTED_DATA_STREAMS</div>
                    <h2 className="text-4xl md:text-6xl font-black tracking-tight">VISUAL_INTEL</h2>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
                    {/* Stream Info */}
                    <div className="lg:col-span-4 space-y-12">
                        {streams.map((stream, i) => (
                            <div
                                key={i}
                                className={`transition-all duration-500 cursor-pointer group ${i === activeIndex ? 'opacity-100 translate-x-4' : 'opacity-20 hover:opacity-50'}`}
                                onClick={() => setActiveIndex(i)}
                            >
                                <div className="font-mono text-xs text-matrix-green mb-2">{stream.title}</div>
                                <div className="font-mono text-[10px] text-matrix-dark-green tracking-widest">{stream.meta}</div>
                                <div className={`h-1 bg-matrix-green mt-4 transition-all duration-500 ${i === activeIndex ? 'w-full shadow-matrix-glow' : 'w-0'}`}></div>
                            </div>
                        ))}
                    </div>

                    {/* Stream Display */}
                    <div className="lg:col-span-8 relative group">
                        <div className="glass p-2 md:p-4 rounded-2xl overflow-hidden shadow-2xl relative">
                            <div className="absolute inset-0 bg-matrix-green/5 animate-pulse pointer-events-none z-10"></div>
                            <div className="relative aspect-video overflow-hidden rounded-xl bg-matrix-black">
                                {streams.map((stream, i) => (
                                    <img
                                        key={i}
                                        src={stream.url}
                                        alt={stream.title}
                                        className={`absolute inset-0 w-full h-full object-contain transition-all duration-1000 ease-in-out ${i === activeIndex ? 'opacity-100 scale-100' : 'opacity-0 scale-110 pointer-events-none'}`}
                                    />
                                ))}
                            </div>

                            {/* HUD Overlays */}
                            <div className="absolute top-8 left-8 font-mono text-[10px] text-matrix-green z-20 bg-matrix-black/80 px-2 py-1">
                                REC_STREAM_ACTIVE
                            </div>
                            <div className="absolute bottom-8 right-8 font-mono text-[10px] text-matrix-green z-20 bg-matrix-black/80 px-2 py-1">
                                BITRATE: 4.2MBPS
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
};

export default DataVisuals;
