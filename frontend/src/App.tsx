import { Connect } from '@stacks/connect-react';
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';
import { useState } from 'react';
import WalletConnect from './components/WalletConnect';
// import CreateStream from './components/CreateStream';
// import StreamDashboard from './components/StreamDashboard';

export default function App() {
  const [userData, setUserData] = useState<any>(null);

  const authOptions = {
    appDetails: {
      name: 'DrizzleonStacks',
      icon: window.location.origin + '/favicon.ico',
    },
    userSession: undefined, // Handled inside Connect
    onFinish: () => {
      // Reload on auth to pick up session
      window.location.reload();
    },
    onCancel: () => {
      console.log('User cancelled login');
    },
  };

  return (
    <Connect authOptions={authOptions}>
      <BrowserRouter>
        <div className="flex-col w-full h-full min-h-screen">
          
          {/* Navbar */}
          <nav className="navbar">
            <div className="container flex justify-between items-center w-full">
              <div className="flex items-center gap-4">
                <Link to="/" style={{ textDecoration: 'none' }}>
                  <div className="text-xl text-gradient">DrizzleonStacks</div>
                </Link>
                <div className="flex gap-4 ml-8" style={{ display: userData ? 'flex' : 'none' }}>
                  <Link to="/create" className="text-secondary" style={{ textDecoration: 'none' }}>Create Stream</Link>
                  <Link to="/dashboard" className="text-secondary" style={{ textDecoration: 'none' }}>Dashboard</Link>
                </div>
              </div>
              <WalletConnect onAuthComplete={setUserData} />
            </div>
          </nav>

          {/* Main Content */}
          <main className="container mt-8 mb-8" style={{ flex: 1 }}>
            {!userData ? (
              <div className="flex-col items-center justify-center h-full gap-4 mt-8" style={{ textAlign: 'center' }}>
                <h1 className="text-2xl mb-2">Bitcoin-Anchored Payment Streams</h1>
                <p className="text-secondary mb-8" style={{ maxWidth: '600px', margin: '0 auto 32px' }}>
                  Trustless, continuous value transfer on Stacks. Lock STX or SIP-010 tokens 
                  and stream them block-by-block with cliff schedules, milestone unlocks, and tradeable NFT positions.
                </p>
                <div className="glass-panel p-6" style={{ maxWidth: '400px', margin: '0 auto' }}>
                  <p className="mb-4">Connect your Stacks wallet to get started.</p>
                </div>
              </div>
            ) : (
              <Routes>
                <Route path="/" element={<div className="text-lg">Welcome to DrizzleonStacks. Select an option above.</div>} />
                <Route path="/create" element={<div className="text-lg">Create Stream form coming here...</div>} />
                <Route path="/dashboard" element={<div className="text-lg">Dashboard coming here...</div>} />
              </Routes>
            )}
          </main>
          
        </div>
      </BrowserRouter>
    </Connect>
  );
}
