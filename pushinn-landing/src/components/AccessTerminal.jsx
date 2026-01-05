import React, { useState, useRef, useEffect } from 'react';

const AccessTerminal = () => {
    const [input, setInput] = useState('');
    const [history, setHistory] = useState([
        { type: 'info', text: 'PUSHINN_PROTOCOL_ACCESS_GATEWAY' },
        { type: 'info', text: '--------------------------------' },
        { type: 'info', text: 'ENTER_IDENTITY_EMAIL_TO_REQUEST_KEY:' }
    ]);
    const [isProcessing, setIsProcessing] = useState(false);
    const inputRef = useRef(null);

    const handleSubmit = (e) => {
        e.preventDefault();
        if (!input || isProcessing) return;

        const email = input.trim();
        setHistory(prev => [...prev, { type: 'input', text: email }]);
        setInput('');
        setIsProcessing(true);

        // Simulate processing
        setTimeout(() => {
            setHistory(prev => [...prev,
            { type: 'info', text: '> VALIDATING_IDENTITY...' },
            { type: 'info', text: '> ENCRYPTING_REQUEST...' },
            { type: 'success', text: '> ACCESS_QUEUED: ACTIVATION_KEY_SENT_TO_IDENTITY.' }
            ]);
            setIsProcessing(false);
        }, 2000);
    };

    useEffect(() => {
        if (inputRef.current) {
            inputRef.current.focus();
        }
    }, []);

    return (
        <section id="access" className="py-32 relative">
            <div className="container px-6 max-w-4xl mx-auto">
                <div className="glass p-8 md:p-16 rounded-3xl border-matrix-green/20 bg-matrix-black/90 shadow-2xl relative overflow-hidden">
                    {/* Terminal Header */}
                    <div className="flex items-center justify-between mb-8 border-b border-matrix-green/10 pb-4">
                        <div className="flex gap-2">
                            <div className="w-3 h-3 rounded-full bg-red-500/20 border border-red-500/50"></div>
                            <div className="w-3 h-3 rounded-full bg-yellow-500/20 border border-yellow-500/50"></div>
                            <div className="w-3 h-3 rounded-full bg-green-500/20 border border-green-500/50"></div>
                        </div>
                        <div className="font-mono text-[10px] text-matrix-green/40 tracking-widest">GATEWAY_TERMINAL_v1.0</div>
                    </div>

                    {/* Terminal Output */}
                    <div className="font-mono text-sm md:text-base space-y-2 mb-8 min-h-[200px]">
                        {history.map((line, i) => (
                            <div key={i} className={`animate-fade-in ${line.type === 'success' ? 'text-matrix-green font-bold' : line.type === 'input' ? 'text-white' : 'text-matrix-dark-green'}`}>
                                {line.type === 'input' && <span className="mr-2">$</span>}
                                {line.text}
                            </div>
                        ))}
                        {isProcessing && (
                            <div className="flex items-center gap-2 text-matrix-green">
                                <div className="w-2 h-2 bg-matrix-green animate-ping rounded-full"></div>
                                <span>PROCESSING...</span>
                            </div>
                        )}
                    </div>

                    {/* Terminal Input */}
                    {!isProcessing && history.length < 7 && (
                        <form onSubmit={handleSubmit} className="flex items-center gap-2 font-mono text-sm md:text-base">
                            <span className="text-matrix-green">$</span>
                            <input
                                ref={inputRef}
                                type="email"
                                value={input}
                                onChange={(e) => setInput(e.target.value)}
                                className="bg-transparent border-none outline-none text-white w-full"
                                placeholder="USER@NETWORK.COM"
                                autoFocus
                            />
                        </form>
                    )}

                    {/* Decorative elements */}
                    <div className="absolute -bottom-20 -right-20 w-60 h-60 bg-matrix-green/5 blur-[100px] rounded-full"></div>
                </div>
            </div>
        </section>
    );
};

export default AccessTerminal;
