import React from 'react';

const FeatureCard = ({ icon, title, description, code }) => {
    return (
        <div className="glass p-8 transition-all duration-500 hover:-translate-y-3 group relative overflow-hidden">
            {/* Background Code Snippet */}
            <div className="absolute top-4 right-4 font-mono text-[8px] text-matrix-dark-green opacity-10 group-hover:opacity-30 transition-opacity select-none">
                {code}
            </div>

            <div className="text-matrix-green mb-8 p-4 glass w-fit rounded-xl group-hover:scale-110 group-hover:shadow-matrix-glow transition-all duration-500">
                {icon}
            </div>

            <h3 className="text-2xl font-bold mb-4 text-white group-hover:text-matrix-green transition-colors tracking-tight">
                {title}
            </h3>

            <p className="text-matrix-dark-green font-mono text-sm leading-relaxed mb-6">
                {description}
            </p>

            <div className="flex items-center gap-2 text-[10px] font-mono text-matrix-green opacity-0 group-hover:opacity-100 transition-all translate-y-2 group-hover:translate-y-0">
                <span>READ_MORE</span>
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
            </div>

            {/* Corner accents */}
            <div className="absolute top-0 left-0 w-2 h-2 border-t border-l border-matrix-green opacity-0 group-hover:opacity-100 transition-all"></div>
            <div className="absolute bottom-0 right-0 w-2 h-2 border-b border-r border-matrix-green opacity-0 group-hover:opacity-100 transition-all"></div>
        </div>
    );
};

const Features = () => {
    const features = [
        {
            title: "NEURAL_MAPPING",
            description: "Proprietary spot discovery algorithm. Real-time node sharing with encrypted location data.",
            code: "GET /api/v1/spots",
            icon: <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
        },
        {
            title: "BATTLE_LOGIC",
            description: "Asynchronous Game of SKATE protocol. Decentralized community verification and ranking.",
            code: "POST /api/v1/battle",
            icon: <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>
        },
        {
            title: "DATA_STREAM",
            description: "High-bandwidth media sharing. Follow the global network and sync with your local crew.",
            code: "WS /feed/live",
            icon: <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><rect x="2" y="2" width="20" height="20" rx="5" ry="5"></rect><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"></path></svg>
        },
        {
            title: "REPUTATION_XP",
            description: "Proof-of-trick consensus. Earn digital assets and unlock premium protocol features.",
            code: "PUT /user/xp",
            icon: <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="12" cy="8" r="7"></circle><polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"></polyline></svg>
        }
    ];

    return (
        <section id="features" className="py-32 relative">
            <div className="container px-6">
                <div className="flex flex-col items-center text-center mb-24">
                    <div className="font-mono text-xs text-matrix-green tracking-[0.5em] mb-4 opacity-50">CORE_CAPABILITIES</div>
                    <h2 className="text-4xl md:text-6xl font-black mb-6 tracking-tight">THE_PROTOCOL</h2>
                    <div className="h-1 w-24 bg-matrix-green shadow-matrix-glow"></div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
                    {features.map((f, i) => (
                        <FeatureCard key={i} {...f} />
                    ))}
                </div>
            </div>
        </section>
    );
};

export default Features;
