import { useConnect } from '@stacks/connect-react';
import { AppConfig, UserSession } from '@stacks/connect';
import { useEffect, useState } from 'react';

const appConfig = new AppConfig(['store_write', 'publish_data']);
export const userSession = new UserSession({ appConfig });

interface WalletConnectProps {
  onAuthComplete: (userData: any) => void;
}

export default function WalletConnect({ onAuthComplete }: WalletConnectProps) {
  const { authenticate, disconnect } = useConnect();
  const [isSignedIn, setIsSignedIn] = useState(false);
  const [address, setAddress] = useState('');

  useEffect(() => {
    if (userSession.isSignInPending()) {
      userSession.handlePendingSignIn().then((userData) => {
        setIsSignedIn(true);
        setAddress(userData.profile.stxAddress.mainnet); // Default to mainnet format for display
        onAuthComplete(userData);
      });
    } else if (userSession.isUserSignedIn()) {
      const userData = userSession.loadUserData();
      setIsSignedIn(true);
      setAddress(userData.profile.stxAddress.mainnet);
      onAuthComplete(userData);
    }
  }, [onAuthComplete]);

  const login = () => {
    authenticate({
      appDetails: {
        name: 'DrizzleonStacks',
        icon: window.location.origin + '/favicon.ico',
      },
      onFinish: (payload) => {
        const userData = payload.userSession.loadUserData();
        setIsSignedIn(true);
        setAddress(userData.profile.stxAddress.mainnet);
        onAuthComplete(userData);
      },
    });
  };

  const logout = () => {
    disconnect();
    setIsSignedIn(false);
    setAddress('');
    onAuthComplete(null);
  };

  const truncateAddress = (addr: string) => {
    if (!addr) return '';
    return `${addr.substring(0, 5)}...${addr.substring(addr.length - 4)}`;
  };

  if (isSignedIn) {
    return (
      <div className="flex items-center gap-4">
        <div className="text-secondary text-sm glass-panel p-2" style={{ padding: '8px 16px' }}>
          {truncateAddress(address)}
        </div>
        <button onClick={logout} className="btn btn-secondary">
          Disconnect
        </button>
      </div>
    );
  }

  return (
    <button onClick={login} className="btn btn-primary">
      Connect Wallet
    </button>
  );
}
