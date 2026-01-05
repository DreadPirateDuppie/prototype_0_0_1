import React, { useState, useEffect } from 'react';

const Navbar = () => {
    const [scrolled, setScrolled] = useState(false);

    useEffect(() => {
        const handleScroll = () => setScrolled(window.scrollY > 50);
        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    return (
        <nav className={`fixed top-0 left-0 w-full z-50 transition-all duration-500 ${scrolled ? 'py-4 bg-matrix-black/80 backdrop-blur-md border-b border-white/5' : 'py-8 bg-transparent'}`}>
            <div className="container flex justify-between items-center">
                <div className="flex items-center gap-2 group cursor-pointer">
                    <div className="w-8 h-8 bg-matrix-green rounded-lg flex items-center justify-center font-black text-matrix-black transition-transform group-hover:rotate-12">
                        P
                    </div>
                    <span className="font-display font-black text-xl tracking-tighter text-white">PUSHINN</span>
                </div>

                <div className="hidden md:flex items-center gap-10">
                    {['Features', 'Visuals', 'Beta'].map((item) => (
                        <a
                            key={item}
                            href={`#${item.toLowerCase()}`}
                            className="text-sm font-medium text-dim hover:text-matrix-green transition-colors"
                        >
                            {item}
                        </a>
                    ))}
                    <a href="#beta" className="btn-primary" style={{ padding: '0.6rem 1.5rem', fontSize: '0.9rem' }}>
                        Join Beta
                    </a>
                </div>

                <div className="md:hidden text-white">
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>
                </div>
            </div>
        </nav>
    );
};

export default Navbar;
