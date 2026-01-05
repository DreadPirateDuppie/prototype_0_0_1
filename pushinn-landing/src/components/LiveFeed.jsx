import React, { useState, useEffect } from 'react';

const LiveFeed = () => {
    const [events, setEvents] = useState([
        { id: 1, user: 'NEO_SK8R', action: 'uploaded a new clip', location: 'Southbank', time: '2m ago' },
        { id: 2, user: 'TRINITY_GRIND', action: 'won a battle against MORPHEUS', location: 'Global', time: '5m ago' },
        { id: 3, user: 'CYBER_FLIP', action: 'discovered a new spot', location: 'Berlin Tech', time: '12m ago' },
    ]);

    useEffect(() => {
        const users = ['GHOST_OLLIE', 'MATRIX_SLIDE', 'ZEN_KICK', 'VOID_HEEL', 'PIXEL_GRAB'];
        const actions = ['uploaded a clip', 'started a battle', 'pinned a spot', 'joined the network', 'leveled up'];
        const locations = ['LA Courthouse', 'MACBA', 'Staples Center', 'Love Park', 'The Banks'];

        const interval = setInterval(() => {
            const newEvent = {
                id: Date.now(),
                user: users[Math.floor(Math.random() * users.length)],
                action: actions[Math.floor(Math.random() * actions.length)],
                location: locations[Math.floor(Math.random() * locations.length)],
                time: 'Just now'
            };

            setEvents(prev => [newEvent, ...prev.slice(0, 4)]);
        }, 4000);

        return () => clearInterval(interval);
    }, []);

    return (
        <section className="py-24 relative overflow-hidden">
            <div className="container px-6">
                <div className="glass p-8 md:p-12 relative">
                    <div className="flex items-center gap-4 mb-12">
                        <div className="w-3 h-3 bg-matrix-green rounded-full shadow-matrix-glow animate-ping"></div>
                        <h2 className="text-2xl md:text-3xl font-bold tracking-widest">LIVE_PROTOCOL_FEED</h2>
                    </div>

                    <div className="flex flex-col gap-4">
                        {events.map((event) => (
                            <div
                                key={event.id}
                                className="flex flex-col md:flex-row md:items-center justify-between p-4 border-l-2 border-matrix-dark-green hover:border-matrix-green hover:bg-matrix-green/5 transition-all animate-fade-in"
                            >
                                <div className="flex items-center gap-4">
                                    <span className="font-mono text-matrix-green font-bold">[{event.user}]</span>
                                    <span className="font-mono text-white opacity-80">{event.action}</span>
                                </div>
                                <div className="flex items-center gap-6 mt-2 md:mt-0">
                                    <span className="font-mono text-xs text-matrix-dark-green uppercase tracking-widest">LOC: {event.location}</span>
                                    <span className="font-mono text-[10px] text-matrix-green opacity-50">{event.time}</span>
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className="mt-12 pt-8 border-t border-matrix-dark-green/20 flex justify-between items-center">
                        <div className="font-mono text-[10px] text-matrix-dark-green">
                            TOTAL_NODES_ONLINE: 1,420
                        </div>
                        <div className="font-mono text-[10px] text-matrix-dark-green">
                            UPTIME: 99.998%
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
};

export default LiveFeed;
