import React from 'react';

const Footer = () => {
    return (
        <footer className="py-20 border-t border-matrix-green/10 relative overflow-hidden">
            {/* Decorative background text */}
            <div className="absolute bottom-0 left-0 w-full font-mono text-[15vw] text-matrix-green/5 font-black select-none pointer-events-none -mb-[5vw]">
                PUSHINN
            </div>

            <div className="container px-6 relative z-10">
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-12 mb-20">
                    <div className="flex flex-col gap-6">
                        <div className="flex items-center gap-3">
                            <div className="w-8 h-8 border-2 border-matrix-green flex items-center justify-center font-mono font-black text-matrix-green">P</div>
                            <span className="font-mono font-black text-xl text-matrix-green tracking-tighter">PUSHINN</span>
                        </div>
                        <p className="font-mono text-xs text-matrix-dark-green leading-relaxed max-w-xs">
                            The decentralized social layer for the global skateboarding community. Built on the Pushinn protocol.
                        </p>
                    </div>

                    <div className="flex flex-col gap-6">
                        <h4 className="font-mono text-xs font-bold text-white tracking-[0.3em]">PROTOCOL</h4>
                        <div className="flex flex-col gap-3 font-mono text-[10px] text-matrix-dark-green">
                            <a href="#" className="hover:text-matrix-green transition-colors">NETWORK_STATUS</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">DOCUMENTATION</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">API_REFERENCE</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">GOVERNANCE</a>
                        </div>
                    </div>

                    <div className="flex flex-col gap-6">
                        <h4 className="font-mono text-xs font-bold text-white tracking-[0.3em]">COMMUNITY</h4>
                        <div className="flex flex-col gap-3 font-mono text-[10px] text-matrix-dark-green">
                            <a href="#" className="hover:text-matrix-green transition-colors">DISCORD_SERVER</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">TWITTER_FEED</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">INSTAGRAM_CORE</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">GITHUB_REPO</a>
                        </div>
                    </div>

                    <div className="flex flex-col gap-6">
                        <h4 className="font-mono text-xs font-bold text-white tracking-[0.3em]">LEGAL</h4>
                        <div className="flex flex-col gap-3 font-mono text-[10px] text-matrix-dark-green">
                            <a href="#" className="hover:text-matrix-green transition-colors">PRIVACY_POLICY</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">TERMS_OF_SERVICE</a>
                            <a href="#" className="hover:text-matrix-green transition-colors">COOKIE_SETTINGS</a>
                        </div>
                    </div>
                </div>

                <div className="flex flex-col md:flex-row justify-between items-center pt-12 border-t border-matrix-green/5 gap-6">
                    <div className="font-mono text-[10px] text-matrix-dark-green opacity-50">
                        © 2025 PUSHINN_PROTOCOL_LABS. ALL_SYSTEMS_OPERATIONAL.
                    </div>
                    <div className="flex gap-8 font-mono text-[10px] text-matrix-dark-green">
                        <span className="flex items-center gap-2">
                            <div className="w-1 h-1 bg-matrix-green rounded-full shadow-matrix-glow"></div>
                            ENCRYPTED_CONNECTION
                        </span>
                        <span className="flex items-center gap-2">
                            <div className="w-1 h-1 bg-matrix-green rounded-full shadow-matrix-glow"></div>
                            NODE_ID: 0x7F...3A
                        </span>
                    </div>
                </div>
            </div>
        </footer>
    );
};

export default Footer;
