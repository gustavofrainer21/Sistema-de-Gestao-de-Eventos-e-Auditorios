import { NavLink, Navigate, Route, Routes } from 'react-router-dom'
import { isAdmin, keycloak } from './keycloak'
import Catalogo from './pages/Catalogo'
import EventoDetalhe from './pages/EventoDetalhe'
import MinhasInscricoes from './pages/MinhasInscricoes'
import CertificadoView from './pages/CertificadoView'
import AdminPainel from './pages/AdminPainel'
import AdminLocais from './pages/AdminLocais'
import EventoForm from './pages/EventoForm'
import Checkin from './pages/Checkin'
import VerificarCertificado from './pages/VerificarCertificado'

function Admin({ children }: { children: React.ReactNode }) {
  return isAdmin() ? <>{children}</> : <Navigate to="/" replace />
}

export default function App() {
  const admin = isAdmin()
  const nome = keycloak.tokenParsed?.name ?? keycloak.tokenParsed?.preferred_username ?? 'Usuário'

  return (
    <>
      <header className="topo">
        <strong className="marca">Eventos &amp; Auditórios</strong>
        <nav>
          <NavLink to="/" end>Catálogo</NavLink>
          <NavLink to="/minhas">Minhas inscrições</NavLink>
          {admin && (
            <>
              <NavLink to="/admin">Painel</NavLink>
              <NavLink to="/admin/locais">Locais</NavLink>
              <NavLink to="/admin/eventos/novo">Novo evento</NavLink>
              <NavLink to="/admin/certificados">Verificar certificado</NavLink>
            </>
          )}
        </nav>
        <span className="usuario">
          {nome} ({admin ? 'Organizador' : 'Participante'})
          <button className="link" onClick={() => keycloak.logout({ redirectUri: window.location.origin })}>
            Sair
          </button>
        </span>
      </header>

      <main className="conteudo">
        <Routes>
          <Route path="/" element={<Catalogo />} />
          <Route path="/eventos/:id" element={<EventoDetalhe />} />
          <Route path="/minhas" element={<MinhasInscricoes />} />
          <Route path="/certificado/:inscricaoId" element={<CertificadoView />} />
          <Route path="/admin" element={<Admin><AdminPainel /></Admin>} />
          <Route path="/admin/locais" element={<Admin><AdminLocais /></Admin>} />
          <Route path="/admin/eventos/novo" element={<Admin><EventoForm /></Admin>} />
          <Route path="/admin/eventos/:id/editar" element={<Admin><EventoForm /></Admin>} />
          <Route path="/admin/eventos/:id/checkin" element={<Admin><Checkin /></Admin>} />
          <Route path="/admin/certificados" element={<Admin><VerificarCertificado /></Admin>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </>
  )
}
