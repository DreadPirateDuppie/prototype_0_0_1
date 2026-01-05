import React from 'react'
import Navbar from './components/Navbar'
import TerminalHero from './components/TerminalHero'
import ProtocolExplorer from './components/ProtocolExplorer'
import DataVisuals from './components/DataVisuals'
import AccessTerminal from './components/AccessTerminal'
import Footer from './components/Footer'
import MatrixRain from './components/MatrixRain'
import CyberHUD from './components/CyberHUD'

function App() {
  return (
    <div className="min-h-screen bg-matrix-black text-matrix-text selection:bg-matrix-green selection:text-matrix-black overflow-x-hidden">
      <MatrixRain />
      <CyberHUD />
      <Navbar />

      <main className="relative z-10">
        <TerminalHero />
        <ProtocolExplorer />
        <DataVisuals />
        <AccessTerminal />
      </main>

      <Footer />
    </div>
  )
}

export default App
