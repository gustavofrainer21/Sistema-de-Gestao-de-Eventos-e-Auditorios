import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { keycloak } from './keycloak'
import './styles.css'

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement)

keycloak
  .init({ onLoad: 'login-required', pkceMethod: 'S256', checkLoginIframe: false })
  .then(() => {
    root.render(
      <React.StrictMode>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </React.StrictMode>,
    )
  })
  .catch(() => {
    root.render(<p style={{ padding: 24 }}>Não foi possível conectar ao Keycloak. Verifique se ele está em execução.</p>)
  })
