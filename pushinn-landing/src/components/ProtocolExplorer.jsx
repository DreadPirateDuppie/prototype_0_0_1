import React, { useState } from 'react';

const ProtocolExplorer = () => {
    const [activeNode, setActiveNode] = useState(0);

    const nodes = [
        {
            id: "01",
            title: "NEURAL_MAPPING",
            desc: "Proprietary spot discovery algorithm. Real-time node sharing with encrypted location data.",
            stats: { nodes: "1,420", uptime: "99.9%", latency: "14ms" }
        },
        {
            id: "02",
            title: "BATTLE_LOGIC",
            desc: "Asynchronous Game of SKATE protocol. Decentralized community verification and ranking.",
            stats: { matches: "8,240", votes: "45k+", avg_win: "62%" }
        },
        {
            id: "03",
            title: "DATA_STREAM",
            description: "High-bandwidth media sharing. Follow the global network and sync with your local crew.",
            stats: { bandwidth: "4.2TB/s", clips: "120k", peers: "5.2k" }
        }
    ];

    return (
        <section id="protocol" className="py-32 relative">
            <div className="container px-6">
                <div className="flex flex-col lg:flex-row gap-16 items-start">
                    {/* Node Selection */}
                    <div className="w-full lg:w-1/3 space-y-4">
                        <div className="font-mono text-[10px] text-matrix-green tracking-[0.5em] mb-8 opacity-40">SELECT_PROTOCOL_NODE</div>
                        {nodes.map((node, i) => (
                            <button
                                key={i}
                                onClick={() => setActiveNode(i)}
                                className={`w-full text-left p-6 glass transition-all duration-500 group relative overflow-hidden ${activeNode === i ? 'border-matrix-green bg-matrix-green/5' : 'opacity-40 hover:opacity-100'}`}
                            >
                                <div className="flex items-center justify-between">
                                    <span className="font-mono text-xs text-matrix-green">{node.id}</span>
                                    <h3 className="text-xl font-bold tracking-tight">{node.title}</h3>
                                </div>
                                {activeNode === i && (
                                    <div className="absolute bottom-0 left-0 h-1 bg-matrix-green shadow-matrix-glow animate-pulse w-full"></div>
                                )}
                            </button>
                        ))}
                    </div>

                    {/* Node Data Display */}
                    <div className="w-full lg:w-2/3 glass p-8 md:p-16 relative min-h-[400px] flex flex-col justify-center">
                        <div className="absolute top-0 right-0 p-4 font-mono text-[10px] text-matrix-green/20">NODE_STATUS: STABLE</div>

                        <div className="animate-fade-in" key={activeNode}>
                            <h2 className="text-4xl md:text-6xl font-black mb-8 text-white tracking-tighter">
                                {nodes[activeNode].title}
                            </h2>
                            <p className="text-xl font-mono text-matrix-dark-green mb-12 leading-relaxed max-w-2xl">
                                {nodes[activeNode].desc}
                            </p>

                            <div className="grid grid-cols-3 gap-8 pt-8 border-t border-matrix-green/10">
                                {Object.entries(nodes[activeNode].stats).map(([key, value]) => (
                                    <div key={key}>
                                        <div className="font-mono text-[10px] text-matrix-green opacity-40 uppercase mb-2">{key}</div>
                                        <div className="text-2xl font-bold text-matrix-green">{value}</div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
};

export default ProtocolExplorer;
