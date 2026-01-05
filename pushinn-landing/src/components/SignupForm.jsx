import React, { useState } from 'react';

const SignupForm = () => {
    const [email, setEmail] = useState('');
    const [status, setStatus] = useState('idle'); // idle, loading, success, error

    const handleSubmit = (e) => {
        e.preventDefault();
        if (!email) return;

        setStatus('loading');

        // Simulate API call
        setTimeout(() => {
            setStatus('success');
            setEmail('');
        }, 2000);
    };

    return (
        <section id="beta" className="py-32 relative overflow-hidden">
            {/* Background decorative elements */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-matrix-green/5 blur-[120px] rounded-full -z-10"></div>

            <div className="container px-6 max-w-4xl mx-auto">
                <div className="glass p-8 md:p-20 relative overflow-hidden rounded-3xl border-matrix-green/20">
                    {/* Decorative corner accents */}
                    <div className="absolute top-0 left-0 w-16 h-16 border-t-2 border-l-2 border-matrix-green"></div>
                    <div className="absolute bottom-0 right-0 w-16 h-16 border-b-2 border-r-2 border-matrix-green"></div>

                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
                        <div className="text-left">
                            <div className="font-mono text-xs text-matrix-green tracking-[0.4em] mb-6">ACCESS_REQUEST</div>
                            <h2 className="text-4xl md:text-5xl font-black mb-6 tracking-tight text-white">JOIN_THE<br /><span className="text-matrix-green">NETWORK</span></h2>
                            <p className="text-matrix-dark-green font-mono leading-relaxed mb-8">
                                The Pushinn protocol is currently in limited rollout. Request your access key to join the decentralized skateboarding social layer.
                            </p>
                            <div className="flex flex-col gap-4">
                                <div className="flex items-center gap-3 font-mono text-[10px] text-matrix-dark-green">
                                    <div className="w-1.5 h-1.5 bg-matrix-green rounded-full"></div>
                                    EARLY_ADOPTER_BADGE [UNLOCKED]
                                </div>
                                <div className="flex items-center gap-3 font-mono text-[10px] text-matrix-dark-green">
                                    <div className="w-1.5 h-1.5 bg-matrix-green rounded-full"></div>
                                    BETA_TESTER_REWARDS [ACTIVE]
                                </div>
                            </div>
                        </div>

                        <div className="relative">
                            {status === 'success' ? (
                                <div className="animate-fade-in text-center py-12">
                                    <div className="w-20 h-20 border-2 border-matrix-green rounded-full flex items-center justify-center mx-auto mb-8 shadow-matrix-glow animate-pulse">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" className="text-matrix-green"><polyline points="20 6 9 17 4 12"></polyline></svg>
                                    </div>
                                    <h3 className="text-2xl font-bold text-matrix-green mb-4 tracking-widest">ACCESS_GRANTED</h3>
                                    <p className="text-sm font-mono text-matrix-dark-green">Your request has been queued. Check your terminal for the activation key.</p>
                                    <button
                                        onClick={() => setStatus('idle')}
                                        className="mt-10 font-mono text-[10px] text-matrix-green hover:underline tracking-widest"
                                    >
                                        SUBMIT_ANOTHER_REQUEST
                                    </button>
                                </div>
                            ) : (
                                <form onSubmit={handleSubmit} className="flex flex-col gap-6">
                                    <div className="relative group">
                                        <label className="absolute -top-3 left-4 bg-matrix-black px-2 font-mono text-[10px] text-matrix-green z-10">USER_EMAIL</label>
                                        <input
                                            type="email"
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            placeholder="ENTER_YOUR_IDENTITY"
                                            required
                                            className="w-full bg-transparent border-2 border-matrix-dark-green/50 p-5 font-mono text-matrix-green focus:border-matrix-green focus:outline-none focus:shadow-matrix-glow transition-all rounded-xl"
                                        />
                                        <div className="absolute right-4 top-1/2 -translate-y-1/2 text-matrix-dark-green opacity-30 font-mono text-[10px] group-focus-within:opacity-100 transition-opacity">
                                            [REQUIRED]
                                        </div>
                                    </div>

                                    <button
                                        type="submit"
                                        disabled={status === 'loading'}
                                        className="group relative w-full py-5 bg-matrix-green text-matrix-black font-black text-xl overflow-hidden rounded-xl transition-all hover:scale-[1.02] active:scale-[0.98] disabled:opacity-50"
                                    >
                                        <span className="relative z-10">{status === 'loading' ? 'ENCRYPTING...' : 'REQUEST_ACCESS'}</span>
                                        <div className="absolute inset-0 bg-white translate-y-full group-hover:translate-y-0 transition-transform duration-300"></div>
                                    </button>

                                    <div className="flex items-center gap-4 opacity-30 group">
                                        <div className="h-px flex-1 bg-matrix-dark-green"></div>
                                        <span className="font-mono text-[8px] text-matrix-dark-green tracking-[0.5em]">SECURE_CONNECTION</span>
                                        <div className="h-px flex-1 bg-matrix-dark-green"></div>
                                    </div>

                                    <p className="text-[9px] font-mono text-matrix-dark-green text-center uppercase tracking-widest opacity-40">
                                        By requesting access, you agree to the Pushinn protocol terms and neural privacy policy.
                                    </p>
                                </form>
                            )}
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
};

export default SignupForm;
