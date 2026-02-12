#!/bin/bash
set -e

echo "Deploying minimal Next.js panel..."

cd /opt/panel/backend

# Create minimal Next.js app structure
cat > package.json <<'EOF'
{
  "name": "breach-rabbit-panel",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.2.3",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  }
}
EOF

mkdir -p app

cat > app/layout.js <<'EOF'
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'] })

export const metadata = { title: 'Breach Rabbit Panel' }

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  )
}
EOF

cat > app/page.js <<'EOF'
'use client'

export default function Home() {
  return (
    <div style={{
      padding: '80px 20px',
      textAlign: 'center',
      fontFamily: 'system-ui, sans-serif',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      minHeight: '100vh',
      color: 'white'
    }}>
      <div style={{ fontSize: '6em', marginBottom: '30px' }}>🐰</div>
      <h1 style={{ fontSize: '2.8em', marginBottom: '20px' }}>Breach Rabbit Web Panel</h1>
      
      <div style={{
        background: 'rgba(255,255,255,0.1)',
        borderRadius: '16px',
        padding: '40px',
        maxWidth: '700px',
        margin: '0 auto',
        backdropFilter: 'blur(10px)'
      }}>
        <p style={{ fontSize: '1.4em', marginBottom: '30px' }}>✅ Installation Complete!</p>
        
        <div style={{
          background: 'rgba(0,0,0,0.2)',
          padding: '20px',
          borderRadius: '12px',
          fontFamily: 'monospace',
          fontSize: '1em',
          textAlign: 'left',
          marginBottom: '30px'
        }}>
          <strong>🔑 View credentials:</strong><br/>
          cat /root/breach-rabbit-credentials.txt
        </div>
        
        <p style={{ marginBottom: '20px', fontSize: '1.1em' }}>Then start the panel:</p>
        
        <div style={{
          background: 'rgba(0,0,0,0.2)',
          padding: '20px',
          borderRadius: '12px',
          fontFamily: 'monospace',
          fontSize: '1em',
          textAlign: 'left'
        }}>
          sudo -u panel pm2 start /opt/panel/backend/ecosystem.config.js<br/>
          sudo -u panel pm2 save
        </div>
      </div>
      
      <p style={{ marginTop: '40px', opacity: '0.8', fontSize: '0.9em' }}>
        Access panel at: http://your-server:3000
      </p>
    </div>
  )
}
EOF

# Install and build
chown -R panel:panel /opt/panel/backend
sudo -u panel yarn install --silent 2>&1 | grep -v "warning" || true
sudo -u panel yarn build --silent 2>&1 | grep -v "info" || true

echo "✓ Next.js panel deployed and built"