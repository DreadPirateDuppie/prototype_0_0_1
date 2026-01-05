import React from 'react';

const CyberHUD = ({ children }) => {
    return (
        <div className="fixed inset-0 pointer-events-none z-40 overflow-hidden">
            {/* Scanning Line */}
            <div className="absolute top-0 left-0 w-full h-[2px] bg-matrix-green/20 shadow-matrix-glow animate-scan"></div>

            {/* Corner Accents */}
            <div className="absolute top-6 left-6 w-12 h-12 border-t-2 border-l-2 border-matrix-green/50"></div>
            <div className="absolute top-6 right-6 w-12 h-12 border-t-2 border-r-2 border-matrix-green/50"></div>
            <div className="absolute bottom-6 left-6 w-12 h-12 border-b-2 border-l-2 border-matrix-green/50"></div>
            <div className="absolute bottom-6 right-6 w-12 h-12 border-b-2 border-r-2 border-matrix-green/50"></div>

            {/* HUD Metadata */}
            <div className="absolute top-8 left-20 font-mono text-[10px] text-matrix-green/40 tracking-widest uppercase">
                SYSTEM_SCAN: ACTIVE // NODE_ID: 0x7F...3A
            </div>
            <div className="absolute bottom-8 left-20 font-mono text-[10px] text-matrix-green/40 tracking-widest uppercase">
                ENCRYPTION: AES-256 // PROTOCOL: PUSHINN_v1.0.4
            </div>
            <div className="absolute bottom-8 right-20 font-mono text-[10px] text-matrix-green/40 tracking-widest uppercase">
                LAT: 51.4225 // LON: -0.0666
            </div>

            {/* Vignette Effect */}
            <div className="absolute inset-0 bg-radial-vignette pointer-events-none"></div>

            <style jsx>{`
        .animate-scan {
          animation: scan 8s linear infinite;
        }
        @keyframes scan {
          from { transform: translateY(-100vh); }
          to { transform: translateY(100vh); }
        }
        .bg-radial-vignette {
          background: radial-gradient(circle, transparent 60%, rgba(0, 0, 0, 0.4) 100%);
        }
      `}</style>
        </div>
    );
};

export default CyberHUD;
